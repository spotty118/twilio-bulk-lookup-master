class AddressEnrichmentJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(contact)
    contact = Contact.find(contact.id) if contact.is_a?(Contact)

    Rails.logger.info "[AddressEnrichmentJob] Starting address enrichment for contact #{contact.id}"

    service = AddressEnrichmentService.new(contact)
    success = service.enrich

    if success
      Rails.logger.info "[AddressEnrichmentJob] Successfully enriched address for contact #{contact.id}"
    else
      Rails.logger.warn "[AddressEnrichmentJob] Address enrichment returned false for contact #{contact.id}"
    end

  rescue => e
    Rails.logger.error "[AddressEnrichmentJob] Error enriching contact #{contact.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
