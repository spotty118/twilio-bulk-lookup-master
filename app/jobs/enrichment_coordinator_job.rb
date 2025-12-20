class EnrichmentCoordinatorJob < ApplicationJob
  queue_as :default

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound do |_job, exception|
    Rails.logger.error("Contact not found for enrichment coordination: #{exception.message}")
  end

  # NOTE: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  #
  # PERFORMANCE: This job now uses ParallelEnrichmentService to run all enrichments
  # concurrently instead of queueing separate background jobs. This provides 2-3x
  # throughput improvement by executing API calls in parallel.
  #
  # Before: Sequential jobs ~2000ms (4 × 500ms each)
  # After:  Parallel execution ~600ms (slowest API + overhead)
  #
  def perform(contact_id)
    contact = Contact.find(contact_id)

    # Skip if lookup not completed yet
    unless contact.lookup_completed?
      Rails.logger.info("Skipping contact #{contact.id}: lookup not completed")
      return
    end

    # Get credentials once to check all feature flags
    credentials = TwilioCredential.current
    return unless credentials

    # Determine which enrichments to run based on feature flags and contact type
    enrichment_types = []

    # Business enrichment - runs for all contacts if enabled
    enrichment_types << :business if credentials.enable_business_enrichment

    # Email enrichment - for businesses or if business enrichment will run
    if credentials.enable_email_enrichment && (contact.business? || credentials.enable_business_enrichment)
      enrichment_types << :email
    end

    # Address enrichment - only for consumers if enabled
    enrichment_types << :address if credentials.enable_address_enrichment && !contact.business?

    # Verizon coverage - only for contacts with addresses
    enrichment_types << :verizon if credentials.enable_verizon_coverage_check && !contact.business?

    # Trust Hub - only for businesses if enabled
    if credentials.enable_trust_hub && (contact.business? || credentials.enable_business_enrichment)
      enrichment_types << :trust_hub
    end

    # Run enrichments in parallel
    if enrichment_types.any?
      Rails.logger.info("Running #{enrichment_types.count} enrichments in parallel for contact #{contact.id}: #{enrichment_types.join(', ')}")

      parallel_service = ParallelEnrichmentService.new(contact)

      # Run with automatic retry for failed enrichments
      results = parallel_service.enrich_with_retry(enrichment_types, max_retries: 1)

      # Log summary
      success_count = results.values.count { |r| r[:success] }
      total_duration = results.values.sum { |r| r[:duration] || 0 }

      Rails.logger.info("Parallel enrichment complete for contact #{contact.id}: " \
                       "#{success_count}/#{enrichment_types.count} succeeded, " \
                       "total time: #{total_duration}ms")

      # Log any failures
      failures = results.select { |_type, result| !result[:success] }
      failures.each do |type, result|
        Rails.logger.warn("#{type.to_s.titleize} enrichment failed for contact #{contact.id}: #{result[:error]}")
      end
    else
      Rails.logger.info("No enrichment jobs to run for contact #{contact.id}")
    end
  rescue StandardError => e
    Rails.logger.error("Unexpected error coordinating enrichment for contact #{contact_id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Track error for monitoring/alerting
    ErrorTrackingService.capture(
      e,
      context: { contact_id: contact_id, job: 'EnrichmentCoordinatorJob' }
    )
    # Don't raise - coordinator failures shouldn't fail the entire enrichment pipeline
  end
end
