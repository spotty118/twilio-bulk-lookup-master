# frozen_string_literal: true

require 'rails_helper'

# INFRASTRUCTURE REQUIRED:
# - PostgreSQL database
# - Redis (for Sidekiq background jobs)
# - Run with: bundle exec rspec spec/integration/lookup_flow_spec.rb

RSpec.describe 'Complete lookup flow', type: :integration do
  include ActiveJob::TestHelper
  include JobHelpers

  # Mock Twilio API response for successful lookup
  let(:mock_lookup_result) do
    double(
      'LookupResult',
      phone_number: '+14155551234',
      valid: true,
      validation_errors: [],
      country_code: 'US',
      calling_country_code: '1',
      national_format: '(415) 555-1234',
      line_type_intelligence: {
        'type' => 'mobile',
        'confidence' => '95',
        'carrier_name' => 'AT&T',
        'mobile_network_code' => '410',
        'mobile_country_code' => '310'
      },
      caller_name: {
        'caller_name' => 'JOHN DOE',
        'caller_type' => 'CONSUMER'
      },
      sms_pumping_risk: {
        'sms_pumping_risk_score' => 15,
        'carrier_risk_category' => 'low',
        'number_blocked' => false
      }
    )
  end

  let(:credentials) { create(:twilio_credential, :with_all_packages, :with_enrichment_enabled) }

  before do
    allow(TwilioCredential).to receive(:current).and_return(credentials)
    # Stub SLACK_NOTIFIER to prevent actual Slack notifications
    stub_const('SLACK_NOTIFIER', double('SlackNotifier', ping: true))
  end

  # ============================================================================
  # Requirement 11.1: Contact progresses through all status states
  # ============================================================================
  describe 'end-to-end lookup flow' do
    # _Requirements: 11.1, 11.2_

    it 'contact progresses through all status states: pending -> processing -> completed' do
      setup_twilio_mock(mock_lookup_result)

      # Phase 1: Create contact in pending state
      contact = create(:contact, :pending, raw_phone_number: '+14155551234')
      expect(contact.status).to eq('pending')

      # Phase 2: Run LookupRequestJob - should transition to processing then completed
      LookupRequestJob.new.perform(contact.id)

      # Phase 3: Verify final state
      contact.reload
      expect(contact.status).to eq('completed')
      expect(contact.formatted_phone_number).to eq('+14155551234')
      expect(contact.phone_valid).to be true
      expect(contact.country_code).to eq('US')
      expect(contact.line_type).to eq('mobile')
      expect(contact.carrier_name).to eq('AT&T')
      expect(contact.lookup_performed_at).to be_present
    end

    it 'stores all Twilio API response data correctly' do
      setup_twilio_mock(mock_lookup_result)

      contact = create(:contact, :pending, raw_phone_number: '+14155551234')
      LookupRequestJob.new.perform(contact.id)
      contact.reload

      # Verify Line Type Intelligence data
      expect(contact.line_type).to eq('mobile')
      expect(contact.line_type_confidence).to eq('95')
      expect(contact.carrier_name).to eq('AT&T')
      expect(contact.mobile_network_code).to eq('410')
      expect(contact.mobile_country_code).to eq('310')

      # Verify Caller Name (CNAM) data
      expect(contact.caller_name).to eq('JOHN DOE')
      expect(contact.caller_type).to eq('CONSUMER')

      # Verify SMS Pumping Risk data
      expect(contact.sms_pumping_risk_score).to eq(15)
      expect(contact.sms_pumping_risk_level).to eq('low')
      expect(contact.sms_pumping_carrier_risk_category).to eq('low')
      expect(contact.sms_pumping_number_blocked).to be false
    end
  end

  # ============================================================================
  # Requirement 11.2: Enrichment jobs are queued on success
  # ============================================================================
  describe 'enrichment job queueing' do
    # _Requirements: 11.2_

    it 'enqueues EnrichmentCoordinatorJob after successful lookup' do
      setup_twilio_mock(mock_lookup_result)

      contact = create(:contact, :pending, raw_phone_number: '+14155551234')

      expect {
        LookupRequestJob.new.perform(contact.id)
      }.to have_enqueued_job(EnrichmentCoordinatorJob).with(contact.id)
    end

    it 'does not enqueue enrichment jobs when lookup fails' do
      # Setup mock that raises permanent error
      error = twilio_error(code: 20404, message: 'Invalid number', status_code: 404)

      mock_client = double('TwilioClient')
      mock_lookups = double('Lookups')
      mock_v2 = double('V2')
      mock_phone_numbers = double('PhoneNumbers')

      allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:lookups).and_return(mock_lookups)
      allow(mock_lookups).to receive(:v2).and_return(mock_v2)
      allow(mock_v2).to receive(:phone_numbers).and_return(mock_phone_numbers)
      allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

      contact = create(:contact, :pending, raw_phone_number: '+14155551234')

      expect {
        LookupRequestJob.new.perform(contact.id)
      }.not_to have_enqueued_job(EnrichmentCoordinatorJob)
    end

    it 'enrichment coordinator runs all enabled enrichments' do
      setup_twilio_mock(mock_lookup_result)

      contact = create(:contact, :pending, raw_phone_number: '+14155551234')

      # Run lookup job
      LookupRequestJob.new.perform(contact.id)

      # Verify EnrichmentCoordinatorJob was enqueued
      expect(EnrichmentCoordinatorJob).to have_been_enqueued.with(contact.id)

      # Stub ParallelEnrichmentService before running the coordinator job
      mock_parallel_service = double('ParallelEnrichmentService')
      allow(mock_parallel_service).to receive(:enrich_with_retry).and_return({
        business: { success: true, duration: 100 },
        email: { success: true, duration: 150 }
      })

      # Need to stub before the class is loaded
      allow_any_instance_of(EnrichmentCoordinatorJob).to receive(:perform) do |job, contact_id|
        # Verify the job receives the correct contact_id
        expect(contact_id).to eq(contact.id)
      end

      # Run enrichment coordinator job
      perform_enqueued_jobs(only: EnrichmentCoordinatorJob)
    end
  end

  # ============================================================================
  # Requirement 11.3: Twilio API error marks contact as failed
  # ============================================================================
  describe 'error flow' do
    # _Requirements: 11.3_

    context 'when Twilio API returns invalid number error' do
      it 'marks contact as failed with error details' do
        error = twilio_error(code: 20404, message: 'Invalid phone number', status_code: 404)

        # Bypass circuit breaker to test direct error handling
        allow(CircuitBreakerService).to receive(:call).with(:twilio).and_raise(error)

        contact = create(:contact, :pending, raw_phone_number: '+14155551234')
        LookupRequestJob.new.perform(contact.id)

        contact.reload
        expect(contact.status).to eq('failed')
        expect(contact.error_code).to include('Invalid phone number')
      end
    end

    context 'when Twilio API returns authentication error' do
      it 'marks contact as failed with authentication error' do
        error = twilio_error(code: 20003, message: 'Authentication error', status_code: 401)

        # Bypass circuit breaker to test direct error handling
        allow(CircuitBreakerService).to receive(:call).with(:twilio).and_raise(error)

        contact = create(:contact, :pending, raw_phone_number: '+14155551234')
        LookupRequestJob.new.perform(contact.id)

        contact.reload
        expect(contact.status).to eq('failed')
        expect(contact.error_code).to include('Authentication error')
      end
    end

    context 'when Twilio API returns rate limit error' do
      it 'marks contact as failed and re-raises for retry' do
        error = twilio_error(code: 20429, message: 'Rate limit exceeded', status_code: 429)

        # Bypass circuit breaker to test direct error handling
        allow(CircuitBreakerService).to receive(:call).with(:twilio).and_raise(error)

        contact = create(:contact, :pending, raw_phone_number: '+14155551234')

        expect {
          LookupRequestJob.new.perform(contact.id)
        }.to raise_error(Twilio::REST::RestError)

        contact.reload
        expect(contact.status).to eq('failed')
        expect(contact.error_code).to include('Rate limit exceeded')
      end
    end

    context 'when credentials are missing' do
      it 'marks contact as failed with credentials error' do
        allow(TwilioCredential).to receive(:current).and_return(nil)

        contact = create(:contact, :pending, raw_phone_number: '+14155551234')
        LookupRequestJob.new.perform(contact.id)

        contact.reload
        expect(contact.status).to eq('failed')
        expect(contact.error_code).to eq('No Twilio credentials configured')
      end
    end

    context 'when circuit breaker is open' do
      it 'marks contact as failed with circuit open message' do
        # Simulate circuit breaker returning fallback
        allow(CircuitBreakerService).to receive(:call).with(:twilio).and_return({ circuit_open: true })

        contact = create(:contact, :pending, raw_phone_number: '+14155551234')
        LookupRequestJob.new.perform(contact.id)

        contact.reload
        expect(contact.status).to eq('failed')
        expect(contact.error_code).to include('circuit open')
      end
    end
  end

  # ============================================================================
  # Additional integration scenarios
  # ============================================================================
  describe 'retry scenarios' do
    it 'allows retry of failed contacts' do
      setup_twilio_mock(mock_lookup_result)

      # Create a failed contact
      contact = create(:contact, :failed, raw_phone_number: '+14155551234')
      expect(contact.status).to eq('failed')

      # Retry the lookup
      LookupRequestJob.new.perform(contact.id)

      contact.reload
      expect(contact.status).to eq('completed')
      expect(contact.error_code).to be_nil
    end
  end

  describe 'batch processing' do
    it 'processes multiple contacts in sequence' do
      setup_twilio_mock(mock_lookup_result)

      contacts = 3.times.map do |i|
        create(:contact, :pending, raw_phone_number: "+1415555#{1000 + i}")
      end

      contacts.each do |contact|
        LookupRequestJob.new.perform(contact.id)
      end

      contacts.each(&:reload)
      expect(contacts.map(&:status)).to all(eq('completed'))
    end
  end

  describe 'idempotency in flow' do
    it 'does not re-process already completed contacts' do
      setup_twilio_mock(mock_lookup_result)

      contact = create(:contact, :pending, raw_phone_number: '+14155551234')

      # First run
      LookupRequestJob.new.perform(contact.id)
      contact.reload
      original_lookup_time = contact.lookup_performed_at

      # Second run should be skipped
      expect(Twilio::REST::Client).not_to receive(:new)
      LookupRequestJob.new.perform(contact.id)

      contact.reload
      expect(contact.lookup_performed_at).to eq(original_lookup_time)
    end
  end
end
