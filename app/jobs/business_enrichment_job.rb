class BusinessEnrichmentJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 2 do |job, exception|
    contact_id = job.arguments.first
    contact = Contact.find_by(id: contact_id)
    Rails.logger.warn("Business enrichment failed for contact #{contact_id}: #{exception.message}")
  end

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("Contact not found for enrichment: #{exception.message}")
  end

  # Note: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)
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
      # Note: Trust Hub and Email enrichment jobs are enqueued in parallel by EnrichmentCoordinatorJob
      # They will check business_enriched? before processing
    else
      Rails.logger.info("No business data found for contact #{contact.id}")
      # Don't mark as enriched if no data found - allows future re-attempts
      # Contact will be eligible for re-enrichment on next lookup
    end

  # Keep broad StandardError rescue at outermost level to ensure job failures are properly logged
  # and retried via Sidekiq's retry mechanism. This prevents silent failures in the background job queue.
  rescue StandardError => e
    Rails.logger.error("Unexpected error enriching contact #{contact.id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end
end
