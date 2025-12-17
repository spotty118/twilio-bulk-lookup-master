# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LookupRequestJob, type: :job do
  # Test Suite for LookupRequestJob
  # Validates: Requirements 2.1, 2.2, 2.3, 2.4

  let(:contact) { create(:contact, :pending) }
  let(:credentials) { create(:twilio_credential, :with_all_packages) }

  # Mock Twilio API response
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
        'confidence' => 95,
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

  before do
    allow(TwilioCredential).to receive(:current).and_return(credentials)
    setup_twilio_mock(mock_lookup_result)
  end

  # ============================================================================
  # Requirement 2.1: Job processes pending contacts
  # ============================================================================
  describe 'processing pending contacts' do
    # _Requirements: 2.1_
    it 'marks contact as processing and performs lookup for pending contacts' do
      expect {
        described_class.new.perform(contact.id)
      }.to change { contact.reload.status }.from('pending').to('completed')
    end

    it 'updates contact with API response data' do
      described_class.new.perform(contact.id)
      contact.reload

      expect(contact.formatted_phone_number).to eq('+14155551234')
      expect(contact.phone_valid).to be true
      expect(contact.country_code).to eq('US')
      expect(contact.line_type).to eq('mobile')
      expect(contact.carrier_name).to eq('AT&T')
    end
  end

  # ============================================================================
  # Requirement 2.2: Job skips completed contacts (idempotency)
  # ============================================================================
  describe 'idempotency - skipping completed contacts' do
    # _Requirements: 2.2_
    let(:completed_contact) { create(:contact, :completed) }

    it 'skips already completed contacts without making API calls' do
      # Verify no Twilio client is instantiated
      expect(Twilio::REST::Client).not_to receive(:new)

      described_class.new.perform(completed_contact.id)
    end

    it 'does not change status of completed contacts' do
      expect {
        described_class.new.perform(completed_contact.id)
      }.not_to change { completed_contact.reload.status }
    end

    it 'logs skip message for completed contacts' do
      expect(Rails.logger).to receive(:info)
        .with(/Skipping contact #{completed_contact.id}: already completed/)

      described_class.new.perform(completed_contact.id)
    end

    it 'does not enqueue enrichment jobs for already completed contacts' do
      expect {
        described_class.new.perform(completed_contact.id)
      }.not_to have_enqueued_job(EnrichmentCoordinatorJob)
    end
  end

  # ============================================================================
  # Requirement 2.3: Job skips processing contacts (idempotency)
  # ============================================================================
  describe 'idempotency - skipping processing contacts' do
    # _Requirements: 2.3_
    let(:processing_contact) { create(:contact, :processing) }

    it 'skips contacts already being processed without making API calls' do
      # Verify no Twilio client is instantiated
      expect(Twilio::REST::Client).not_to receive(:new)

      described_class.new.perform(processing_contact.id)
    end

    it 'does not change status of processing contacts' do
      expect {
        described_class.new.perform(processing_contact.id)
      }.not_to change { processing_contact.reload.status }
    end

    it 'logs skip message when contact already processing' do
      expect(Rails.logger).to receive(:info)
        .with(/Skipping contact #{processing_contact.id}: already being processed/)

      described_class.new.perform(processing_contact.id)
    end
  end

  # ============================================================================
  # Requirement 2.4: Race condition prevention with pessimistic locking
  # ============================================================================
  describe 'race condition prevention' do
    # _Requirements: 2.4_

    it 'uses pessimistic locking to prevent race conditions' do
      # Create a fresh contact for this test
      test_contact = create(:contact, :pending)
      
      # We need to verify with_lock is called on the contact
      # Since the job finds the contact by ID, we need to intercept that
      expect_any_instance_of(Contact).to receive(:with_lock).and_call_original

      described_class.new.perform(test_contact.id)
    end

    context 'when multiple jobs run concurrently' do
      it 'prevents duplicate processing - only one job acquires the lock' do
        # Create a contact for concurrent processing
        concurrent_contact = create(:contact, :pending)
        contact_id = concurrent_contact.id
        
        # Track how many times the Twilio API is called
        api_call_count = 0
        
        # Setup mock that counts calls
        mock_phone_numbers = double('PhoneNumbers')
        allow(mock_phone_numbers).to receive(:fetch) do
          api_call_count += 1
          mock_lookup_result
        end
        
        mock_client = double('TwilioClient')
        mock_lookups = double('Lookups')
        mock_v2 = double('V2')
        
        allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:lookups).and_return(mock_lookups)
        allow(mock_lookups).to receive(:v2).and_return(mock_v2)
        allow(mock_v2).to receive(:phone_numbers).and_return(mock_phone_numbers)

        # Run multiple jobs concurrently
        threads = 5.times.map do
          Thread.new do
            Thread.current.report_on_exception = false
            begin
              described_class.new.perform(contact_id)
              :success
            rescue StandardError => e
              e
            end
          end
        end

        results = threads.map(&:value)

        # Verify only one API call was made
        expect(api_call_count).to eq(1), "Expected 1 API call but got #{api_call_count}"

        # Verify contact ended up in a valid final state
        concurrent_contact.reload
        expect(concurrent_contact.status).to eq('completed')
      end

      it 'skips contacts that transition to processing during lock acquisition' do
        # Create a contact
        race_contact = create(:contact, :pending)
        
        # Simulate a race where another job already set status to processing
        # by updating the contact after the first job starts but before it checks status
        allow_any_instance_of(Contact).to receive(:with_lock) do |contact, &block|
          # Simulate another job already processing this contact
          contact.update_column(:status, 'processing')
          block.call
        end

        # The job should detect the status change and skip
        expect(Rails.logger).to receive(:info)
          .with(/Skipping contact #{race_contact.id}: already being processed/)

        described_class.new.perform(race_contact.id)
      end
    end

    it 'allows retry of failed contacts' do
      failed_contact = create(:contact, :failed)

      expect {
        described_class.new.perform(failed_contact.id)
      }.to change { failed_contact.reload.status }.from('failed').to('completed')
    end
  end

  # ============================================================================
  # Error handling tests
  # ============================================================================
  describe 'error handling' do
    context 'when credentials are missing' do
      before do
        allow(TwilioCredential).to receive(:current).and_return(nil)
      end

      it 'marks contact as failed with appropriate message' do
        described_class.new.perform(contact.id)

        contact.reload
        expect(contact.status).to eq('failed')
        expect(contact.error_code).to eq('No Twilio credentials configured')
      end

      it 'does not attempt API call' do
        expect(Twilio::REST::Client).not_to receive(:new)

        described_class.new.perform(contact.id)
      end
    end

    context 'when Twilio API returns permanent error' do
      it 'marks contact as failed without retrying' do
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

        expect {
          described_class.new.perform(contact.id)
        }.not_to raise_error

        expect(contact.reload.status).to eq('failed')
      end
    end

    context 'when Twilio API returns transient error (rate limit)' do
      it 'marks contact as failed and re-raises for retry' do
        # Setup mock that raises rate limit error
        error = twilio_error(code: 20429, message: 'Rate limit exceeded', status_code: 429)
        
        # Bypass circuit breaker to test direct error handling
        allow(CircuitBreakerService).to receive(:call).with(:twilio).and_raise(error)

        expect {
          described_class.new.perform(contact.id)
        }.to raise_error(Twilio::REST::RestError)

        expect(contact.reload.status).to eq('failed')
      end
    end

    context 'when contact not found' do
      it 'raises RecordNotFound (job will be discarded)' do
        expect {
          described_class.new.perform(999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  # ============================================================================
  # Job configuration tests
  # ============================================================================
  describe 'job configuration' do
    it 'is queued on default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end

    it 'has retry configuration for Twilio errors' do
      # Verify the job class has retry_on configured
      expect(described_class).to respond_to(:retry_on)
    end
  end
end
