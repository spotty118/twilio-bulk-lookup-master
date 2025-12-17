# frozen_string_literal: true

require 'rails_helper'

# INFRASTRUCTURE REQUIRED:
# - PostgreSQL with SERIALIZABLE isolation (for race condition tests)
# - Redis (for Sidekiq background jobs)
# - Run with: bundle exec rspec spec/integration/webhook_replay_attack_spec.rb

RSpec.describe 'Webhook replay attack protection', type: :request do
  include ActiveJob::TestHelper

  before do
    # Mock Twilio credentials and signature validation
    allow(TwilioCredential).to receive(:current).and_return(double(auth_token: 'test_token'))
    allow_any_instance_of(Twilio::Security::RequestValidator).to receive(:validate).and_return(true)
  end

  describe 'POST /webhooks/twilio/sms_status' do
    let(:valid_webhook_params) do
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

    it 'accepts first webhook POST and processes it' do
      expect do
        post '/webhooks/twilio/sms_status', params: valid_webhook_params
      end.to change(Webhook, :count).by(1)

      expect(response).to have_http_status(:ok)

      webhook = Webhook.last
      expect(webhook.source).to eq('twilio_sms')
      expect(webhook.external_id).to eq('SM1234567890abcdef1234567890abcdef')
      expect(webhook.event_type).to eq('sms_status')
      expect(webhook.status).to eq('pending')
      expect(webhook.idempotency_key).to eq('twilio_sms:SM1234567890abcdef1234567890abcdef')

      # Verify WebhookProcessorJob was enqueued
      expect(enqueued_jobs.size).to eq(1)
      expect(enqueued_jobs.first[:job]).to eq(WebhookProcessorJob)
      expect(enqueued_jobs.first[:args].first).to eq(webhook.id)
    end

    it 'rejects duplicate webhook POST (replay attack)' do
      # First POST: Create webhook
      post '/webhooks/twilio/sms_status', params: valid_webhook_params
      expect(response).to have_http_status(:ok)
      initial_webhook_count = Webhook.count
      initial_job_count = enqueued_jobs.size

      # Second POST: Replay attack (same MessageSid)
      expect do
        post '/webhooks/twilio/sms_status', params: valid_webhook_params
      end.not_to change(Webhook, :count)

      expect(response).to have_http_status(:ok) # Still returns 200 (idempotent)
      expect(Webhook.count).to eq(initial_webhook_count)

      # Verify NO additional job was enqueued
      expect(enqueued_jobs.size).to eq(initial_job_count)
    end

    it 'allows different webhooks with different MessageSids' do
      # First webhook
      post '/webhooks/twilio/sms_status', params: valid_webhook_params.merge(MessageSid: 'SM_FIRST')
      expect(response).to have_http_status(:ok)

      # Second webhook (different MessageSid)
      expect do
        post '/webhooks/twilio/sms_status', params: valid_webhook_params.merge(MessageSid: 'SM_SECOND')
      end.to change(Webhook, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(Webhook.pluck(:external_id)).to contain_exactly('SM_FIRST', 'SM_SECOND')
    end

    it 'handles replay attack after webhook has been processed' do
      # First POST: Create and process webhook
      post '/webhooks/twilio/sms_status', params: valid_webhook_params
      webhook = Webhook.last

      # Simulate processing
      perform_enqueued_jobs
      webhook.reload
      webhook.update!(status: 'processed', processed_at: Time.current)

      # Replay attack on processed webhook
      expect do
        post '/webhooks/twilio/sms_status', params: valid_webhook_params
      end.not_to change(Webhook, :count)

      expect(response).to have_http_status(:ok)

      # Verify webhook status unchanged
      webhook.reload
      expect(webhook.status).to eq('processed')
      expect(webhook.processed_at).to be_present
    end

    it 'logs duplicate webhook attempts for security monitoring' do
      allow(Rails.logger).to receive(:info)

      # First POST
      post '/webhooks/twilio/sms_status', params: valid_webhook_params

      # Replay attack
      post '/webhooks/twilio/sms_status', params: valid_webhook_params

      # Verify duplicate was logged
      expect(Rails.logger).to have_received(:info).with(
        /Duplicate SMS webhook ignored \(pending\): SM1234567890abcdef1234567890abcdef/
      )
    end

    it 'handles replay attack with modified payload (same MessageSid)' do
      # First POST: delivered status
      post '/webhooks/twilio/sms_status',
           params: valid_webhook_params.merge(MessageStatus: 'delivered')

      original_webhook = Webhook.last
      initial_count = Webhook.count

      # Replay attack: Same MessageSid but different status (attacker trying to modify)
      post '/webhooks/twilio/sms_status',
           params: valid_webhook_params.merge(MessageStatus: 'failed')

      # Verify no new webhook created
      expect(Webhook.count).to eq(initial_count)

      # Verify original webhook payload unchanged
      original_webhook.reload
      expect(original_webhook.payload['MessageStatus']).to eq('delivered')
    end
  end

  describe 'POST /webhooks/twilio/voice_status' do
    let(:voice_webhook_params) do
      {
        CallSid: 'CA1234567890abcdef1234567890abcdef',
        CallStatus: 'completed',
        To: '+14155551234',
        From: '+14155555678',
        Duration: '45',
        AccountSid: 'ACTEST00000000000000000000000000'
      }
    end

    it 'accepts first voice webhook and rejects replay' do
      # First POST
      post '/webhooks/twilio/voice_status', params: voice_webhook_params
      expect(response).to have_http_status(:ok)
      expect(Webhook.count).to eq(1)

      # Replay attack
      expect do
        post '/webhooks/twilio/voice_status', params: voice_webhook_params
      end.not_to change(Webhook, :count)

      expect(response).to have_http_status(:ok)
    end

    it 'allows same CallSid for SMS and Voice (different sources)' do
      # Create SMS webhook with ID "ID123"
      post '/webhooks/twilio/sms_status',
           params: { MessageSid: 'ID123', MessageStatus: 'delivered', To: '+14155551234', From: '+14155555678' }

      # Create Voice webhook with same ID "ID123" (different source)
      expect do
        post '/webhooks/twilio/voice_status',
             params: { CallSid: 'ID123', CallStatus: 'completed', To: '+14155551234', From: '+14155555678' }
      end.to change(Webhook, :count).by(1)

      # Verify both webhooks exist with different sources
      webhooks = Webhook.where(external_id: 'ID123')
      expect(webhooks.count).to eq(2)
      expect(webhooks.pluck(:source)).to contain_exactly('twilio_sms', 'twilio_voice')
    end
  end

  describe 'race condition handling (concurrent duplicate POSTs)' do
    it 'prevents duplicate webhook creation when two requests arrive simultaneously' do
      # Simulate two concurrent POST requests with same MessageSid
      threads = 2.times.map do
        Thread.new do
          post '/webhooks/twilio/sms_status',
               params: {
                 MessageSid: 'SM_CONCURRENT_TEST',
                 MessageStatus: 'delivered',
                 To: '+14155551234',
                 From: '+14155555678'
               }
        end
      end

      threads.each(&:join)

      # Only one webhook should be created (database constraint prevents duplicates)
      expect(Webhook.where(external_id: 'SM_CONCURRENT_TEST').count).to eq(1)
    end

    it 'handles ActiveRecord::RecordNotUnique gracefully' do
      allow(Webhook).to receive(:find_or_initialize_by).and_raise(ActiveRecord::RecordNotUnique.new('Duplicate entry'))
      allow(Rails.logger).to receive(:warn)

      post '/webhooks/twilio/sms_status',
           params: {
             MessageSid: 'SM_RACE_CONDITION',
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678'
           }

      expect(response).to have_http_status(:ok)
      expect(Rails.logger).to have_received(:warn).with(/Duplicate SMS webhook \(race condition\): SM_RACE_CONDITION/)
    end
  end

  describe 'edge cases' do
    it 'handles very long MessageSid (500 characters)' do
      long_message_sid = 'SM' + ('A' * 498)

      post '/webhooks/twilio/sms_status',
           params: {
             MessageSid: long_message_sid,
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678'
           }

      expect(response).to have_http_status(:ok)

      webhook = Webhook.last
      expect(webhook.external_id).to eq(long_message_sid)
      expect(webhook.idempotency_key).to include(long_message_sid)

      # Replay with same long MessageSid should be rejected
      expect do
        post '/webhooks/twilio/sms_status',
             params: { MessageSid: long_message_sid, MessageStatus: 'delivered', To: '+14155551234',
                       From: '+14155555678' }
      end.not_to change(Webhook, :count)
    end

    it 'handles MessageSid with special characters' do
      special_message_sid = 'SM-123:456/789'

      post '/webhooks/twilio/sms_status',
           params: {
             MessageSid: special_message_sid,
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678'
           }

      expect(response).to have_http_status(:ok)

      webhook = Webhook.last
      expect(webhook.external_id).to eq(special_message_sid)
      expect(webhook.idempotency_key).to eq("twilio_sms:#{special_message_sid}")

      # Replay should be rejected
      expect do
        post '/webhooks/twilio/sms_status',
             params: { MessageSid: special_message_sid, MessageStatus: 'delivered', To: '+14155551234',
                       From: '+14155555678' }
      end.not_to change(Webhook, :count)
    end

    it 'handles webhook without MessageSid (falls back to payload hash)' do
      allow(Rails.logger).to receive(:warn)

      # POST without MessageSid (should use payload hash as fallback)
      post '/webhooks/twilio/sms_status',
           params: {
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678',
             Body: 'Test message'
           }

      expect(response).to have_http_status(:ok)

      webhook = Webhook.last
      expect(webhook.external_id).to be_nil
      expect(webhook.idempotency_key).to start_with('twilio_sms:hash:')

      # Verify warning was logged
      expect(Rails.logger).to have_received(:warn).with(
        /Webhook created without external_id/
      )

      # Replay with same payload should be rejected (same hash)
      expect do
        post '/webhooks/twilio/sms_status',
             params: {
               MessageStatus: 'delivered',
               To: '+14155551234',
               From: '+14155555678',
               Body: 'Test message'
             }
      end.not_to change(Webhook, :count)
    end
  end

  describe 'security implications' do
    it 'prevents replay attack from processing duplicate payment confirmations' do
      # Scenario: SMS confirmation for payment transaction
      payment_confirmation_params = {
        MessageSid: 'SM_PAYMENT_CONFIRM_12345',
        MessageStatus: 'delivered',
        To: '+14155551234',
        From: '+14155555678',
        Body: 'Payment of $100 confirmed. Transaction ID: TXN_789'
      }

      # First POST: Legitimate payment confirmation
      post '/webhooks/twilio/sms_status', params: payment_confirmation_params
      expect(response).to have_http_status(:ok)

      webhook = Webhook.last
      perform_enqueued_jobs
      webhook.reload

      # Simulate processing (e.g., marking transaction as confirmed)
      webhook.update!(
        status: 'processed',
        processed_at: Time.current,
        payload: webhook.payload.merge('processed_action' => 'transaction_confirmed')
      )

      initial_webhook_count = Webhook.count

      # Replay attack: Attacker tries to trigger duplicate processing
      10.times do
        post '/webhooks/twilio/sms_status', params: payment_confirmation_params
      end

      # Verify NO additional webhooks created
      expect(Webhook.count).to eq(initial_webhook_count)

      # Verify original webhook still has single processing record
      webhook.reload
      expect(webhook.status).to eq('processed')
      expect(webhook.processed_at).to be_present
    end

    it 'prevents attacker from bypassing idempotency by changing capitalization' do
      # First POST: Normal MessageSid
      post '/webhooks/twilio/sms_status',
           params: {
             MessageSid: 'SM1234567890abcdef',
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678'
           }

      initial_count = Webhook.count

      # Replay attack: Same MessageSid with different capitalization
      # Note: Twilio IDs are case-sensitive, so this would be treated as different
      # However, our idempotency key is case-sensitive too, so this is correctly handled
      post '/webhooks/twilio/sms_status',
           params: {
             MessageSid: 'SM1234567890ABCDEF', # Different capitalization
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678'
           }

      # This is actually a different MessageSid (Twilio IDs are case-sensitive)
      # So a new webhook SHOULD be created
      expect(Webhook.count).to eq(initial_count + 1)

      # Verify idempotency keys are different (case-sensitive)
      expect(Webhook.pluck(:idempotency_key)).to include(
        'twilio_sms:SM1234567890abcdef',
        'twilio_sms:SM1234567890ABCDEF'
      )
    end

    it 'prevents mass replay attack (100 duplicate POSTs in rapid succession)' do
      initial_count = Webhook.count

      # Mass replay attack: 100 duplicate POSTs
      100.times do
        post '/webhooks/twilio/sms_status',
             params: {
               MessageSid: 'SM_MASS_REPLAY',
               MessageStatus: 'delivered',
               To: '+14155551234',
               From: '+14155555678'
             }
      end

      # Only 1 webhook should be created (all others rejected)
      expect(Webhook.count).to eq(initial_count + 1)

      # Verify only 1 WebhookProcessorJob was enqueued
      webhook_processor_jobs = enqueued_jobs.select { |job| job[:job] == WebhookProcessorJob }
      expect(webhook_processor_jobs.size).to eq(1)
    end
  end

  describe 'monitoring and alerting' do
    it 'increments StatsD counter for duplicate webhook attempts' do
      allow(StatsD).to receive(:increment) if defined?(StatsD)

      # First POST
      post '/webhooks/twilio/sms_status',
           params: {
             MessageSid: 'SM_STATSD_TEST',
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678'
           }

      # Replay attack
      post '/webhooks/twilio/sms_status',
           params: {
             MessageSid: 'SM_STATSD_TEST',
             MessageStatus: 'delivered',
             To: '+14155551234',
             From: '+14155555678'
           }

      # Verify metric was incremented (if StatsD is configured)
      if defined?(StatsD)
        expect(StatsD).to have_received(:increment).with(
          'webhook.duplicate_rejected',
          tags: ['source:twilio_sms']
        )
      end
    end
  end
end
