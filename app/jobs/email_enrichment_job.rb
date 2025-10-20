class EmailEnrichmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 2 do |job, exception|
    contact = job.arguments.first
    Rails.logger.warn("Email enrichment failed for contact #{contact.id}: #{exception.message}")
  end

  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("Contact not found for email enrichment: #{exception.message}")
  end

  def perform(contact)
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
        DuplicateDetectionJob.perform_later(contact)
      end
    else
      Rails.logger.info("No email data found for contact #{contact.id}")
    end

  rescue => e
    Rails.logger.error("Unexpected error enriching email for contact #{contact.id}: #{e.class} - #{e.message}")
    raise
  end
end
