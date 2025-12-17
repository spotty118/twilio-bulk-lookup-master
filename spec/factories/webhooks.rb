# frozen_string_literal: true

FactoryBot.define do
  factory :webhook do
    source { 'twilio_sms' }
    event_type { 'message_status' }
    received_at { Time.current }
    status { 'pending' }
    payload { { 'MessageSid' => "SM#{SecureRandom.hex(16)}", 'MessageStatus' => 'delivered' } }

    # Generate external_id for idempotency
    sequence(:external_id) { |n| "SM#{SecureRandom.hex(16)}" }

    # Source traits
    trait :sms do
      source { 'twilio_sms' }
      event_type { 'message_status' }
      payload do
        {
          'MessageSid' => external_id,
          'MessageStatus' => 'delivered',
          'To' => '+14155551234',
          'From' => '+14155559999'
        }
      end
    end

    trait :voice do
      source { 'twilio_voice' }
      event_type { 'call_status' }
      payload do
        {
          'CallSid' => external_id,
          'CallStatus' => 'completed',
          'To' => '+14155551234',
          'From' => '+14155559999',
          'AnsweredBy' => 'human'
        }
      end
    end

    trait :trust_hub do
      source { 'twilio_trust_hub' }
      event_type { 'verification_status' }
      payload do
        {
          'CustomerProfileSid' => "BU#{SecureRandom.hex(16)}",
          'Status' => 'twilio-approved'
        }
      end
    end

    # Status traits
    trait :pending do
      status { 'pending' }
      processed_at { nil }
    end

    trait :processing do
      status { 'processing' }
      processed_at { nil }
    end

    trait :processed do
      status { 'processed' }
      processed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      processing_error { 'Processing failed: Unknown error' }
      retry_count { 1 }
    end

    # With contact association
    trait :with_contact do
      association :contact, factory: :contact
    end

    # Duplicate webhook (for idempotency testing)
    trait :duplicate do
      # Uses same external_id to test duplicate handling
    end
  end
end
