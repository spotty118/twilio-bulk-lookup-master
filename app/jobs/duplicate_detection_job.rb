class DuplicateDetectionJob < ApplicationJob
  queue_as :default

  def perform(contact)
    # Skip if already marked as duplicate
    return if contact.is_duplicate?

    credentials = TwilioCredential.current
    return unless credentials&.enable_duplicate_detection

    Rails.logger.info("Checking for duplicates: contact #{contact.id}")

    # Find potential duplicates
    duplicates = DuplicateDetectionService.find_duplicates(contact)

    if duplicates.any?
      Rails.logger.info("Found #{duplicates.length} potential duplicates for contact #{contact.id}")

      # Store duplicate check timestamp
      contact.update(duplicate_checked_at: Time.current)

      # Auto-merge if enabled and high confidence
      if credentials.auto_merge_duplicates
        duplicates.each do |dup|
          if dup[:confidence] >= 95
            Rails.logger.info("Auto-merging contact #{dup[:contact].id} into #{contact.id} (confidence: #{dup[:confidence]}%)")
            DuplicateDetectionService.merge(contact, dup[:contact])
          end
        end
      end
    else
      Rails.logger.info("No duplicates found for contact #{contact.id}")
      contact.update(duplicate_checked_at: Time.current)
    end

  rescue => e
    Rails.logger.error("Duplicate detection error for contact #{contact.id}: #{e.message}")
  end
end
