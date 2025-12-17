# frozen_string_literal: true

require 'rails_helper'

# INFRASTRUCTURE REQUIRED:
# - PostgreSQL with SERIALIZABLE isolation (or READ COMMITTED with proper locking)
# - Redis (for Sidekiq background jobs)
# - Run with: SIDEKIQ_CONCURRENCY=10 bundle exec rspec spec/integration/bulk_import_with_recalculation_spec.rb

RSpec.describe 'Bulk import workflow with metric recalculation', type: :integration do
  include ActiveJob::TestHelper

  describe 'bulk import with callbacks skipped + background recalculation' do
    it 'imports 1000 contacts efficiently, then recalculates metrics via background job' do
      # Phase 1: Bulk import with callbacks skipped (fast)
      import_start_time = Time.current

      contact_ids = Contact.with_callbacks_skipped do
        1000.times.map do |i|
          Contact.create!(
            raw_phone_number: "+141555#{i.to_s.rjust(5, '0')}",
            full_name: "Test User #{i}",
            email: "user#{i}@example.com",
            status: 'pending'
          ).id
        end
      end

      import_duration = Time.current - import_start_time

      # Verify import was fast (should be < 10 seconds for 1000 contacts)
      expect(import_duration).to be < 10.seconds

      # Verify all contacts were created
      expect(Contact.where(id: contact_ids).count).to eq(1000)

      # Phase 2: Verify fingerprints and quality scores are NOT calculated yet
      contacts_without_fingerprints = Contact.where(id: contact_ids)
                                             .where(phone_fingerprint: nil)
                                             .count
      expect(contacts_without_fingerprints).to eq(1000)

      contacts_without_quality_scores = Contact.where(id: contact_ids)
                                               .where(data_quality_score: nil)
                                               .count
      expect(contacts_without_quality_scores).to eq(1000)

      # Phase 3: Enqueue RecalculateContactMetricsJob
      RecalculateContactMetricsJob.perform_later(contact_ids)

      # Verify job was enqueued
      expect(enqueued_jobs.size).to eq(1)
      expect(enqueued_jobs.first[:job]).to eq(RecalculateContactMetricsJob)

      # Phase 4: Process enqueued jobs (simulates Sidekiq processing)
      recalculation_start_time = Time.current
      perform_enqueued_jobs
      recalculation_duration = Time.current - recalculation_start_time

      # Verify recalculation completed (should be < 30 seconds for 1000 contacts)
      expect(recalculation_duration).to be < 30.seconds

      # Phase 5: Verify all fingerprints are now calculated
      contacts_with_fingerprints = Contact.where(id: contact_ids)
                                          .where.not(phone_fingerprint: nil)
                                          .count
      expect(contacts_with_fingerprints).to eq(1000)

      # Phase 6: Verify all quality scores are now calculated
      contacts_with_quality_scores = Contact.where(id: contact_ids)
                                            .where.not(data_quality_score: nil)
                                            .count
      expect(contacts_with_quality_scores).to eq(1000)

      # Phase 7: Spot-check fingerprint accuracy
      sample_contact = Contact.find(contact_ids.first)
      expect(sample_contact.phone_fingerprint).to eq('4155500000')
      expect(sample_contact.name_fingerprint).to eq('0 test user')
      expect(sample_contact.email_fingerprint).to eq('user0@example.com')

      # Phase 8: Verify quality scores are reasonable
      average_quality_score = Contact.where(id: contact_ids)
                                     .average(:data_quality_score)
                                     .to_f
      expect(average_quality_score).to be > 20  # Should have some quality (phone, name, email populated)
      expect(average_quality_score).to be < 60  # Not fully enriched yet
    end

    it 'handles large batch (10,000 contacts) with chunked job processing' do
      # Create 10,000 contacts with callbacks skipped
      contact_ids = Contact.with_callbacks_skipped do
        10_000.times.map do |i|
          Contact.create!(
            raw_phone_number: "+141666#{i.to_s.rjust(5, '0')}",
            status: 'pending'
          ).id
        end
      end

      # Enqueue RecalculateContactMetricsJob (should auto-chunk into batches of 100)
      RecalculateContactMetricsJob.perform_later(contact_ids)

      # Should enqueue multiple jobs (10,000 / 100 = 100 batches)
      # Note: First job processes 100, then enqueues next batch
      perform_enqueued_jobs

      # Verify all contacts have fingerprints after batch processing
      contacts_with_fingerprints = Contact.where(id: contact_ids)
                                          .where.not(phone_fingerprint: nil)
                                          .count
      expect(contacts_with_fingerprints).to eq(10_000)
    end

    it 'preserves data integrity when contacts have partial data' do
      # Create contacts with varying levels of completeness
      contact_ids = Contact.with_callbacks_skipped do
        [
          # Full data
          Contact.create!(
            raw_phone_number: '+14155551111',
            full_name: 'John Doe',
            email: 'john@example.com',
            business_name: 'Acme Corp',
            status: 'pending'
          ),
          # Phone only
          Contact.create!(
            raw_phone_number: '+14155552222',
            status: 'pending'
          ),
          # Phone and name only
          Contact.create!(
            raw_phone_number: '+14155553333',
            full_name: 'Jane Smith',
            status: 'pending'
          )
        ].map(&:id)
      end

      # Recalculate metrics
      Contact.recalculate_bulk_metrics(contact_ids)

      # Verify fingerprints calculated correctly
      contact1 = Contact.find(contact_ids[0])
      expect(contact1.phone_fingerprint).to eq('4155551111')
      expect(contact1.name_fingerprint).to eq('doe john')
      expect(contact1.email_fingerprint).to eq('john@example.com')
      expect(contact1.data_quality_score).to be > 50  # High quality (4 fields populated)

      contact2 = Contact.find(contact_ids[1])
      expect(contact2.phone_fingerprint).to eq('4155552222')
      expect(contact2.name_fingerprint).to be_nil
      expect(contact2.email_fingerprint).to be_nil
      expect(contact2.data_quality_score).to be < 30  # Low quality (only phone)

      contact3 = Contact.find(contact_ids[2])
      expect(contact3.phone_fingerprint).to eq('4155553333')
      expect(contact3.name_fingerprint).to eq('jane smith')
      expect(contact3.email_fingerprint).to be_nil
      expect(contact3.data_quality_score).to be_between(30, 50) # Medium quality
    end

    it 'correctly handles duplicate detection after bulk import' do
      # Phase 1: Bulk import with callbacks skipped (no duplicate detection yet)
      contact_ids = Contact.with_callbacks_skipped do
        [
          Contact.create!(raw_phone_number: '+14155551234', full_name: 'John Doe'),
          Contact.create!(raw_phone_number: '+14155551234', full_name: 'John Doe'), # Duplicate phone + name
          Contact.create!(raw_phone_number: '+14155555678', full_name: 'Jane Smith')
        ].map(&:id)
      end

      # Verify duplicates NOT detected yet (callbacks were skipped)
      expect(Contact.where(id: contact_ids, is_duplicate: true).count).to eq(0)

      # Phase 2: Recalculate metrics (triggers fingerprint calculation)
      Contact.recalculate_bulk_metrics(contact_ids)

      # Phase 3: Run DuplicateDetectionJob manually (normally runs as background job)
      Contact.where(id: contact_ids).find_each do |contact|
        duplicates = Contact.where(phone_fingerprint: contact.phone_fingerprint)
                            .where.not(id: contact.id)
                            .where('created_at < ?', contact.created_at)

        if duplicates.exists?
          contact.update!(
            is_duplicate: true,
            duplicate_of_id: duplicates.first.id
          )
        end
      end

      # Verify duplicate was detected
      contact1 = Contact.find(contact_ids[0])
      contact2 = Contact.find(contact_ids[1])
      contact3 = Contact.find(contact_ids[2])

      expect(contact1.is_duplicate).to be false  # First occurrence
      expect(contact2.is_duplicate).to be true   # Duplicate of contact1
      expect(contact2.duplicate_of_id).to eq(contact1.id)
      expect(contact3.is_duplicate).to be false  # Unique phone number
    end

    it 'eventual consistency: normal saves still trigger callbacks after bulk import' do
      # Phase 1: Bulk import with callbacks skipped
      bulk_contact_ids = Contact.with_callbacks_skipped do
        10.times.map { |i| Contact.create!(raw_phone_number: "+141577#{i.to_s.rjust(5, '0')}").id }
      end

      # Verify fingerprints NOT calculated
      expect(Contact.where(id: bulk_contact_ids).where.not(phone_fingerprint: nil).count).to eq(0)

      # Phase 2: Create new contact normally (outside bulk import block)
      normal_contact = Contact.create!(
        raw_phone_number: '+14155559999',
        full_name: 'Normal User',
        status: 'pending'
      )

      # Verify callbacks ran for normal save
      expect(normal_contact.phone_fingerprint).not_to be_nil
      expect(normal_contact.phone_fingerprint).to eq('4155559999')
      expect(normal_contact.name_fingerprint).to eq('normal user')
      expect(normal_contact.data_quality_score).not_to be_nil

      # Phase 3: Update existing contact normally
      bulk_contact = Contact.find(bulk_contact_ids.first)
      bulk_contact.update!(full_name: 'Updated Name')

      # Verify callbacks ran for normal update
      bulk_contact.reload
      expect(bulk_contact.phone_fingerprint).not_to be_nil # Should be calculated on update
      expect(bulk_contact.name_fingerprint).to eq('name updated')
    end
  end

  describe 'performance benchmarks' do
    it 'bulk import is at least 2x faster than normal import' do
      # Benchmark: Normal import (with callbacks)
      normal_start_time = Time.current
      normal_contact_ids = 100.times.map do |i|
        Contact.create!(raw_phone_number: "+141588#{i.to_s.rjust(5, '0')}").id
      end
      normal_duration = Time.current - normal_start_time

      # Clean up
      Contact.where(id: normal_contact_ids).delete_all

      # Benchmark: Bulk import (callbacks skipped)
      bulk_start_time = Time.current
      bulk_contact_ids = Contact.with_callbacks_skipped do
        100.times.map { |i| Contact.create!(raw_phone_number: "+141599#{i.to_s.rjust(5, '0')}").id }
      end
      bulk_duration = Time.current - bulk_start_time

      # Verify bulk import is at least 2x faster
      expect(bulk_duration).to be < (normal_duration / 2)

      # Log benchmark results
      Rails.logger.info("Bulk import performance: Normal=#{normal_duration.round(2)}s, Bulk=#{bulk_duration.round(2)}s, Speedup=#{(normal_duration / bulk_duration).round(2)}x")
    end

    it 'recalculation processes 1000 contacts in under 30 seconds' do
      contact_ids = Contact.with_callbacks_skipped do
        1000.times.map { |i| Contact.create!(raw_phone_number: "+141500#{i.to_s.rjust(5, '0')}").id }
      end

      start_time = Time.current
      Contact.recalculate_bulk_metrics(contact_ids)
      duration = Time.current - start_time

      expect(duration).to be < 30.seconds

      Rails.logger.info("Recalculation performance: 1000 contacts in #{duration.round(2)}s (#{(1000 / duration).round(2)} contacts/sec)")
    end
  end

  describe 'error handling during bulk operations' do
    it 'rolls back transaction if bulk import fails mid-batch' do
      initial_count = Contact.count

      expect do
        Contact.transaction do
          Contact.with_callbacks_skipped do
            # Create 5 valid contacts
            5.times { |i| Contact.create!(raw_phone_number: "+141511#{i.to_s.rjust(5, '0')}") }

            # Raise error mid-batch
            raise ActiveRecord::Rollback
          end
        end
      end.not_to change(Contact, :count)

      # Verify no contacts were persisted
      expect(Contact.count).to eq(initial_count)
    end

    it 'continues recalculation even if individual contact update fails' do
      contact_ids = Contact.with_callbacks_skipped do
        [
          Contact.create!(raw_phone_number: '+14155551111'),
          Contact.create!(raw_phone_number: '+14155552222'),
          Contact.create!(raw_phone_number: '+14155553333')
        ].map(&:id)
      end

      # Stub contacts to raise error on first call only
      call_count = 0
      allow_any_instance_of(Contact).to receive(:update_fingerprints!) do
        call_count += 1
        raise StandardError, 'Simulated error' if call_count == 1
      end

      # Should not raise error (should rescue and continue)
      expect do
        Contact.recalculate_bulk_metrics(contact_ids)
      end.not_to raise_error

      # At least some contacts should have fingerprints calculated
      contacts_with_fingerprints = Contact.where(id: contact_ids)
                                          .where.not(phone_fingerprint: nil)
                                          .count
      expect(contacts_with_fingerprints).to be >= 2
    end
  end

  describe 'thread safety' do
    it 'handles concurrent bulk imports in different threads correctly' do
      thread1_fingerprints = []
      thread2_fingerprints = []

      t1 = Thread.new do
        Contact.with_callbacks_skipped do
          sleep 0.1 # Ensure threads overlap
          contact = Contact.create!(raw_phone_number: '+14155551111')
          thread1_fingerprints << contact.phone_fingerprint
        end
      end

      t2 = Thread.new do
        sleep 0.05
        # This thread does NOT skip callbacks
        contact = Contact.create!(raw_phone_number: '+14155552222')
        thread2_fingerprints << contact.phone_fingerprint
      end

      t1.join
      t2.join

      # Thread 1 (callbacks skipped) should have nil fingerprint
      expect(thread1_fingerprints.first).to be_nil

      # Thread 2 (callbacks enabled) should have fingerprint
      expect(thread2_fingerprints.first).to eq('4155552222')
    end

    it 'nested with_callbacks_skipped blocks work correctly' do
      outer_contact = nil
      inner_contact = nil
      post_block_contact = nil

      Contact.with_callbacks_skipped do
        outer_contact = Contact.create!(raw_phone_number: '+14155551111')

        Contact.with_callbacks_skipped do
          inner_contact = Contact.create!(raw_phone_number: '+14155552222')
        end
      end

      post_block_contact = Contact.create!(raw_phone_number: '+14155553333')

      # Both outer and inner should skip callbacks
      expect(outer_contact.phone_fingerprint).to be_nil
      expect(inner_contact.phone_fingerprint).to be_nil

      # Post-block should have callbacks enabled
      expect(post_block_contact.phone_fingerprint).to eq('4155553333')
    end
  end
end
