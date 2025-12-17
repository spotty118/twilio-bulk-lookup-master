# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  include ActiveJob::TestHelper

  # Shared setup for bypassing Twilio signature verification
  # Use a valid 32-character hex auth token
  let(:valid_auth_token) { SecureRandom.hex(16) }
  let(:credentials) { create(:twilio_credential, auth_token: valid_auth_token) }

  before do
    # Mock TwilioCredential.current to return our test credentials
    allow(TwilioCredential).to receive(:current).and_return(credentials)

    # Mock the Twilio signature validator to always return true (bypass verification)
    validator = instance_double(Twilio::Security::RequestValidator)
    allow(validator).to receive(:validate).and_return(true)
    allow(Twilio::Security::RequestValidator).to receive(:new).and_return(validator)

    # Set a valid signature header
    request.headers['HTTP_X_TWILIO_SIGNATURE'] = 'valid_signature_hash'
  end

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

    # Requirements 5.1: Valid webhook returns 200 and creates record
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
        end.to have_enqueued_job(WebhookProcessorJob)
      end

      it 'sets received_at timestamp' do
        freeze_time do
          post :twilio_sms_status, params: valid_params

          webhook = Webhook.last
          expect(webhook.received_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    # Requirements 5.4: Duplicate MessageSid handled gracefully
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

      it 'logs duplicate webhook info' do
        allow(Rails.logger).to receive(:info)

        post :twilio_sms_status, params: valid_params

        expect(Rails.logger).to have_received(:info).with(
          /Duplicate SMS webhook ignored \(pending\): SM1234567890abcdef1234567890abcdef/
        )
      end
    end

    # Requirements 5.4: Duplicate with processed status (replay attack)
    context 'with processed webhook (replay attack)' do
      before do
        Webhook.create!(
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

      it 'logs replay rejection' do
        allow(Rails.logger).to receive(:info)

        post :twilio_sms_status, params: valid_params

        expect(Rails.logger).to have_received(:info).with(
          /Duplicate SMS webhook rejected \(already processed\): SM1234567890abcdef1234567890abcdef/
        )
      end
    end

    # Requirements 5.3: Unexpected error returns 200
    context 'with race condition (concurrent duplicate POSTs)' do
      it 'handles ActiveRecord::RecordNotUnique gracefully and returns 200' do
        # Stub find_or_initialize_by to raise RecordNotUnique (simulates race condition)
        allow(Webhook).to receive(:find_or_initialize_by).and_raise(
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
          /Duplicate SMS webhook \(race condition\): SM1234567890abcdef1234567890abcdef/
        )
      end
    end

    # Requirements 5.2: Validation failure returns 200 and logs error
    context 'with validation failure' do
      it 'returns 200 OK and logs error when webhook save fails' do
        # Create a webhook that will fail validation on save
        invalid_webhook = Webhook.new(
          source: 'twilio_sms',
          external_id: 'SM1234567890abcdef1234567890abcdef',
          event_type: 'sms_status',
          payload: valid_params.as_json,
          status: 'pending',
          received_at: Time.current
        )

        # Make the webhook appear as new but fail on save
        allow(Webhook).to receive(:find_or_initialize_by).and_return(invalid_webhook)
        allow(invalid_webhook).to receive(:new_record?).and_return(true)
        allow(invalid_webhook).to receive(:save).and_return(false)
        allow(invalid_webhook).to receive(:errors).and_return(
          double(full_messages: ['Idempotency key has already been taken'])
        )

        allow(Rails.logger).to receive(:error)

        post :twilio_sms_status, params: valid_params

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:error).with(
          /Failed to create SMS webhook: Idempotency key has already been taken/
        )
      end
    end

    # Requirements 5.3: Unexpected error returns 200
    context 'with unexpected error' do
      it 'returns 200 OK and logs error on StandardError' do
        allow(Webhook).to receive(:find_or_initialize_by).and_raise(
          StandardError.new('Unexpected database error')
        )

        allow(Rails.logger).to receive(:error)

        post :twilio_sms_status, params: valid_params

        expect(response).to have_http_status(:ok)
        expect(Rails.logger).to have_received(:error).with(
          /SMS webhook error: StandardError - Unexpected database error/
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

    it 'creates voice webhook and returns 200' do
      expect do
        post :twilio_voice_status, params: valid_params
      end.to change(Webhook, :count).by(1)

      expect(response).to have_http_status(:ok)

      webhook = Webhook.last
      expect(webhook.source).to eq('twilio_voice')
      expect(webhook.external_id).to eq('CA1234567890abcdef1234567890abcdef')
      expect(webhook.event_type).to eq('voice_status')
      expect(webhook.idempotency_key).to eq('twilio_voice:CA1234567890abcdef1234567890abcdef')
    end

    it 'rejects duplicate voice webhook and returns 200' do
      # Create first webhook
      post :twilio_voice_status, params: valid_params

      # Attempt duplicate
      expect do
        post :twilio_voice_status, params: valid_params
      end.not_to change(Webhook, :count)

      expect(response).to have_http_status(:ok)
    end

    it 'allows same ID for SMS and Voice (different sources)' do
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

  describe 'POST #twilio_trust_hub' do
    let(:valid_params) do
      {
        CustomerProfileSid: 'BU1234567890abcdef1234567890abcdef',
        StatusCallbackEvent: 'verification_status',
        Status: 'twilio-approved'
      }
    end

    it 'creates trust hub webhook and returns 200' do
      expect do
        post :twilio_trust_hub, params: valid_params
      end.to change(Webhook, :count).by(1)

      expect(response).to have_http_status(:ok)

      webhook = Webhook.last
      expect(webhook.source).to eq('twilio_trust_hub')
      expect(webhook.external_id).to eq('BU1234567890abcdef1234567890abcdef')
      expect(webhook.event_type).to eq('verification_status')
    end
  end

  describe 'webhook signature verification' do
    let(:valid_params) do
      {
        MessageSid: 'SM1234567890abcdef1234567890abcdef',
        MessageStatus: 'delivered',
        To: '+14155551234',
        From: '+14155555678'
      }
    end

    context 'with invalid Twilio signature' do
      before do
        # Mock the validator to return false for invalid signatures
        validator = instance_double(Twilio::Security::RequestValidator)
        allow(validator).to receive(:validate).and_return(false)
        allow(Twilio::Security::RequestValidator).to receive(:new).and_return(validator)
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

    context 'with validation errors during signature check' do
      before do
        # Simulate validation error (ArgumentError)
        validator = instance_double(Twilio::Security::RequestValidator)
        allow(validator).to receive(:validate).and_raise(ArgumentError, 'Invalid auth token format')
        allow(Twilio::Security::RequestValidator).to receive(:new).and_return(validator)
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

  describe 'POST #generic' do
    let(:valid_params) do
      {
        source: 'custom_source',
        event_type: 'custom_event',
        external_id: 'EXT123',
        data: { key: 'value' }
      }
    end

    it 'creates generic webhook and returns success JSON' do
      expect do
        post :generic, params: valid_params
      end.to change(Webhook, :count).by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['webhook_id']).to be_present
    end

    it 'returns error JSON when webhook creation fails' do
      # Force validation failure by creating duplicate first
      Webhook.create!(
        source: 'custom_source',
        external_id: 'EXT123',
        event_type: 'custom_event',
        payload: {},
        status: 'pending',
        received_at: Time.current
      )

      post :generic, params: valid_params

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['errors']).to be_present
    end
  end
end
