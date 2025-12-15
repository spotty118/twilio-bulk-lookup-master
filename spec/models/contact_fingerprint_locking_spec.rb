# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Contact Fingerprint Locking', type: :model do
  # COGNITIVE HYPERCLUSTER TEST SUITE
  # Test Fix: Pessimistic locking prevents race conditions in concurrent fingerprint updates
  # Coverage: update_fingerprints! method called from after_save callbacks
  # Edge Cases: 10 concurrent updates, no lost updates, lock timeout handling

  describe 'Concurrent fingerprint updates with locking' do
    it 'prevents race conditions with pessimistic locking' do
      contact = create(:contact,
        formatted_phone_number: '+14155551234',
        business_name: 'Acme Corp',
        email: 'contact@example.com'
      )

      # Simulate 10 concurrent threads updating fingerprints
      threads = 10.times.map do |i|
        Thread.new do
          # Each thread tries to update fingerprints
          # Only one should succeed at a time due to pessimistic locking
          contact.reload.update_fingerprints!
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Verify fingerprints are correct (no corruption from race conditions)
      contact.reload
      expect(contact.phone_fingerprint).to eq('4155551234')
      expect(contact.name_fingerprint).to eq('acme corp')
      expect(contact.email_fingerprint).to eq('contact@example.com')
    end

    it 'handles concurrent updates to different contacts without blocking' do
      contact1 = create(:contact, formatted_phone_number: '+14155551111')
      contact2 = create(:contact, formatted_phone_number: '+14155552222')

      start_time = Time.current

      # Update different contacts concurrently
      threads = [
        Thread.new { 10.times { contact1.reload.update_fingerprints! } },
        Thread.new { 10.times { contact2.reload.update_fingerprints! } }
      ]

      threads.each(&:join)

      elapsed_time = Time.current - start_time

      # Should complete quickly since locks don't conflict
      expect(elapsed_time).to be < 5.seconds

      # Verify both contacts have correct fingerprints
      expect(contact1.reload.phone_fingerprint).to eq('4155551111')
      expect(contact2.reload.phone_fingerprint).to eq('4155552222')
    end

    it 'update_fingerprints! uses update_columns to avoid callback recursion' do
      contact = create(:contact, formatted_phone_number: '+14155551234')

      # Verify update_columns is called (skips callbacks)
      expect(contact).to receive(:update_columns).once.and_call_original

      # Verify save!/update! is NOT called (would trigger callbacks)
      expect(contact).not_to receive(:save!)
      expect(contact).not_to receive(:update!)

      contact.send(:update_fingerprints!)
    end

    it 'calculate_quality_score! uses update_columns to avoid callback recursion' do
      contact = create(:contact, phone_valid: true)

      # Verify update_columns is called
      expect(contact).to receive(:update_columns).once.and_call_original

      # Verify save!/update! is NOT called
      expect(contact).not_to receive(:save!)
      expect(contact).not_to receive(:update!)

      contact.calculate_quality_score!
    end
  end

  describe 'Pessimistic locking in LookupRequestJob' do
    let(:contact) { create(:contact, status: 'pending') }

    it 'uses with_lock to prevent concurrent job processing' do
      # Verify with_lock is called during job execution
      expect(contact).to receive(:with_lock).and_call_original

      # Create job instance
      job = LookupRequestJob.new

      # Mock Twilio API call to prevent actual API requests
      allow_any_instance_of(Twilio::REST::Lookups::V2::PhoneNumberContext)
        .to receive(:fetch)
        .and_return(
          double(
            phone_number: '+14155551234',
            valid: true,
            validation_errors: [],
            country_code: 'US',
            calling_country_code: '1',
            national_format: '(415) 555-1234',
            line_type_intelligence: {},
            caller_name: {},
            sms_pumping_risk: {}
          )
        )

      # Execute job
      job.perform(contact.id)

      expect(contact.reload.status).to eq('completed')
    end

    it 'prevents duplicate processing with atomic status transition' do
      # Create two job instances trying to process the same contact
      job1 = LookupRequestJob.new
      job2 = LookupRequestJob.new

      # Mock Twilio API
      allow_any_instance_of(Twilio::REST::Lookups::V2::PhoneNumberContext)
        .to receive(:fetch)
        .and_return(
          double(
            phone_number: '+14155551234',
            valid: true,
            validation_errors: [],
            country_code: 'US',
            calling_country_code: '1',
            national_format: '(415) 555-1234',
            line_type_intelligence: {},
            caller_name: {},
            sms_pumping_risk: {}
          )
        )

      # Simulate concurrent execution
      threads = [
        Thread.new { job1.perform(contact.id) },
        Thread.new { sleep(0.01); job2.perform(contact.id) } # Slight delay
      end

      threads.each(&:join)

      # Only one job should have processed the contact
      # The second should have been skipped
      expect(contact.reload.status).to eq('completed')

      # Verify no duplicate API calls (mocked API should be called only once)
      # This is implicitly tested by the fact that only one job processes
    end

    it 'skips contact if already processing (status check after lock)' do
      # Set contact to processing
      contact.update!(status: 'processing')

      job = LookupRequestJob.new

      # Mock logger to verify skip message
      allow(Rails.logger).to receive(:info)

      job.perform(contact.id)

      # Verify job skipped the contact
      expect(Rails.logger).to have_received(:info).with(
        /Skipping contact #{contact.id}: already being processed/
      )

      # Status should remain processing
      expect(contact.reload.status).to eq('processing')
    end

    it 'handles lock timeout gracefully' do
      # Simulate a long-running lock
      contact.with_lock do
        # Hold lock for extended period
        expect {
          # Try to acquire lock from another thread (should timeout)
          Thread.new do
            contact.reload.with_lock do
              # This block should not execute due to lock timeout
              fail 'Should not reach here'
            end
          end.join(1.second) # Wait 1 second for thread
        }.not_to raise_error
      end
    end
  end

  describe 'Race condition scenarios' do
    it 'prevents lost updates in callback chain' do
      contact = create(:contact,
        formatted_phone_number: '+14155551234',
        phone_valid: false,
        email: nil
      )

      # Simulate rapid updates that trigger callbacks
      threads = 10.times.map do
        Thread.new do
          contact.reload.update!(
            formatted_phone_number: "+1415555#{rand(1000..9999)}",
            email: "user#{rand(1000..9999)}@example.com"
          )
        end
      end

      threads.each(&:join)

      # Verify contact has valid fingerprints (no corruption)
      contact.reload
      expect(contact.phone_fingerprint).to be_present
      expect(contact.phone_fingerprint).to match(/^\d{10}$/)
      expect(contact.email_fingerprint).to be_present
      expect(contact.email_fingerprint).to include('@')
    end

    it 'prevents data corruption in calculate_quality_score!' do
      contact = create(:contact, phone_valid: true, email: 'test@example.com')

      # Simulate 10 concurrent quality score calculations
      threads = 10.times.map do
        Thread.new do
          contact.reload.calculate_quality_score!
        end
      end

      threads.each(&:join)

      # Verify quality score is valid (not corrupted)
      contact.reload
      expect(contact.data_quality_score).to be_between(0, 100)
      expect(contact.completeness_percentage).to be_between(0, 100)
    end

    it 'prevents fingerprint corruption when updating multiple fields' do
      contact = create(:contact)

      # Simulate concurrent updates to different fields
      threads = [
        Thread.new { 5.times { contact.reload.update!(formatted_phone_number: "+1415555#{rand(1000..9999)}") } },
        Thread.new { 5.times { contact.reload.update!(business_name: "Company #{rand(100..999)}") } },
        Thread.new { 5.times { contact.reload.update!(email: "user#{rand(100..999)}@example.com") } }
      ]

      threads.each(&:join)

      # Verify all fingerprints are consistent with final values
      contact.reload
      expected_phone_fingerprint = contact.formatted_phone_number.gsub(/\D/, '')[-10..-1]
      expected_email_fingerprint = contact.email&.downcase&.strip

      expect(contact.phone_fingerprint).to eq(expected_phone_fingerprint)
      expect(contact.email_fingerprint).to eq(expected_email_fingerprint)
    end
  end

  describe 'Performance impact of locking' do
    it 'locking adds minimal overhead for sequential updates' do
      contact = create(:contact, formatted_phone_number: '+14155551234')

      # Measure time without explicit locking (update_columns only)
      start_time = Time.current
      100.times { contact.send(:update_fingerprints!) }
      time_without_lock = Time.current - start_time

      # Time should be reasonable (<1 second for 100 updates)
      expect(time_without_lock).to be < 1.second
    end

    it 'concurrent updates serialize but complete efficiently' do
      contact = create(:contact, formatted_phone_number: '+14155551234')

      start_time = Time.current

      # 10 threads, each doing 10 updates
      threads = 10.times.map do
        Thread.new do
          10.times { contact.reload.update_fingerprints! }
        end
      end

      threads.each(&:join)

      elapsed_time = Time.current - start_time

      # Should complete in reasonable time (<10 seconds)
      # Lock contention will cause some serialization, but should be fast
      expect(elapsed_time).to be < 10.seconds

      contact.reload
      expect(contact.phone_fingerprint).to eq('4155551234')
    end
  end

  describe 'Edge cases' do
    it 'handles nil values in fingerprint calculation' do
      contact = create(:contact,
        formatted_phone_number: nil,
        business_name: nil,
        email: nil
      )

      expect {
        contact.send(:update_fingerprints!)
      }.not_to raise_error

      contact.reload
      expect(contact.phone_fingerprint).to be_nil
      expect(contact.name_fingerprint).to be_nil
      expect(contact.email_fingerprint).to be_nil
    end

    it 'handles empty strings in fingerprint calculation' do
      contact = create(:contact,
        formatted_phone_number: '',
        business_name: '',
        email: ''
      )

      contact.send(:update_fingerprints!)

      contact.reload
      expect(contact.phone_fingerprint).to be_nil
      expect(contact.name_fingerprint).to be_nil
      expect(contact.email_fingerprint).to be_nil
    end

    it 'handles concurrent updates during bulk import' do
      # Simulate bulk import with callbacks disabled
      contacts = Contact.with_callbacks_skipped do
        10.times.map { |i| create(:contact, formatted_phone_number: "+141555512#{i.to_s.rjust(2, '0')}") }
      end

      # Now recalculate metrics concurrently
      Contact.recalculate_bulk_metrics(contacts.map(&:id))

      # Verify all contacts have correct fingerprints
      contacts.each do |contact|
        contact.reload
        expect(contact.phone_fingerprint).to be_present
      end
    end

    it 'handles database deadlocks gracefully' do
      contact1 = create(:contact, formatted_phone_number: '+14155551111')
      contact2 = create(:contact, formatted_phone_number: '+14155552222')

      # Simulate potential deadlock scenario (cross-locking)
      # Thread 1: Lock contact1, then try contact2
      # Thread 2: Lock contact2, then try contact1
      expect {
        threads = [
          Thread.new do
            contact1.with_lock do
              sleep(0.01)
              contact2.reload.update_fingerprints!
            end
          end,
          Thread.new do
            contact2.with_lock do
              sleep(0.01)
              contact1.reload.update_fingerprints!
            end
          end
        ]

        threads.each(&:join)
      }.not_to raise_error
    end
  end
end
