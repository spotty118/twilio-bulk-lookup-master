# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contact, 'status workflow', type: :model do
  # Tests for Contact model status workflow
  # Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6

  describe 'default status on creation' do
    # Requirement 1.1: WHEN a contact is created THEN the Contact model SHALL have status defaulting to 'pending'

    it 'defaults to pending status when no status is specified' do
      contact = Contact.create!(raw_phone_number: '+14155551234')
      expect(contact.status).to eq('pending')
    end

    it 'allows explicit pending status on creation' do
      contact = Contact.create!(raw_phone_number: '+14155551234', status: 'pending')
      expect(contact.status).to eq('pending')
    end

    it 'allows failed status on creation' do
      contact = Contact.create!(raw_phone_number: '+14155551234', status: 'failed')
      expect(contact.status).to eq('failed')
    end

    it 'allows completed status on creation when lookup_performed_at is present' do
      contact = Contact.create!(
        raw_phone_number: '+14155551234',
        status: 'completed',
        lookup_performed_at: Time.current
      )
      expect(contact.status).to eq('completed')
    end

    it 'allows processing status on creation when lookup_performed_at is blank' do
      contact = Contact.create!(
        raw_phone_number: '+14155551234',
        status: 'processing',
        lookup_performed_at: nil
      )
      expect(contact.status).to eq('processing')
    end
  end

  describe 'valid status transitions' do
    # Requirement 1.2: pending → processing
    describe 'pending → processing' do
      let(:contact) { create(:contact, :pending) }

      it 'allows transition from pending to processing' do
        contact.status = 'processing'
        expect(contact.save).to be true
        expect(contact.reload.status).to eq('processing')
      end

      it 'allows transition via mark_processing!' do
        contact.mark_processing!
        expect(contact.reload.status).to eq('processing')
      end
    end

    # Requirement 1.3: processing → completed
    describe 'processing → completed' do
      let(:contact) { create(:contact, :processing) }

      it 'allows transition from processing to completed' do
        contact.status = 'completed'
        contact.lookup_performed_at = Time.current
        expect(contact.save).to be true
        expect(contact.reload.status).to eq('completed')
      end

      it 'allows transition via mark_completed!' do
        contact.mark_completed!
        expect(contact.reload.status).to eq('completed')
        expect(contact.lookup_performed_at).to be_present
      end
    end

    # Requirement 1.4: processing → failed
    describe 'processing → failed' do
      let(:contact) { create(:contact, :processing) }

      it 'allows transition from processing to failed' do
        contact.status = 'failed'
        contact.error_code = 'API Error'
        expect(contact.save).to be true
        expect(contact.reload.status).to eq('failed')
      end

      it 'allows transition via mark_failed!' do
        contact.mark_failed!('Connection timeout')
        expect(contact.reload.status).to eq('failed')
        expect(contact.error_code).to eq('Connection timeout')
      end
    end

    # Requirement 1.6: failed → pending (retry scenario)
    describe 'failed → pending (retry)' do
      let(:contact) { create(:contact, :failed) }

      it 'allows transition from failed to pending for retry' do
        contact.status = 'pending'
        expect(contact.save).to be true
        expect(contact.reload.status).to eq('pending')
      end

      it 'allows transition from failed to processing for immediate retry' do
        contact.status = 'processing'
        expect(contact.save).to be true
        expect(contact.reload.status).to eq('processing')
      end
    end

    # Requirement 1.2: pending → failed (direct failure)
    describe 'pending → failed' do
      let(:contact) { create(:contact, :pending) }

      it 'allows transition from pending to failed' do
        contact.status = 'failed'
        contact.error_code = 'Validation error'
        expect(contact.save).to be true
        expect(contact.reload.status).to eq('failed')
      end
    end
  end

  describe 'invalid status transitions' do
    # Requirement 1.5: completed → pending rejection
    describe 'completed → pending rejection' do
      let(:contact) { create(:contact, :completed) }

      it 'rejects transition from completed to pending' do
        contact.status = 'pending'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to include(/Invalid status transition/)
      end

      it 'rejects transition from completed to processing' do
        contact.status = 'processing'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to include(/Invalid status transition/)
      end

      it 'rejects transition from completed to failed' do
        contact.status = 'failed'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to include(/Invalid status transition/)
      end

      it 'preserves original status after rejected transition' do
        original_status = contact.status
        contact.status = 'pending'
        contact.save
        # After failed save, the status should be restored
        expect(contact.status).to eq(original_status)
      end
    end

    # Additional invalid transitions
    describe 'pending → completed (skipping processing)' do
      let(:contact) { create(:contact, :pending) }

      it 'rejects direct transition from pending to completed' do
        contact.status = 'completed'
        expect(contact.save).to be false
        expect(contact.errors[:status]).to include(/Invalid status transition/)
      end
    end
  end

  describe 'status helper methods' do
    describe '#is_terminal_state?' do
      it 'returns true for completed status' do
        contact = build(:contact, :completed)
        expect(contact.is_terminal_state?).to be true
      end

      it 'returns false for pending status' do
        contact = build(:contact, :pending)
        expect(contact.is_terminal_state?).to be false
      end

      it 'returns false for processing status' do
        contact = build(:contact, :processing)
        expect(contact.is_terminal_state?).to be false
      end

      it 'returns false for failed status' do
        contact = build(:contact, :failed)
        expect(contact.is_terminal_state?).to be false
      end
    end

    describe '#is_retryable_state?' do
      it 'returns true for failed status' do
        contact = build(:contact, :failed)
        expect(contact.is_retryable_state?).to be true
      end

      it 'returns true for pending status' do
        contact = build(:contact, :pending)
        expect(contact.is_retryable_state?).to be true
      end

      it 'returns false for completed status' do
        contact = build(:contact, :completed)
        expect(contact.is_retryable_state?).to be false
      end

      it 'returns false for processing status' do
        contact = build(:contact, :processing)
        expect(contact.is_retryable_state?).to be false
      end
    end

    describe '#can_transition_to?' do
      context 'from pending' do
        let(:contact) { build(:contact, :pending) }

        it 'can transition to processing' do
          expect(contact.can_transition_to?('processing')).to be true
        end

        it 'can transition to failed' do
          expect(contact.can_transition_to?('failed')).to be true
        end

        it 'cannot transition to completed' do
          expect(contact.can_transition_to?('completed')).to be false
        end
      end

      context 'from processing' do
        let(:contact) { build(:contact, :processing) }

        it 'can transition to completed' do
          expect(contact.can_transition_to?('completed')).to be true
        end

        it 'can transition to failed' do
          expect(contact.can_transition_to?('failed')).to be true
        end

        it 'cannot transition to pending' do
          expect(contact.can_transition_to?('pending')).to be false
        end
      end

      context 'from completed' do
        let(:contact) { build(:contact, :completed) }

        it 'cannot transition to any status' do
          expect(contact.can_transition_to?('pending')).to be false
          expect(contact.can_transition_to?('processing')).to be false
          expect(contact.can_transition_to?('failed')).to be false
        end
      end

      context 'from failed' do
        let(:contact) { build(:contact, :failed) }

        it 'can transition to pending' do
          expect(contact.can_transition_to?('pending')).to be true
        end

        it 'can transition to processing' do
          expect(contact.can_transition_to?('processing')).to be true
        end

        it 'cannot transition to completed' do
          expect(contact.can_transition_to?('completed')).to be false
        end
      end
    end
  end
end
