class EmailEnrichmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 2 do |job, exception|
    contact_id = job.arguments.first
    contact = Contact.find_by(id: contact_id)
    Rails.logger.warn("Email enrichment failed for contact #{contact_id}: #{exception.message}")
  end

  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("Contact not found for email enrichment: #{exception.message}")
  end

  # Note: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)
    # Skip if already enriched
    if contact.email_enriched?
      Rails.logger.info("Skipping contact #{contact.id}: email already enriched")
      return
    end

    # Skip if email enrichment disabled
    credentials = TwilioCredential.current
    unless credentials&.enable_email_enrichment
      Rails.logger.info("Email enrichment disabled in settings")
      return
    end

    # Perform enrichment
    Rails.logger.info("Enriching email data for contact #{contact.id}")

    success = EmailEnrichmentService.enrich(contact)

    if success
      Rails.logger.info("Successfully enriched contact #{contact.id} with email data")

      # Queue duplicate detection after email enrichment
      if credentials&.enable_duplicate_detection
        DuplicateDetectionJob.perform_later(contact_id)
      end
    else
      Rails.logger.info("No email data found for contact #{contact.id}")
    end

  rescue StandardError => e
    Rails.logger.error("Unexpected error enriching email for contact #{contact.id}: #{e.class} - #{e.message}")
    raise
  end
end
