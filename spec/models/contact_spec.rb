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
    let!(:pending_contact) { create(:contact, status: 'pending') }
    let!(:completed_contact) { create(:contact, status: 'completed') }
    let!(:failed_contact) { create(:contact, status: 'failed') }

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
      contact = create(:contact, status: 'completed', formatted_phone_number: '+14155551234')
      expect(contact.lookup_completed?).to be true
    end

    it 'returns false when status is not completed' do
      contact = create(:contact, status: 'pending', formatted_phone_number: '+14155551234')
      expect(contact.lookup_completed?).to be false
    end

    it 'returns false when formatted_phone_number is missing' do
      contact = create(:contact, status: 'completed', formatted_phone_number: nil)
      expect(contact.lookup_completed?).to be false
    end
  end

  describe '#mark_processing!' do
    it 'updates status to processing' do
      contact = create(:contact, status: 'pending')
      contact.mark_processing!
      expect(contact.reload.status).to eq('processing')
    end
  end

  describe '#mark_completed!' do
    it 'updates status to completed with timestamp' do
      contact = create(:contact, status: 'processing')
      freeze_time do
        contact.mark_completed!
        expect(contact.reload.status).to eq('completed')
        expect(contact.lookup_performed_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe 'status transitions' do
    context 'from pending' do
      let(:contact) { create(:contact, status: 'pending') }

      it 'allows transition to processing' do
        contact.status = 'processing'
        expect(contact.save).to be true
      end

      it 'allows transition to failed' do
        contact.status = 'failed'
        expect(contact.save).to be true
      end

      it 'prevents transition to completed directly' do
        contact.status = 'completed'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to be_present
      end
    end

    context 'from completed' do
      let(:contact) { create(:contact, status: 'completed') }

      it 'prevents any status change (terminal state)' do
        contact.status = 'pending'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to include(/Invalid status transition/)
      end
    end
  end

  describe 'callback recursion prevention' do
    it 'does not trigger infinite callbacks on fingerprint update' do
      contact = create(:contact, formatted_phone_number: '+14155551234')

      expect {
        contact.update(formatted_phone_number: '+14155559999')
      }.not_to raise_error

      expect(contact.reload.phone_fingerprint).to eq('4155559999')
    end

    it 'updates fingerprints without extra database saves' do
      contact = create(:contact)

      expect(contact).to receive(:update_columns).once.and_call_original

      contact.send(:update_fingerprints!)
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
