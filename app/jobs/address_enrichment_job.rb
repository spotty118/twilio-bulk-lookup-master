class AddressEnrichmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Don't retry if contact was deleted
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("[AddressEnrichmentJob] Contact not found: #{exception.message}")
  end

  # Note: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)

    # Skip if address enrichment disabled
    credentials = TwilioCredential.current
    unless credentials&.enable_address_enrichment
      Rails.logger.info("[AddressEnrichmentJob] Address enrichment disabled in settings")
      return
    end

    Rails.logger.info "[AddressEnrichmentJob] Starting address enrichment for contact #{contact.id}"

    service = AddressEnrichmentService.new(contact)
    success = service.enrich

    if success
      Rails.logger.info "[AddressEnrichmentJob] Successfully enriched address for contact #{contact.id}"
    else
      Rails.logger.warn "[AddressEnrichmentJob] Address enrichment returned false for contact #{contact.id}"
    end

  # Keep broad StandardError rescue at outermost level to ensure job failures are properly logged
  # and retried via Sidekiq's retry mechanism. This prevents silent failures in the background job queue.
  rescue StandardError => e
    Rails.logger.error "[AddressEnrichmentJob] Error enriching contact #{contact.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
