# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contact, type: :model do
  # Darwin-Gödel Test Suite - Generation 1
  # Addresses critical gap: 0% test coverage

  describe 'validations' do
    it { should validate_presence_of(:raw_phone_number) }
    it { should validate_inclusion_of(:status).in_array(%w[pending processing completed failed]) }

    describe 'phone number format validation' do
      it 'accepts valid E.164 format' do
        contact = build(:contact, raw_phone_number: '+14155551234')
        expect(contact).to be_valid
      end

      it 'accepts numbers without + prefix' do
        contact = build(:contact, raw_phone_number: '14155551234')
        expect(contact).to be_valid
      end

      it 'rejects invalid formats' do
        contact = build(:contact, raw_phone_number: 'abc123')
        expect(contact).not_to be_valid
        expect(contact.errors[:raw_phone_number]).to include(/must be a valid phone number/)
      end

      it 'rejects numbers starting with 0' do
        contact = build(:contact, raw_phone_number: '01234567890')
        expect(contact).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:pending_contact) { create(:contact, :pending) }
    let!(:completed_contact) { create(:contact, :completed) }
    let!(:failed_contact) { create(:contact, :failed) }

    it '.pending returns only pending contacts' do
      expect(Contact.pending).to contain_exactly(pending_contact)
    end

    it '.completed returns only completed contacts' do
      expect(Contact.completed).to contain_exactly(completed_contact)
    end

    it '.failed returns only failed contacts' do
      expect(Contact.failed).to contain_exactly(failed_contact)
    end

    it '.not_processed returns pending and failed' do
      expect(Contact.not_processed).to contain_exactly(pending_contact, failed_contact)
    end
  end

  describe '#lookup_completed?' do
    it 'returns true when status is completed and phone is formatted' do
      contact = create(:contact, :completed)
      expect(contact.lookup_completed?).to be true
    end

    it 'returns false when status is not completed' do
      contact = create(:contact, :pending)
      expect(contact.lookup_completed?).to be false
    end

    it 'returns false when formatted_phone_number is missing' do
      contact = build(:contact, :completed, formatted_phone_number: nil)
      expect(contact.lookup_completed?).to be false
    end
  end

  describe '#mark_processing!' do
    it 'updates status to processing' do
      contact = create(:contact, :pending)
      contact.mark_processing!
      expect(contact.reload.status).to eq('processing')
    end
  end

  describe '#mark_completed!' do
    it 'updates status to completed with timestamp and calculates cost' do
      contact = create(:contact, :processing)
      freeze_time do
        expect(contact).to receive(:calculate_api_cost)
        contact.mark_completed!
        expect(contact.reload.status).to eq('completed')
        expect(contact.lookup_performed_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe 'status transitions' do
    context 'from pending' do
      let(:contact) { create(:contact, :pending) }

      it 'allows transition to processing' do
        contact.status = 'processing'
        expect(contact.save).to be true
      end

      it 'allows transition to failed' do
        contact.status = 'failed'
        contact.error_code = 'E123' # Required for failed status
        expect(contact.save).to be true
      end

      it 'prevents transition to completed directly' do
        contact.status = 'completed'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to be_present
      end
    end

    context 'from completed' do
      let(:contact) { create(:contact, :completed) }

      it 'prevents any status change (terminal state)' do
        contact.status = 'pending'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to include(/Invalid status transition/)
      end
    end
  end

  describe 'callback recursion prevention' do
    # Requirements 9.1, 9.2: Fingerprint updates must use update_columns to skip callbacks
    # and prevent infinite callback loops

    describe 'update_columns usage for fingerprints (Requirement 9.1)' do
      it 'uses update_columns when updating phone fingerprint' do
        contact = create(:contact, formatted_phone_number: '+14155551234')

        # Verify update_columns is called (not update or save)
        expect(contact).to receive(:update_columns).with(
          hash_including(:phone_fingerprint, :updated_at)
        ).and_call_original

        contact.update_fingerprints!
      end

      it 'uses update_columns when updating name fingerprint' do
        contact = create(:contact, business_name: 'Test Corp', is_business: true)

        expect(contact).to receive(:update_columns).with(
          hash_including(:name_fingerprint, :updated_at)
        ).and_call_original

        contact.update_fingerprints!
      end

      it 'uses update_columns when updating email fingerprint' do
        contact = create(:contact, email: 'test@example.com')

        expect(contact).to receive(:update_columns).with(
          hash_including(:email_fingerprint, :updated_at)
        ).and_call_original

        contact.update_fingerprints!
      end

      it 'uses update_columns for quality score calculation' do
        contact = create(:contact, phone_valid: true)

        expect(contact).to receive(:update_columns).with(
          hash_including(:data_quality_score, :completeness_percentage, :updated_at)
        ).and_call_original

        contact.calculate_quality_score!
      end
    end

    describe 'no additional callbacks triggered (Requirement 9.2)' do
      it 'does not trigger infinite callbacks on phone number update' do
        contact = create(:contact, formatted_phone_number: '+14155551234')

        # Track callback invocations
        callback_count = 0
        allow(contact).to receive(:update_fingerprints!).and_wrap_original do |method|
          callback_count += 1
          method.call
        end

        contact.update(formatted_phone_number: '+14155559999')

        # Should only be called once, not recursively
        expect(callback_count).to eq(1)
        expect(contact.reload.phone_fingerprint).to eq('4155559999')
      end

      it 'does not trigger infinite callbacks on name update' do
        contact = create(:contact, business_name: 'Original Corp', is_business: true)

        callback_count = 0
        allow(contact).to receive(:update_fingerprints!).and_wrap_original do |method|
          callback_count += 1
          method.call
        end

        contact.update(business_name: 'Updated Corp')

        expect(callback_count).to eq(1)
      end

      it 'does not trigger infinite callbacks on email update' do
        contact = create(:contact, email: 'old@example.com')

        callback_count = 0
        allow(contact).to receive(:update_fingerprints!).and_wrap_original do |method|
          callback_count += 1
          method.call
        end

        contact.update(email: 'new@example.com')

        expect(callback_count).to eq(1)
      end

      it 'does not trigger after_save callbacks when update_fingerprints! is called directly' do
        contact = create(:contact, formatted_phone_number: '+14155551234')

        # Spy on after_save callback methods
        after_save_triggered = false
        allow(contact).to receive(:update_fingerprints_if_needed) do
          after_save_triggered = true
        end

        # Direct call to update_fingerprints! should not trigger after_save
        contact.update_fingerprints!

        expect(after_save_triggered).to be false
      end

      it 'does not trigger after_save callbacks when calculate_quality_score! is called directly' do
        contact = create(:contact, phone_valid: true)

        after_save_triggered = false
        allow(contact).to receive(:calculate_quality_score_if_needed) do
          after_save_triggered = true
        end

        contact.calculate_quality_score!

        expect(after_save_triggered).to be false
      end
    end

    describe 'fingerprint update completes without errors' do
      it 'completes phone fingerprint update without raising errors' do
        contact = create(:contact, formatted_phone_number: '+14155551234')

        expect do
          contact.update(formatted_phone_number: '+14155559999')
        end.not_to raise_error

        expect(contact.reload.phone_fingerprint).to eq('4155559999')
      end

      it 'completes name fingerprint update without raising errors' do
        contact = create(:contact, business_name: 'Test Corp', is_business: true)

        expect do
          contact.update(business_name: 'New Corp')
        end.not_to raise_error

        expect(contact.reload.name_fingerprint).to eq('corp new')
      end

      it 'completes email fingerprint update without raising errors' do
        contact = create(:contact, email: 'old@example.com')

        expect do
          contact.update(email: 'new@example.com')
        end.not_to raise_error

        expect(contact.reload.email_fingerprint).to eq('new@example.com')
      end

      it 'handles multiple field updates in single save without recursion' do
        contact = create(:contact,
                         formatted_phone_number: '+14155551234',
                         business_name: 'Old Corp',
                         email: 'old@example.com',
                         is_business: true)

        expect do
          contact.update(
            formatted_phone_number: '+14155559999',
            business_name: 'New Corp',
            email: 'new@example.com'
          )
        end.not_to raise_error

        contact.reload
        expect(contact.phone_fingerprint).to eq('4155559999')
        expect(contact.name_fingerprint).to eq('corp new')
        expect(contact.email_fingerprint).to eq('new@example.com')
      end
    end

    describe 'database query verification' do
      it 'update_fingerprints! executes exactly one UPDATE query' do
        contact = create(:contact, formatted_phone_number: '+14155551234')

        update_count = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          update_count += 1 if payload[:sql] =~ /UPDATE.*contacts/i
        end

        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          contact.update_fingerprints!
        end

        expect(update_count).to eq(1)
      end

      it 'calculate_quality_score! executes exactly one UPDATE query' do
        contact = create(:contact, phone_valid: true)

        update_count = 0
        callback = lambda do |_name, _start, _finish, _id, payload|
          update_count += 1 if payload[:sql] =~ /UPDATE.*contacts/i
        end

        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          contact.calculate_quality_score!
        end

        expect(update_count).to eq(1)
      end
    end
  end

  describe '#calculate_quality_score!' do
    it 'scores valid phone number' do
      contact = create(:contact, phone_valid: true)
      contact.calculate_quality_score!
      expect(contact.reload.data_quality_score).to be >= 20
    end

    it 'scores verified email highly' do
      contact = create(:contact, email: 'test@example.com', email_verified: true)
      contact.calculate_quality_score!
      expect(contact.reload.data_quality_score).to be >= 20
    end

    it 'penalizes high fraud risk' do
      contact = create(:contact, sms_pumping_risk_level: 'high')
      contact.calculate_quality_score!
      expect(contact.reload.data_quality_score).to be < 50
    end
  end

  describe '#calculate_api_cost' do
    it 'sets cost to $0.005' do
      contact = create(:contact)
      contact.calculate_api_cost
      expect(contact.api_cost).to eq(0.005)
    end
  end

  describe 'fraud risk helpers' do
    it '#high_fraud_risk? detects high risk level' do
      contact = build(:contact, sms_pumping_risk_level: 'high')
      expect(contact.high_fraud_risk?).to be true
    end

    it '#safe_number? detects low risk' do
      contact = build(:contact, sms_pumping_risk_level: 'low', sms_pumping_number_blocked: false)
      expect(contact.safe_number?).to be true
    end
  end

  describe 'duplicate detection' do
    it 'calculates phone fingerprint from last 10 digits' do
      contact = build(:contact, formatted_phone_number: '+14155551234')
      expect(contact.send(:calculate_phone_fingerprint)).to eq('4155551234')
    end

    it 'normalizes name fingerprint' do
      contact = build(:contact, business_name: 'Acme Corp.', is_business: true)
      fingerprint = contact.send(:calculate_name_fingerprint)
      expect(fingerprint).to eq('acme corp')
    end

    it 'normalizes email fingerprint' do
      contact = build(:contact, email: '  Test@Example.COM  ')
      expect(contact.send(:calculate_email_fingerprint)).to eq('test@example.com')
    end
  end
end
