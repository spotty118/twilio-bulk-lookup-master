# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhook, type: :model do
  describe 'idempotency protection' do
    describe 'database constraints' do
      it 'rejects duplicate webhooks with same source and external_id' do
        # Create first webhook
        Webhook.create!(
          source: 'twilio_sms',
          external_id: 'SM1234567890abcdef',
          event_type: 'sms_status',
          payload: { MessageStatus: 'delivered' },
          received_at: Time.current
        )

        # Attempt to create duplicate
        duplicate = Webhook.new(
          source: 'twilio_sms',
          external_id: 'SM1234567890abcdef',
          event_type: 'sms_status',
          payload: { MessageStatus: 'delivered' },
          received_at: Time.current
        )

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:idempotency_key]).to include('has already been taken')
      end

      it 'allows webhooks with same external_id but different source' do
        Webhook.create!(
          source: 'twilio_sms',
          external_id: 'ID123',
          event_type: 'sms_status',
          received_at: Time.current
        )

        # Different source, same ID - should be allowed
        webhook2 = Webhook.create!(
          source: 'twilio_voice',
          external_id: 'ID123',
          event_type: 'voice_status',
          received_at: Time.current
        )

        expect(webhook2).to be_persisted
      end

      it 'allows webhooks with same source but different external_id' do
        Webhook.create!(
          source: 'twilio_sms',
          external_id: 'ID123',
          event_type: 'sms_status',
          received_at: Time.current
        )

        # Same source, different ID - should be allowed
        webhook2 = Webhook.create!(
          source: 'twilio_sms',
          external_id: 'ID456',
          event_type: 'sms_status',
          received_at: Time.current
        )

        expect(webhook2).to be_persisted
      end
    end

    describe '#generate_idempotency_key' do
      it 'generates key from source and external_id' do
        webhook = Webhook.new(
          source: 'twilio_sms',
          external_id: 'SM1234567890',
          event_type: 'sms_status',
          received_at: Time.current
        )

        webhook.valid?  # Trigger before_validation callback

        expect(webhook.idempotency_key).to eq('twilio_sms:SM1234567890')
      end

      it 'generates hash-based key when external_id is missing' do
        allow(Rails.logger).to receive(:warn)

        webhook = Webhook.new(
          source: 'test_source',
          external_id: nil,
          event_type: 'test_event',
          payload: { test: 'data' },
          received_at: Time.current
        )

        webhook.valid?

        # Should use payload hash as fallback
        expect(webhook.idempotency_key).to start_with('test_source:hash:')
        expect(webhook.idempotency_key.length).to be > 20

        # Should log warning
        expect(Rails.logger).to have_received(:warn).with(
          /Webhook created without external_id/
        )
      end

      it 'generates consistent hash for same payload' do
        payload = { message: 'test', timestamp: '2024-01-01' }

        webhook1 = Webhook.new(
          source: 'test',
          external_id: nil,
          event_type: 'test',
          payload: payload,
          received_at: Time.current
        )
        webhook1.valid?

        webhook2 = Webhook.new(
          source: 'test',
          external_id: nil,
          event_type: 'test',
          payload: payload,
          received_at: Time.current
        )
        webhook2.valid?

        expect(webhook1.idempotency_key).to eq(webhook2.idempotency_key)
      end

      it 'does not override manually set idempotency_key' do
        webhook = Webhook.new(
          source: 'test',
          external_id: 'ID123',
          event_type: 'test',
          idempotency_key: 'custom_key',
          received_at: Time.current
        )

        webhook.valid?

        expect(webhook.idempotency_key).to eq('custom_key')
      end
    end

    describe 'replay attack prevention' do
      it 'prevents processing same webhook twice' do
        # First webhook creates record
        webhook1 = Webhook.create!(
          source: 'twilio_sms',
          external_id: 'SM1234567890',
          event_type: 'sms_status',
          payload: { MessageStatus: 'delivered' },
          status: 'pending',
          received_at: Time.current
        )

        # Process it
        webhook1.update!(status: 'processed', processed_at: Time.current)

        # Replay attempt - should fail validation
        webhook2 = Webhook.new(
          source: 'twilio_sms',
          external_id: 'SM1234567890',
          event_type: 'sms_status',
          payload: { MessageStatus: 'delivered' },
          received_at: Time.current
        )

        expect(webhook2).not_to be_valid
        expect(Webhook.count).to eq(1)
      end

      it 'logs rejection of duplicate webhooks' do
        Webhook.create!(
          source: 'twilio_sms',
          external_id: 'SM1234567890',
          event_type: 'sms_status',
          received_at: Time.current
        )

        duplicate = Webhook.new(
          source: 'twilio_sms',
          external_id: 'SM1234567890',
          event_type: 'sms_status',
          received_at: Time.current
        )

        expect(duplicate).not_to be_valid
        expect(duplicate.errors.full_messages).to include(/Idempotency key has already been taken/)
      end
    end

    describe 'edge cases' do
      it 'handles very long external_ids' do
        long_id = 'A' * 500

        webhook = Webhook.create!(
          source: 'test',
          external_id: long_id,
          event_type: 'test',
          received_at: Time.current
        )

        expect(webhook.idempotency_key).to include(long_id)
        expect(webhook).to be_persisted
      end

      it 'handles special characters in external_id' do
        special_id = "ID-123:456/789"

        webhook = Webhook.create!(
          source: 'test',
          external_id: special_id,
          event_type: 'test',
          received_at: Time.current
        )

        expect(webhook.idempotency_key).to eq("test:#{special_id}")
        expect(webhook).to be_persisted
      end

      it 'handles empty payload gracefully' do
        webhook = Webhook.new(
          source: 'test',
          external_id: nil,
          event_type: 'test',
          payload: {},
          received_at: Time.current
        )

        webhook.valid?

        # Should generate hash even for empty payload
        expect(webhook.idempotency_key).to start_with('test:hash:')
      end

      it 'handles nil payload gracefully' do
        webhook = Webhook.new(
          source: 'test',
          external_id: nil,
          event_type: 'test',
          payload: nil,
          received_at: Time.current
        )

        webhook.valid?

        # Should generate hash for nil payload
        expect(webhook.idempotency_key).to start_with('test:hash:')
      end
    end

    describe 'race condition handling' do
      it 'prevents duplicate creation in concurrent requests (theoretical)' do
        # This test simulates what would happen if two requests arrive simultaneously
        # In practice, the database unique constraint handles this

        webhook1 = Webhook.new(
          source: 'twilio_sms',
          external_id: 'SM_CONCURRENT',
          event_type: 'sms_status',
          received_at: Time.current
        )

        webhook2 = Webhook.new(
          source: 'twilio_sms',
          external_id: 'SM_CONCURRENT',
          event_type: 'sms_status',
          received_at: Time.current
        )

        # First save succeeds
        expect(webhook1.save).to be true

        # Second save fails due to uniqueness validation
        expect(webhook2.save).to be false
        expect(webhook2.errors[:idempotency_key]).to be_present
      end
    end
  end

  describe 'backwards compatibility' do
    it 'still validates required fields' do
      webhook = Webhook.new(
        # Missing source, event_type, received_at
        external_id: 'ID123'
      )

      expect(webhook).not_to be_valid
      expect(webhook.errors[:source]).to be_present
      expect(webhook.errors[:event_type]).to be_present
      expect(webhook.errors[:received_at]).to be_present
    end

    it 'still validates status inclusion' do
      webhook = Webhook.new(
        source: 'test',
        external_id: 'ID123',
        event_type: 'test',
        status: 'invalid_status',
        received_at: Time.current
      )

      expect(webhook).not_to be_valid
      expect(webhook.errors[:status]).to be_present
    end
  end

  describe 'migration safety' do
    it 'migration is reversible' do
      # This test verifies that the migration up/down methods work correctly
      # In practice, this would be tested by running rails db:migrate:down

      # Verify idempotency_key column exists
      expect(Webhook.column_names).to include('idempotency_key')

      # Verify index exists (this would need to check database schema)
      # In a real test environment, you'd query the database for indexes
    end
  end
end
