class EnrichmentCoordinatorJob < ApplicationJob
  queue_as :default

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("Contact not found for enrichment coordination: #{exception.message}")
  end

  # Note: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)

    # Skip if lookup not completed yet
    unless contact.lookup_completed?
      Rails.logger.info("Skipping contact #{contact.id}: lookup not completed")
      return
    end

    # Get credentials once to check all feature flags
    credentials = TwilioCredential.current

    # Collect all jobs to enqueue
    jobs_to_enqueue = []

    # Business enrichment - runs for all contacts if enabled
    if credentials&.enable_business_enrichment
      jobs_to_enqueue << { job: BusinessEnrichmentJob, reason: "business enrichment enabled" }
    end

    # Address enrichment - only for consumers if enabled
    if credentials&.enable_address_enrichment && contact.consumer?
      jobs_to_enqueue << { job: AddressEnrichmentJob, reason: "address enrichment enabled for consumer" }
    end

    # Verizon coverage - only for consumers with address enrichment enabled
    # Note: VerizonCoverageCheckJob will also check if address is enriched
    if credentials&.enable_verizon_coverage_check && contact.consumer?
      jobs_to_enqueue << { job: VerizonCoverageCheckJob, reason: "verizon coverage check enabled for consumer" }
    end

    # Trust Hub and Email enrichment - only for businesses after business enrichment
    # These will run in parallel with business enrichment, but have their own checks
    # to ensure business enrichment completed before processing
    if contact.business? || credentials&.enable_business_enrichment
      if credentials&.enable_trust_hub
        jobs_to_enqueue << { job: TrustHubEnrichmentJob, reason: "trust hub enrichment enabled for business" }
      end

      if credentials&.enable_email_enrichment
        jobs_to_enqueue << { job: EmailEnrichmentJob, reason: "email enrichment enabled for business" }
      end
    end

    # Enqueue all jobs in parallel
    if jobs_to_enqueue.any?
      Rails.logger.info("Enqueuing #{jobs_to_enqueue.size} enrichment jobs for contact #{contact.id}")

      jobs_to_enqueue.each do |job_info|
        job_info[:job].perform_later(contact.id)
        Rails.logger.info("  - Enqueued #{job_info[:job].name}: #{job_info[:reason]}")
      end
    else
      Rails.logger.info("No enrichment jobs to enqueue for contact #{contact.id}")
    end

  rescue StandardError => e
    Rails.logger.error("Unexpected error coordinating enrichment for contact #{contact_id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Don't raise - coordinator failures shouldn't fail the entire enrichment pipeline
  end
end
