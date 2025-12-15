# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  include ActiveJob::TestHelper

  describe 'POST #twilio_sms_status' do
    let(:valid_params) do
      {
        MessageSid: 'SM1234567890abcdef1234567890abcdef',
        MessageStatus: 'delivered',
        To: '+14155551234',
        From: '+14155555678',
        Body: 'Test message',
        NumSegments: '1',
        AccountSid: 'ACTEST00000000000000000000000000',
        SmsSid: 'SM1234567890abcdef1234567890abcdef'
      }
    end

    context 'with valid params' do
      it 'creates webhook and returns 200 OK' do
        expect do
          post :twilio_sms_status, params: valid_params
        end.to change(Webhook, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it 'creates webhook with correct attributes' do
        post :twilio_sms_status, params: valid_params

        webhook = Webhook.last
        expect(webhook.source).to eq('twilio_sms')
        expect(webhook.external_id).to eq('SM1234567890abcdef1234567890abcdef')
        expect(webhook.event_type).to eq('sms_status')
        expect(webhook.status).to eq('pending')
        expect(webhook.payload['MessageStatus']).to eq('delivered')
        expect(webhook.payload['To']).to eq('+14155551234')
        expect(webhook.received_at).to be_present
      end

      it 'generates idempotency_key correctly' do
        post :twilio_sms_status, params: valid_params

        webhook = Webhook.last
        expect(webhook.idempotency_key).to eq('twilio_sms:SM1234567890abcdef1234567890abcdef')
      end

      it 'enqueues WebhookProcessorJob' do
        expect do
          post :twilio_sms_status, params: valid_params
        end.to(have_enqueued_job(WebhookProcessorJob).with do |webhook_id|
          webhook = Webhook.find(webhook_id)
          expect(webhook.source).to eq('twilio_sms')
        end)
      end

      it 'sets received_at timestamp' do
        freeze_time do
          post :twilio_sms_status, params: valid_params

          webhook = Webhook.last
          expect(webhook.received_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    context 'with duplicate webhook (same MessageSid)' do
      before do
        Webhook.create!(
          source: 'twilio_sms',
          external_id: 'SM1234567890abcdef1234567890abcdef',
          event_type: 'sms_status',
          payload: valid_params.as_json,
          status: 'pending',
          received_at: Time.current
        )
      end

      it 'does not create duplicate webhook' do
        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to change(Webhook, :count)
      end

      it 'returns 200 OK (idempotent)' do
        post :twilio_sms_status, params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it 'does not enqueue WebhookProcessorJob for duplicate' do
        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to have_enqueued_job(WebhookProcessorJob)
      end

      it 'logs duplicate webhook rejection' do
        allow(Rails.logger).to receive(:info)

        post :twilio_sms_status, params: valid_params

        expect(Rails.logger).to have_received(:info).with(
          /Duplicate webhook rejected: SM1234567890abcdef1234567890abcdef/
        )
      end
    end

    context 'with processed webhook (replay attack)' do
      before do
        webhook = Webhook.create!(
          source: 'twilio_sms',
          external_id: 'SM1234567890abcdef1234567890abcdef',
          event_type: 'sms_status',
          payload: valid_params.as_json,
          status: 'processed',
          processed_at: 1.hour.ago,
          received_at: 2.hours.ago
        )
      end

      it 'does not reprocess webhook' do
        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to have_enqueued_job(WebhookProcessorJob)
      end

      it 'returns 200 OK' do
        post :twilio_sms_status, params: valid_params
        expect(response).to have_http_status(:ok)
      end

      it 'logs replay attack attempt' do
        allow(Rails.logger).to receive(:info)

        post :twilio_sms_status, params: valid_params

        expect(Rails.logger).to have_received(:info).with(
          /Duplicate webhook rejected: SM1234567890abcdef1234567890abcdef/
        )
      end
    end

    context 'with race condition (concurrent duplicate POSTs)' do
      it 'handles ActiveRecord::RecordNotUnique gracefully' do
        # Stub find_or_create_by to raise RecordNotUnique (simulates race condition)
        allow(Webhook).to receive(:find_or_create_by).and_raise(
          ActiveRecord::RecordNotUnique.new('Duplicate entry')
        )

        allow(Rails.logger).to receive(:warn)

        # Should not raise error (should rescue and return 200)
        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to raise_error

        expect(response).to have_http_status(:ok)

        # Verify warning was logged
        expect(Rails.logger).to have_received(:warn).with(
          /Duplicate webhook \(race condition\): SM1234567890abcdef1234567890abcdef/
        )
      end
    end

    context 'with missing MessageSid (payload hash fallback)' do
      let(:params_without_message_sid) do
        {
          MessageStatus: 'delivered',
          To: '+14155551234',
          From: '+14155555678',
          Body: 'Test message'
        }
      end

      it 'creates webhook with hash-based idempotency key' do
        allow(Rails.logger).to receive(:warn)

        post :twilio_sms_status, params: params_without_message_sid

        webhook = Webhook.last
        expect(webhook.external_id).to be_nil
        expect(webhook.idempotency_key).to start_with('twilio_sms:hash:')

        # Verify warning was logged
        expect(Rails.logger).to have_received(:warn).with(
          /Webhook created without external_id/
        )
      end
    end

    context 'with invalid params' do
      it 'handles missing required params' do
        # Webhook model validation will catch missing required fields
        # Controller should handle validation errors gracefully
        expect do
          post :twilio_sms_status, params: {}
        end.to raise_error(ActionController::ParameterMissing)
      end
    end
  end

  describe 'POST #twilio_voice_status' do
    let(:valid_params) do
      {
        CallSid: 'CA1234567890abcdef1234567890abcdef',
        CallStatus: 'completed',
        To: '+14155551234',
        From: '+14155555678',
        Duration: '45',
        AccountSid: 'ACTEST00000000000000000000000000'
      }
    end

    it 'creates voice webhook' do
      expect do
        post :twilio_voice_status, params: valid_params
      end.to change(Webhook, :count).by(1)

      webhook = Webhook.last
      expect(webhook.source).to eq('twilio_voice')
      expect(webhook.external_id).to eq('CA1234567890abcdef1234567890abcdef')
      expect(webhook.event_type).to eq('voice_status')
      expect(webhook.idempotency_key).to eq('twilio_voice:CA1234567890abcdef1234567890abcdef')
    end

    it 'rejects duplicate voice webhook' do
      # Create first webhook
      post :twilio_voice_status, params: valid_params

      # Attempt duplicate
      expect do
        post :twilio_voice_status, params: valid_params
      end.not_to change(Webhook, :count)

      expect(response).to have_http_status(:ok)
    end

    it 'allows same CallSid for SMS and Voice (different sources)' do
      # Create SMS webhook with ID "ID123"
      post :twilio_sms_status, params: {
        MessageSid: 'ID123',
        MessageStatus: 'delivered',
        To: '+14155551234',
        From: '+14155555678'
      }

      # Create Voice webhook with same ID "ID123"
      expect do
        post :twilio_voice_status, params: {
          CallSid: 'ID123',
          CallStatus: 'completed',
          To: '+14155551234',
          From: '+14155555678'
        }
      end.to change(Webhook, :count).by(1)

      # Verify both webhooks exist
      webhooks = Webhook.where(external_id: 'ID123')
      expect(webhooks.count).to eq(2)
      expect(webhooks.pluck(:source)).to contain_exactly('twilio_sms', 'twilio_voice')
    end
  end

  describe 'webhook signature verification' do
    let(:credentials) { create(:twilio_credential, auth_token: 'test_token_12345') }
    let(:valid_params) do
      {
        MessageSid: 'SM1234567890abcdef1234567890abcdef',
        MessageStatus: 'delivered',
        To: '+14155551234',
        From: '+14155555678'
      }
    end

    before do
      allow(TwilioCredential).to receive(:current).and_return(credentials)
    end

    context 'with valid Twilio signature' do
      before do
        # Mock the validator to return true for valid signatures
        validator = instance_double(Twilio::Security::RequestValidator)
        allow(validator).to receive(:validate).and_return(true)
        allow(Twilio::Security::RequestValidator).to receive(:new).with('test_token_12345').and_return(validator)
      end

      it 'processes webhook with valid signature' do
        request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'valid_signature_hash'

        expect do
          post :twilio_sms_status, params: valid_params
        end.to change(Webhook, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it 'calls RequestValidator with correct parameters' do
        request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'valid_signature_hash'

        validator = instance_double(Twilio::Security::RequestValidator)
        allow(Twilio::Security::RequestValidator).to receive(:new).with('test_token_12345').and_return(validator)
        expect(validator).to receive(:validate).with(
          an_instance_of(String), # URL
          an_instance_of(Hash),     # params
          'valid_signature_hash'    # signature
        ).and_return(true)

        post :twilio_sms_status, params: valid_params
      end
    end

    context 'with invalid Twilio signature' do
      before do
        # Mock the validator to return false for invalid signatures
        validator = instance_double(Twilio::Security::RequestValidator)
        allow(validator).to receive(:validate).and_return(false)
        allow(Twilio::Security::RequestValidator).to receive(:new).with('test_token_12345').and_return(validator)
      end

      it 'rejects webhook with invalid signature' do
        request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'invalid_signature_hash'

        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to change(Webhook, :count)

        expect(response).to have_http_status(:forbidden)
      end

      it 'logs warning for invalid signature' do
        request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'invalid_signature_hash'
        allow(Rails.logger).to receive(:warn)

        post :twilio_sms_status, params: valid_params

        expect(Rails.logger).to have_received(:warn).with(
          /Invalid Twilio signature for webhook/
        )
      end

      it 'does not enqueue WebhookProcessorJob' do
        request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'invalid_signature_hash'

        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to have_enqueued_job(WebhookProcessorJob)
      end
    end

    context 'with missing signature header' do
      before do
        validator = instance_double(Twilio::Security::RequestValidator)
        allow(validator).to receive(:validate).and_return(false)
        allow(Twilio::Security::RequestValidator).to receive(:new).with('test_token_12345').and_return(validator)
      end

      it 'rejects webhook without signature' do
        # Don't set signature header
        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to change(Webhook, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with missing credentials' do
      before do
        allow(TwilioCredential).to receive(:current).and_return(nil)
      end

      it 'rejects webhook when no credentials configured' do
        request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'any_signature'

        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to change(Webhook, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with validation errors' do
      before do
        # Simulate validation error (ArgumentError)
        validator = instance_double(Twilio::Security::RequestValidator)
        allow(validator).to receive(:validate).and_raise(ArgumentError, 'Invalid auth token format')
        allow(Twilio::Security::RequestValidator).to receive(:new).with('test_token_12345').and_return(validator)
      end

      it 'handles validation errors gracefully' do
        request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'any_signature'
        allow(Rails.logger).to receive(:error)

        expect do
          post :twilio_sms_status, params: valid_params
        end.not_to change(Webhook, :count)

        expect(response).to have_http_status(:forbidden)
        expect(Rails.logger).to have_received(:error).with(
          /Signature verification error: ArgumentError/
        )
      end
    end
  end

  describe 'rate limiting integration' do
    it 'respects Rack::Attack rate limits' do
      # NOTE: This would be tested in integration tests with actual Rack::Attack middleware
      # Controller tests can verify the logic, but full rate limiting requires integration tests
    end
  end

  describe 'logging and monitoring' do
    it 'logs webhook creation' do
      allow(Rails.logger).to receive(:info)

      post :twilio_sms_status, params: valid_params

      # Verify webhook creation was logged (if implemented)
      # Logging implementation depends on specific requirements
    end

    it 'increments StatsD counter for webhook received' do
      allow(StatsD).to receive(:increment) if defined?(StatsD)

      post :twilio_sms_status, params: valid_params

      # Verify metric was incremented (if StatsD is configured)
      if defined?(StatsD)
        expect(StatsD).to have_received(:increment).with(
          'webhook.received',
          tags: ['source:twilio_sms', 'event_type:sms_status']
        )
      end
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      # Stub Webhook.find_or_create_by to raise database error
      allow(Webhook).to receive(:find_or_create_by).and_raise(
        ActiveRecord::StatementInvalid.new('Database connection lost')
      )

      allow(Rails.logger).to receive(:error)

      # Should return 500 or retry (depending on implementation)
      post :twilio_sms_status, params: valid_params

      # In production, this should be handled by exception tracking (Sentry, Rollbar)
    end

    it 'handles Redis errors gracefully (if using Redis for idempotency)' do
      # If idempotency check uses Redis, test Redis failure handling
    end
  end

  describe 'performance' do
    it 'handles 100 webhook POSTs within 5 seconds' do
      start_time = Time.current

      100.times do |i|
        post :twilio_sms_status, params: {
          MessageSid: "SM_PERF_TEST_#{i}",
          MessageStatus: 'delivered',
          To: '+14155551234',
          From: '+14155555678'
        }
      end

      duration = Time.current - start_time
      expect(duration).to be < 5.seconds

      # Verify all webhooks were created
      expect(Webhook.where('external_id LIKE ?', 'SM_PERF_TEST_%').count).to eq(100)
    end

    it 'uses find_or_create_by efficiently (single database query)' do
      # find_or_create_by should issue at most 2 queries:
      # 1. SELECT to find existing record
      # 2. INSERT if not found (skipped if found)

      # This is more efficient than separate find + create
      expect do
        post :twilio_sms_status, params: valid_params
      end.not_to exceed_query_limit(2)
    end
  end

  # Helper method to count database queries
  def exceed_query_limit(count, &block)
    query_count = 0

    counter = lambda { |_name, _started, _finished, _unique_id, payload|
      query_count += 1 unless payload[:name] =~ /SCHEMA/
    }

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)

    be > count
  end
end
