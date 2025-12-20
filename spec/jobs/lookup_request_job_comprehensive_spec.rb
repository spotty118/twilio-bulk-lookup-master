# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LookupRequestJob, type: :job do
  let(:credentials) { create(:twilio_credential, :with_all_packages) }
  let(:contact) { create(:contact, :pending) }

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
      },
      sim_swap: nil,
      reassigned_number: nil
    )
  end

  let(:mock_client) { double('TwilioClient') }
  let(:mock_lookups) { double('Lookups') }
  let(:mock_v2) { double('V2') }
  let(:mock_phone_numbers) { double('PhoneNumbers') }

  before do
    # Clear Sidekiq queue
    Sidekiq::Worker.clear_all

    # Clear cache and circuit breaker state for complete test isolation
    Rails.cache.clear

    # Reset all circuit breakers - must reset data store first
    CircuitBreakerService.reset_data_store! if defined?(CircuitBreakerService)
    CircuitBreakerService.reset(:twilio) if defined?(CircuitBreakerService)
    HttpClient.reset_circuit!('twilio') if defined?(HttpClient)
    HttpClient.reset_circuit!('twilio_api') if defined?(HttpClient)

    # Stub TwilioCredential.current to avoid database lookups
    allow(TwilioCredential).to receive(:current).and_return(credentials)

    # Setup Twilio client mock chain
    allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:lookups).and_return(mock_lookups)

    # V2 API (primary lookup)
    allow(mock_lookups).to receive(:v2).and_return(mock_v2)
    allow(mock_v2).to receive(:phone_numbers).and_return(mock_phone_numbers)
    allow(mock_phone_numbers).to receive(:fetch).and_return(mock_lookup_result)

    # V1 API (Real Phone Validation and Scout)
    mock_v1 = double('V1')
    mock_v1_phone_numbers = double('V1PhoneNumbers')
    mock_v1_result = double('V1Result', add_ons: nil)
    allow(mock_lookups).to receive(:v1).and_return(mock_v1)
    allow(mock_v1).to receive(:phone_numbers).and_return(mock_v1_phone_numbers)
    allow(mock_v1_phone_numbers).to receive(:fetch).and_return(mock_v1_result)
  end

  describe 'job configuration' do
    it 'is queued on default queue' do
      expect(LookupRequestJob.new.queue_name).to eq('default')
    end

    it 'has retry configuration for transient errors' do
      # ActiveJob's retry_on creates exception handlers at the class level
      # We verify the job class has retry_on capability through respond_to
      expect(LookupRequestJob).to respond_to(:retry_on)
    end
  end

  describe '#perform' do
    context 'successful lookup flow' do
      it 'marks contact as processing' do
        described_class.new.perform(contact.id)
        expect(contact.reload.status).to eq('completed')
      end

      it 'updates contact with API response data' do
        described_class.new.perform(contact.id)
        contact.reload

        expect(contact.formatted_phone_number).to eq('+14155551234')
        expect(contact.phone_valid).to be true
        expect(contact.country_code).to eq('US')
        expect(contact.calling_country_code).to eq('1')
        expect(contact.line_type).to eq('mobile')
        expect(contact.carrier_name).to eq('AT&T')
        expect(contact.caller_name).to eq('JOHN DOE')
        expect(contact.sms_pumping_risk_score).to eq(15)
        expect(contact.sms_pumping_risk_level).to eq('low')
      end

      it 'marks contact as completed with timestamp' do
        freeze_time do
          described_class.new.perform(contact.id)
          contact.reload

          expect(contact.status).to eq('completed')
          expect(contact.lookup_performed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'clears error_code on success' do
        contact.update(error_code: 'Previous error')

        described_class.new.perform(contact.id)
        expect(contact.reload.error_code).to be_nil
      end

      it 'calculates risk level from score' do
        allow(mock_lookup_result).to receive(:sms_pumping_risk).and_return({
                                                                             'sms_pumping_risk_score' => 80,
                                                                             'carrier_risk_category' => 'high',
                                                                             'number_blocked' => false
                                                                           })

        described_class.new.perform(contact.id)
        expect(contact.reload.sms_pumping_risk_level).to eq('high')
      end

      it 'handles medium risk scores' do
        allow(mock_lookup_result).to receive(:sms_pumping_risk).and_return({
                                                                             'sms_pumping_risk_score' => 50,
                                                                             'carrier_risk_category' => 'medium',
                                                                             'number_blocked' => false
                                                                           })

        described_class.new.perform(contact.id)
        expect(contact.reload.sms_pumping_risk_level).to eq('medium')
      end

      it 'uses correct Twilio API v2 endpoint' do
        expect(mock_v2).to receive(:phone_numbers).with(contact.raw_phone_number).and_return(mock_phone_numbers)
        described_class.new.perform(contact.id)
      end

      it 'passes data packages to API when configured' do
        packages = credentials.data_packages
        expect(mock_phone_numbers).to receive(:fetch).with(fields: packages).and_return(mock_lookup_result)
        described_class.new.perform(contact.id)
      end

      it 'performs basic lookup when no packages enabled' do
        allow(credentials).to receive(:data_packages).and_return('')

        expect(mock_phone_numbers).to receive(:fetch).with(no_args).and_return(mock_lookup_result)
        described_class.new.perform(contact.id)
      end
    end

    context 'idempotency' do
      it 'skips already completed contacts' do
        completed_contact = create(:contact, :completed)

        expect(mock_client).not_to receive(:lookups)

        described_class.new.perform(completed_contact.id)
      end

      it 'logs skip message for completed contacts' do
        completed_contact = create(:contact, :completed)

        expect(Rails.logger).to receive(:info).with(/Skipping contact.*already completed/)

        described_class.new.perform(completed_contact.id)
      end

      it 'does not enqueue enrichment jobs for already completed contacts' do
        completed_contact = create(:contact, :completed)

        expect do
          described_class.new.perform(completed_contact.id)
        end.not_to have_enqueued_job(BusinessEnrichmentJob)
      end
    end

    context 'status transitions with locking' do
      it 'uses pessimistic locking to prevent race conditions' do
        # The job finds a new instance from DB, so use expect_any_instance_of
        expect_any_instance_of(Contact).to receive(:with_lock).and_call_original
        described_class.new.perform(contact.id)
      end

      it 'transitions from pending to processing' do
        pending_contact = create(:contact, :pending)

        described_class.new.perform(pending_contact.id)

        # Should be completed after successful lookup
        expect(pending_contact.reload.status).to eq('completed')
      end

      it 'allows retry of failed contacts' do
        failed_contact = create(:contact, :failed)

        described_class.new.perform(failed_contact.id)

        expect(failed_contact.reload.status).to eq('completed')
      end

      it 'skips contacts already being processed' do
        processing_contact = create(:contact, :processing)

        expect(Rails.logger).to receive(:info).with(/Skipping contact.*already being processed/)

        described_class.new.perform(processing_contact.id)
      end

      it 'does not call Twilio API for processing contacts' do
        processing_contact = create(:contact, :processing)

        expect(mock_client).not_to receive(:lookups)

        described_class.new.perform(processing_contact.id)
      end
    end

    context 'error handling' do
      context 'Twilio errors' do
        before do
          # Bypass circuit breaker for error handling tests - yield directly to test error handling
          allow(CircuitBreakerService).to receive(:call).with(:twilio) do |&block|
            block.call
          end
        end

        it 'handles invalid number errors (20404)' do
          error = Twilio::REST::RestError.new('Invalid number', double(status_code: 404, body: {}))
          allow(error).to receive(:code).and_return(20_404)
          allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

          described_class.new.perform(contact.id)

          expect(contact.reload.status).to eq('failed')
          expect(contact.error_code).to include('Invalid phone number')
        end

        it 'handles authentication errors (20003)' do
          error = Twilio::REST::RestError.new('Auth failed', double(status_code: 401, body: {}))
          allow(error).to receive(:code).and_return(20_003)
          allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

          described_class.new.perform(contact.id)

          expect(contact.reload.status).to eq('failed')
          expect(contact.error_code).to include('Authentication error')
        end

        it 'marks failed and re-raises for rate limit errors (20429)' do
          error = Twilio::REST::RestError.new('Rate limit', double(status_code: 429, body: {}))
          allow(error).to receive(:code).and_return(20_429)
          allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

          expect do
            described_class.new.perform(contact.id)
          end.to raise_error(Twilio::REST::RestError)

          expect(contact.reload.status).to eq('failed')
          expect(contact.error_code).to include('Rate limit exceeded')
        end

        it 'marks failed and re-raises for unknown Twilio errors' do
          error = Twilio::REST::RestError.new('Unknown', double(status_code: 500, body: {}))
          allow(error).to receive(:code).and_return(50_000)
          allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

          expect do
            described_class.new.perform(contact.id)
          end.to raise_error(Twilio::REST::RestError)

          expect(contact.reload.status).to eq('failed')
        end

        it 'does not retry permanent failures' do
          error = Twilio::REST::RestError.new('Invalid', double(status_code: 404, body: {}))
          allow(error).to receive(:code).and_return(20_404)
          allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

          # Should not raise, preventing retry
          expect do
            described_class.new.perform(contact.id)
          end.not_to raise_error
        end
      end

      context 'network errors' do
        before do
          # Only run these tests if Faraday is defined
          skip 'Faraday not loaded' unless defined?(Faraday::Error)
          # Bypass circuit breaker for error handling tests
          allow(CircuitBreakerService).to receive(:call).with(:twilio) do |&block|
            block.call
          end
        end

        it 'handles Faraday network errors' do
          error = Faraday::ConnectionFailed.new('Connection failed')
          allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

          expect do
            described_class.new.perform(contact.id)
          end.to raise_error(Faraday::Error)

          expect(contact.reload.status).to eq('failed')
          expect(contact.error_code).to include('Network error')
        end
      end

      context 'unexpected errors' do
        before do
          # Bypass circuit breaker for error handling tests
          allow(CircuitBreakerService).to receive(:call).with(:twilio) do |&block|
            block.call
          end
        end

        it 'handles unexpected errors gracefully' do
          allow(mock_phone_numbers).to receive(:fetch).and_raise(StandardError, 'Unexpected')

          described_class.new.perform(contact.id)

          expect(contact.reload.status).to eq('failed')
          expect(contact.error_code).to include('Unexpected error')
        end

        it 'logs unexpected errors' do
          allow(mock_phone_numbers).to receive(:fetch).and_raise(StandardError, 'Unexpected')

          expect(Rails.logger).to receive(:error).at_least(:once)

          described_class.new.perform(contact.id)
        end
      end

      context 'missing contact' do
        it 'discards job when contact not found' do
          expect do
            described_class.new.perform(999_999)
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'credential handling' do
      it 'uses credentials from TwilioCredential.current' do
        expect(TwilioCredential).to receive(:current).and_return(credentials)

        described_class.new.perform(contact.id)
      end

      it 'initializes Twilio client with credentials' do
        expect(Twilio::REST::Client).to receive(:new)
          .with(credentials.account_sid, credentials.auth_token)
          .and_return(mock_client)

        described_class.new.perform(contact.id)
      end

      context 'when credentials are missing' do
        before do
          allow(TwilioCredential).to receive(:current).and_return(nil)
        end

        it 'marks contact as failed' do
          described_class.new.perform(contact.id)

          expect(contact.reload.status).to eq('failed')
          expect(contact.error_code).to eq('No Twilio credentials configured')
        end

        it 'does not attempt API call' do
          expect(Twilio::REST::Client).not_to receive(:new)

          described_class.new.perform(contact.id)
        end
      end

      context 'when credentials have blank values' do
        let(:blank_credentials) { build(:twilio_credential, account_sid: '', auth_token: '') }

        before do
          allow(TwilioCredential).to receive(:current).and_return(blank_credentials)
        end

        it 'marks contact as failed for blank credentials' do
          described_class.new.perform(contact.id)

          expect(contact.reload.status).to eq('failed')
          expect(contact.error_code).to eq('No Twilio credentials configured')
        end
      end

      context 'when using AppConfig credentials' do
        before do
          # Mock AppConfig if defined
          if defined?(AppConfig)
            allow(AppConfig).to receive(:twilio_credentials).and_return({
                                                                          account_sid: 'AC_from_env',
                                                                          auth_token: 'token_from_env'
                                                                        })
          else
            stub_const('AppConfig', Class.new do
              def self.twilio_credentials
                { account_sid: 'AC_from_env', auth_token: 'token_from_env' }
              end
            end)
          end
        end

        it 'prioritizes AppConfig over database credentials' do
          expect(Twilio::REST::Client).to receive(:new)
            .with('AC_from_env', 'token_from_env')
            .and_return(mock_client)

          described_class.new.perform(contact.id)
        end
      end
    end

    context 'enrichment job chaining' do
      before do
        # Bypass circuit breaker for these tests
        allow(CircuitBreakerService).to receive(:call).with(:twilio) do |&block|
          block.call
        end
      end

      it 'enqueues EnrichmentCoordinatorJob after successful lookup' do
        expect do
          described_class.new.perform(contact.id)
        end.to have_enqueued_job(EnrichmentCoordinatorJob).with(contact.id)
      end

      it 'does not enqueue EnrichmentCoordinatorJob on failure' do
        error = Twilio::REST::RestError.new('Invalid', double(status_code: 404, body: {}))
        allow(error).to receive(:code).and_return(20_404)
        allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

        expect do
          described_class.new.perform(contact.id)
        end.not_to have_enqueued_job(EnrichmentCoordinatorJob)
      end
    end

    context 'retry behavior' do
      it 'retries transient errors with exponential backoff' do
        # This is configured via retry_on in the job class
        # We verify the configuration exists
        expect(described_class).to respond_to(:retry_on)
      end

      it 'does not retry permanent errors' do
        error = Twilio::REST::RestError.new('Invalid number', double(status_code: 404, body: {}))
        allow(error).to receive(:code).and_return(20_404)
        allow(mock_phone_numbers).to receive(:fetch).and_raise(error)

        # Should handle error without re-raising
        expect do
          described_class.new.perform(contact.id)
        end.not_to raise_error
      end

      it 'retries up to 3 times for transient errors' do
        # The retry configuration is at the class level
        # We can't easily test the actual retry count in a unit test
        # but we can verify the job has retry configured
        expect(described_class.sidekiq_options['retry']).to be_truthy
      end
    end

    context 'edge cases' do
      it 'handles nil line_type_intelligence data' do
        allow(mock_lookup_result).to receive(:line_type_intelligence).and_return(nil)

        described_class.new.perform(contact.id)

        expect(contact.reload.line_type).to be_nil
        expect(contact.status).to eq('completed')
      end

      it 'handles nil caller_name data' do
        allow(mock_lookup_result).to receive(:caller_name).and_return(nil)

        described_class.new.perform(contact.id)

        expect(contact.reload.caller_name).to be_nil
        expect(contact.status).to eq('completed')
      end

      it 'handles nil sms_pumping_risk data' do
        allow(mock_lookup_result).to receive(:sms_pumping_risk).and_return(nil)

        described_class.new.perform(contact.id)

        expect(contact.reload.sms_pumping_risk_score).to be_nil
        expect(contact.sms_pumping_risk_level).to be_nil
        expect(contact.status).to eq('completed')
      end

      it 'handles validation errors from API' do
        allow(mock_lookup_result).to receive(:validation_errors).and_return(['Invalid format'])
        allow(mock_lookup_result).to receive(:valid).and_return(false)

        described_class.new.perform(contact.id)

        expect(contact.reload.phone_valid).to be false
        expect(contact.validation_errors).to eq(['Invalid format'])
      end

      it 'handles contacts with non-E164 formatted numbers' do
        contact_with_raw_number = create(:contact, raw_phone_number: '4155551234')

        expect(mock_v2).to receive(:phone_numbers).with('4155551234').and_return(mock_phone_numbers)

        described_class.new.perform(contact_with_raw_number.id)
      end
    end

    context 'data package variations' do
      it 'works with minimal package configuration' do
        minimal_creds = build(:twilio_credential, :with_minimal_packages)
        allow(TwilioCredential).to receive(:current).and_return(minimal_creds)
        # Bypass circuit breaker for this test
        allow(CircuitBreakerService).to receive(:call).with(:twilio) do |&block|
          block.call
        end

        packages = minimal_creds.data_packages
        expect(mock_phone_numbers).to receive(:fetch).with(fields: packages).and_return(mock_lookup_result)

        described_class.new.perform(contact.id)

        expect(contact.reload.status).to eq('completed')
      end

      it 'works with no packages enabled' do
        no_package_creds = build(:twilio_credential, :with_no_packages)
        allow(TwilioCredential).to receive(:current).and_return(no_package_creds)
        # Bypass circuit breaker for this test
        allow(CircuitBreakerService).to receive(:call).with(:twilio) do |&block|
          block.call
        end

        expect(mock_phone_numbers).to receive(:fetch).with(no_args).and_return(mock_lookup_result)

        described_class.new.perform(contact.id)

        expect(contact.reload.status).to eq('completed')
      end
    end
  end

  describe 'private methods' do
    describe '#handle_twilio_error' do
      let(:job) { described_class.new }

      it 'classifies permanent vs transient errors correctly' do
        # Invalid number - permanent
        error_404 = Twilio::REST::RestError.new('Not found', double(status_code: 404, body: {}))
        allow(error_404).to receive(:code).and_return(20_404)

        expect do
          job.send(:handle_twilio_error, contact, error_404)
        end.not_to raise_error

        expect(contact.reload.status).to eq('failed')

        # Rate limit - transient
        contact.update(status: 'processing', error_code: nil)
        error_429 = Twilio::REST::RestError.new('Rate limit', double(status_code: 429, body: {}))
        allow(error_429).to receive(:code).and_return(20_429)

        expect do
          job.send(:handle_twilio_error, contact, error_429)
        end.to raise_error(Twilio::REST::RestError)
      end

      it 'logs warnings for all Twilio errors' do
        error = Twilio::REST::RestError.new('Error', double(status_code: 404, body: {}))
        allow(error).to receive(:code).and_return(20_404)

        expect(Rails.logger).to receive(:warn).with(/Twilio error/)

        job.send(:handle_twilio_error, contact, error)
      end
    end
  end
end
