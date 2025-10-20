class BusinessEnrichmentJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 2 do |job, exception|
    contact = job.arguments.first
    Rails.logger.warn("Business enrichment failed for contact #{contact.id}: #{exception.message}")
  end

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("Contact not found for enrichment: #{exception.message}")
  end

  def perform(contact)
    # Skip if already enriched
    if contact.business_enriched?
      Rails.logger.info("Skipping contact #{contact.id}: already enriched")
      return
    end

    # Skip if not completed lookup yet
    unless contact.lookup_completed?
      Rails.logger.info("Skipping contact #{contact.id}: lookup not completed")
      return
    end

    # Check if business enrichment is enabled
    credentials = TwilioCredential.current
    unless credentials&.enable_business_enrichment
      Rails.logger.info("Business enrichment disabled in settings")
      return
    end

    # Perform enrichment
    Rails.logger.info("Enriching business data for contact #{contact.id}")

    success = BusinessEnrichmentService.enrich(contact)

    if success
      Rails.logger.info("Successfully enriched contact #{contact.id} with business data")
      
      # Queue email enrichment after business enrichment
      credentials = TwilioCredential.current
      if credentials&.enable_email_enrichment
        EmailEnrichmentJob.perform_later(contact)
      end
    else
      Rails.logger.info("No business data found for contact #{contact.id}")
      # Mark as attempted even if no data found
      contact.update(
        business_enriched: true,
        business_enriched_at: Time.current,
        business_enrichment_provider: 'none'
      )
    end

  rescue => e
    Rails.logger.error("Unexpected error enriching contact #{contact.id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
