# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contact, type: :model do
  describe 'bulk operations with callback skipping' do
    describe '.with_callbacks_skipped' do
      it 'skips fingerprint calculation callbacks during bulk import' do
        Contact.with_callbacks_skipped do
          contact = Contact.create!(
            raw_phone_number: '+14155551234',
            status: 'pending'
          )

          # Fingerprints should NOT be calculated when callbacks are skipped
          expect(contact.phone_fingerprint).to be_nil
          expect(contact.name_fingerprint).to be_nil
          expect(contact.email_fingerprint).to be_nil
        end
      end

      it 'skips quality score calculation during bulk import' do
        Contact.with_callbacks_skipped do
          contact = Contact.create!(
            raw_phone_number: '+14155551234',
            full_name: 'John Doe',
            email: 'john@example.com',
            phone_valid: true,
            status: 'pending'
          )

          # Quality score should NOT be calculated when callbacks are skipped
          expect(contact.data_quality_score).to be_nil
          expect(contact.completeness_percentage).to be_nil
        end
      end

      it 'skips broadcast_refresh callback during bulk import' do
        # Expect broadcast_refresh NOT to be called
        expect_any_instance_of(Contact).not_to receive(:broadcast_refresh)

        Contact.with_callbacks_skipped do
          Contact.create!(
            raw_phone_number: '+14155551234',
            status: 'pending'
          )
        end
      end

      it 'restores callback behavior after block completes' do
        # Create contact inside with_callbacks_skipped
        Contact.with_callbacks_skipped do
          Contact.create!(raw_phone_number: '+14155551111')
        end

        # Create contact outside with_callbacks_skipped - callbacks should run
        contact = Contact.create!(
          raw_phone_number: '+14155552222',
          status: 'pending'
        )

        # Fingerprints SHOULD be calculated when callbacks are not skipped
        expect(contact.phone_fingerprint).not_to be_nil
      end

      it 'handles nested with_callbacks_skipped blocks' do
        Contact.with_callbacks_skipped do
          Contact.with_callbacks_skipped do
            contact = Contact.create!(raw_phone_number: '+14155551234')
            expect(contact.phone_fingerprint).to be_nil
          end

          # Still skipped in outer block
          contact = Contact.create!(raw_phone_number: '+14155555678')
          expect(contact.phone_fingerprint).to be_nil
        end

        # Callbacks restored after both blocks
        contact = Contact.create!(raw_phone_number: '+14155559999')
        expect(contact.phone_fingerprint).not_to be_nil
      end

      it 'is thread-safe (uses thread_mattr_accessor)' do
        # This test verifies that skip_callbacks_for_bulk_import is thread-local
        # In practice, each Sidekiq worker thread would have independent state

        thread1_fingerprint = nil
        thread2_fingerprint = nil

        t1 = Thread.new do
          Contact.with_callbacks_skipped do
            sleep 0.1  # Ensure threads overlap
            contact = Contact.create!(raw_phone_number: '+14155551111')
            thread1_fingerprint = contact.phone_fingerprint
          end
        end

        t2 = Thread.new do
          sleep 0.05
          # This thread does NOT skip callbacks
          contact = Contact.create!(raw_phone_number: '+14155552222')
          thread2_fingerprint = contact.phone_fingerprint
        end

        t1.join
        t2.join

        # Thread 1 (callbacks skipped) should have nil fingerprint
        expect(thread1_fingerprint).to be_nil

        # Thread 2 (callbacks enabled) should have fingerprint
        expect(thread2_fingerprint).not_to be_nil
      end
    end

    describe '.recalculate_bulk_metrics' do
      let!(:contacts) do
        Contact.with_callbacks_skipped do
          [
            Contact.create!(
              raw_phone_number: '+14155551111',
              full_name: 'John Doe',
              email: 'john@example.com',
              phone_valid: true,
              status: 'completed'
            ),
            Contact.create!(
              raw_phone_number: '+14155552222',
              full_name: 'Jane Smith',
              business_name: 'Acme Corp',
              phone_valid: true,
              business_enriched: true,
              status: 'completed'
            )
          ]
        end
      end

      it 'recalculates fingerprints for all provided contact IDs' do
        # Verify fingerprints are initially nil (callbacks were skipped)
        contacts.each do |contact|
          expect(contact.phone_fingerprint).to be_nil
        end

        # Recalculate metrics
        Contact.recalculate_bulk_metrics(contacts.map(&:id))

        # Reload and verify fingerprints were calculated
        contacts.each do |contact|
          contact.reload
          expect(contact.phone_fingerprint).not_to be_nil
        end
      end

      it 'recalculates quality scores for all provided contact IDs' do
        # Verify quality scores are initially nil
        contacts.each do |contact|
          expect(contact.data_quality_score).to be_nil
        end

        # Recalculate metrics
        Contact.recalculate_bulk_metrics(contacts.map(&:id))

        # Reload and verify quality scores were calculated
        contacts.each do |contact|
          contact.reload
          expect(contact.data_quality_score).not_to be_nil
          expect(contact.data_quality_score).to be > 0
        end
      end

      it 'processes contacts in batches using find_each' do
        # Create 150 contacts to test batching (default batch size is 1000, but find_each will batch)
        contact_ids = Contact.with_callbacks_skipped do
          150.times.map do |i|
            Contact.create!(raw_phone_number: "+1415555#{i.to_s.rjust(4, '0')}").id
          end
        end

        # Recalculate should work for large batches
        expect {
          Contact.recalculate_bulk_metrics(contact_ids)
        }.not_to raise_error

        # Spot check some contacts
        [contact_ids.first, contact_ids.last].each do |id|
          contact = Contact.find(id)
          expect(contact.phone_fingerprint).not_to be_nil
        end
      end

      it 'handles empty array gracefully' do
        expect {
          Contact.recalculate_bulk_metrics([])
        }.not_to raise_error
      end
    end

    describe 'performance improvement' do
      it 'bulk import with callbacks skipped is significantly faster' do
        # Measure bulk import WITH callbacks (slow)
        with_callbacks_time = Benchmark.realtime do
          10.times do |i|
            Contact.create!(raw_phone_number: "+1415666#{i.to_s.rjust(4, '0')}")
          end
        end

        # Clean up
        Contact.where('raw_phone_number LIKE ?', '+1415666%').delete_all

        # Measure bulk import WITHOUT callbacks (fast)
        without_callbacks_time = Benchmark.realtime do
          Contact.with_callbacks_skipped do
            10.times do |i|
              Contact.create!(raw_phone_number: "+1415777#{i.to_s.rjust(4, '0')}")
            end
          end
        end

        # Skipping callbacks should be at least 2x faster (conservative estimate)
        # In practice, it's 10-100x faster depending on callback complexity
        expect(without_callbacks_time).to be < (with_callbacks_time / 2)
      end
    end

    describe 'data integrity' do
      it 'eventual consistency: metrics are correct after recalculation' do
        # Bulk import with callbacks skipped
        contact_ids = Contact.with_callbacks_skipped do
          [
            Contact.create!(
              raw_phone_number: '+14155551111',
              full_name: 'John Doe',
              email: 'john@example.com',
              phone_valid: true,
              email_verified: true,
              business_enriched: true
            ),
            Contact.create!(
              raw_phone_number: '+14155552222',
              full_name: 'Jane Smith',
              phone_valid: false
            )
          ].map(&:id)
        end

        # Recalculate metrics
        Contact.recalculate_bulk_metrics(contact_ids)

        # Verify Contact 1 has high quality score (many fields populated)
        contact1 = Contact.find(contact_ids[0])
        expect(contact1.data_quality_score).to be > 50
        expect(contact1.phone_fingerprint).to eq('4155551111')

        # Verify Contact 2 has lower quality score (fewer fields)
        contact2 = Contact.find(contact_ids[1])
        expect(contact2.data_quality_score).to be < 50
        expect(contact2.phone_fingerprint).to eq('4155552222')
      end

      it 'fingerprints are calculated correctly for duplicate detection' do
        contact_id = Contact.with_callbacks_skipped do
          Contact.create!(
            raw_phone_number: '+14155551234',
            full_name: 'John Doe',
            email: 'john@example.com'
          ).id
        end

        Contact.recalculate_bulk_metrics([contact_id])

        contact = Contact.find(contact_id)
        # Phone fingerprint should be last 10 digits
        expect(contact.phone_fingerprint).to eq('4155551234')

        # Name fingerprint should be normalized (downcased, sorted)
        expect(contact.name_fingerprint).to eq('doe john')

        # Email fingerprint should be normalized
        expect(contact.email_fingerprint).to eq('john@example.com')
      end
    end
  end

  describe 'callback behavior without bulk operations' do
    it 'normal saves still trigger callbacks (backwards compatible)' do
      contact = Contact.create!(
        raw_phone_number: '+14155551234',
        full_name: 'John Doe'
      )

      # Callbacks should have run normally
      expect(contact.phone_fingerprint).not_to be_nil
      expect(contact.data_quality_score).not_to be_nil
    end

    it 'updates trigger fingerprint recalculation if fields changed' do
      contact = Contact.create!(raw_phone_number: '+14155551234')
      original_fingerprint = contact.phone_fingerprint

      # Update phone number
      contact.update!(raw_phone_number: '+14155555678')

      # Fingerprint should be recalculated
      expect(contact.phone_fingerprint).not_to eq(original_fingerprint)
      expect(contact.phone_fingerprint).to eq('4155555678')
    end

    it 'updates do NOT recalculate fingerprints if relevant fields unchanged' do
      contact = Contact.create!(
        raw_phone_number: '+14155551234',
        full_name: 'John Doe'
      )
      original_fingerprint = contact.phone_fingerprint

      # Spy on update_fingerprints! to verify it's not called
      allow(contact).to receive(:update_fingerprints!)

      # Update unrelated field
      contact.update!(status: 'completed')

      # update_fingerprints! should NOT have been called
      expect(contact).not_to have_received(:update_fingerprints!)
      expect(contact.phone_fingerprint).to eq(original_fingerprint)
    end
  end
end
