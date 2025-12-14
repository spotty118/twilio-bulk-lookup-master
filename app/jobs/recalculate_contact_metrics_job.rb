# frozen_string_literal: true

# RecalculateContactMetricsJob
#
# Background job to recalculate fingerprints and quality scores for contacts
# after bulk imports that skipped callbacks.
#
# This job processes contacts in batches to prevent memory issues and
# provides progress tracking for long-running operations.
#
# Usage:
#   # After bulk import with callbacks skipped:
#   RecalculateContactMetricsJob.perform_later(contact_ids)
#
#   # Process all contacts (expensive - use only for maintenance):
#   RecalculateContactMetricsJob.perform_later(Contact.pluck(:id))
#
class RecalculateContactMetricsJob < ApplicationJob
  queue_as :low_priority

  # Retry on database errors (transient failures)
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 3
  retry_on ActiveRecord::StatementInvalid, wait: :exponentially_longer, attempts: 3

  # Don't retry if contact was deleted
  discard_on ActiveRecord::RecordNotFound

  # Process in batches to prevent memory issues
  BATCH_SIZE = 100

  def perform(contact_ids, batch_index: 0)
    return if contact_ids.blank?

    Rails.logger.info("RecalculateContactMetricsJob: Processing batch #{batch_index + 1}, " \
                      "#{contact_ids.size} contacts total")

    # Process this batch
    current_batch = contact_ids.first(BATCH_SIZE)
    remaining = contact_ids.drop(BATCH_SIZE)

    process_batch(current_batch)

    # Enqueue next batch if there are more contacts
    if remaining.any?
      self.class.perform_later(remaining, batch_index: batch_index + 1)
      Rails.logger.info("RecalculateContactMetricsJob: Enqueued batch #{batch_index + 2} " \
                        "with #{remaining.size} remaining contacts")
    else
      Rails.logger.info("RecalculateContactMetricsJob: All batches completed " \
                        "(#{batch_index + 1} total batches)")
    end
  end

  private

  def process_batch(contact_ids)
    start_time = Time.current
    updated_count = 0

    Contact.where(id: contact_ids).find_each do |contact|
      # Update fingerprints for duplicate detection
      contact.update_fingerprints!

      # Recalculate quality score
      contact.calculate_quality_score!

      updated_count += 1
    rescue StandardError => e
      # Log error but continue processing other contacts
      Rails.logger.error(
        "RecalculateContactMetricsJob: Failed to update contact #{contact.id}: #{e.message}"
      )
    end

    duration = Time.current - start_time
    avg_time = duration / updated_count if updated_count.positive?

    Rails.logger.info(
      "RecalculateContactMetricsJob: Batch complete - " \
      "#{updated_count}/#{contact_ids.size} contacts updated in #{duration.round(2)}s " \
      "(avg: #{avg_time&.round(3)}s per contact)"
    )
  end
end
