class DuplicateDetectionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: ->(executions) { (executions ** 4) + rand(30) }, attempts: 3

  # Don't retry if contact was deleted
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("[DuplicateDetectionJob] Contact not found: #{exception.message}")
  end

  # Note: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)

    # Skip if already marked as duplicate
    return if contact.is_duplicate?

    credentials = TwilioCredential.current
    return if credentials && !credentials.enable_duplicate_detection

    Rails.logger.info("Checking for duplicates: contact #{contact.id}")

    # Find potential duplicates
    duplicates = DuplicateDetectionService.find_duplicates(contact)

    if duplicates.any?
      Rails.logger.info("Found #{duplicates.length} potential duplicates for contact #{contact.id}")

      # Store duplicate check timestamp
      contact.update!(duplicate_checked_at: Time.current)

      # Auto-merge if enabled and high confidence
      if credentials&.auto_merge_duplicates
        duplicates.each do |dup|
          if dup[:confidence] >= 95
            Rails.logger.info("Auto-merging contact #{dup[:contact].id} into #{contact.id} (confidence: #{dup[:confidence]}%)")
            DuplicateDetectionService.merge(contact, dup[:contact])
          end
        end
      end
    else
      Rails.logger.info("No duplicates found for contact #{contact.id}")
      contact.update!(duplicate_checked_at: Time.current)
    end

  rescue StandardError => e
    Rails.logger.error("Duplicate detection error for contact #{contact.id}: #{e.message}")
    raise # Re-raise to trigger retry logic
  end
end
