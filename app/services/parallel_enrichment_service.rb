# frozen_string_literal: true

require 'concurrent'

# ParallelEnrichmentService - Coordinates parallel execution of multiple enrichment services
#
# Instead of running enrichments sequentially (slow), this service executes them in parallel
# using Concurrent Ruby promises. This can provide 2-3x throughput improvement for contacts
# that require multiple enrichments.
#
# Usage:
#   service = ParallelEnrichmentService.new(contact)
#   results = service.enrich_all
#
#   # Or selectively enrich
#   results = service.enrich([:business, :email, :address])
#
# Performance:
#   Sequential: 4 API calls × 500ms each = 2,000ms total
#   Parallel:   4 API calls in parallel   = ~600ms total (slowest API + overhead)
#
class ParallelEnrichmentService
  attr_reader :contact, :credentials

  # Available enrichment types
  ENRICHMENT_TYPES = {
    business: { service: BusinessEnrichmentService, enabled_flag: :enable_business_enrichment },
    email: { service: EmailEnrichmentService, enabled_flag: :enable_email_enrichment },
    address: { service: AddressEnrichmentService, enabled_flag: :enable_address_enrichment },
    verizon: { service: VerizonCoverageService, enabled_flag: :enable_verizon_coverage_check, method: :check_coverage },
    trust_hub: { service: TrustHubEnrichmentService, enabled_flag: :enable_trust_hub, method: :enrich }
  }.freeze

  def initialize(contact)
    @contact = contact
    @credentials = TwilioCredential.current
  end

  #
  # Enrich contact with all enabled services in parallel
  #
  # Returns hash of results:
  #   {
  #     business: { success: true, duration: 450 },
  #     email: { success: true, duration: 320 },
  #     address: { success: false, error: "API timeout", duration: 5000 },
  #     ...
  #   }
  #
  def enrich_all
    enabled_types = ENRICHMENT_TYPES.keys.select { |type| enrichment_enabled?(type) }
    enrich(enabled_types)
  end

  #
  # Enrich contact with specific services in parallel
  #
  # @param types [Array<Symbol>] Array of enrichment types to run (e.g., [:business, :email])
  # @return [Hash] Results for each enrichment type
  #
  def enrich(types = [])
    return {} if types.empty?

    # Validate types
    invalid_types = types - ENRICHMENT_TYPES.keys
    raise ArgumentError, "Invalid enrichment types: #{invalid_types.join(', ')}" if invalid_types.any?

    start_time = Time.current

    # Create a promise for each enrichment
    promises = types.map do |type|
      {
        type: type,
        promise: Concurrent::Promise.execute do
          execute_enrichment(type)
        end
      }
    end

    # Wait for all promises to complete and collect results
    results = promises.each_with_object({}) do |item, hash|
      type = item[:type]
      promise = item[:promise]

      begin
        # Wait for promise to complete (with timeout)
        result = promise.value!(10) # 10 second timeout per enrichment
        hash[type] = result
      rescue Concurrent::TimeoutError
        hash[type] = {
          success: false,
          error: 'Enrichment timeout (10s)',
          duration: 10_000
        }
      rescue StandardError => e
        hash[type] = {
          success: false,
          error: "#{e.class}: #{e.message}",
          duration: nil
        }
      end
    end

    total_duration = ((Time.current - start_time) * 1000).round

    # Log summary
    success_count = results.values.count { |r| r[:success] }
    Rails.logger.info "Parallel enrichment completed for contact #{contact.id}: " \
                     "#{success_count}/#{types.count} succeeded in #{total_duration}ms " \
                     "(vs ~#{estimated_sequential_time(types)}ms sequential)"

    results
  end

  #
  # Enrich contact with retries for failed enrichments
  #
  # @param types [Array<Symbol>] Enrichment types to run
  # @param max_retries [Integer] Maximum number of retries per enrichment
  # @return [Hash] Final results after retries
  #
  def enrich_with_retry(types = [], max_retries: 2)
    results = enrich(types)

    # Retry failed enrichments
    max_retries.times do |attempt|
      failed_types = results.select { |_type, result| !result[:success] }.keys
      break if failed_types.empty?

      Rails.logger.info "Retrying #{failed_types.count} failed enrichments (attempt #{attempt + 1}/#{max_retries})"

      retry_results = enrich(failed_types)
      results.merge!(retry_results)
    end

    results
  end

  private

  #
  # Execute a single enrichment
  #
  def execute_enrichment(type)
    config = ENRICHMENT_TYPES[type]
    service_class = config[:service]
    method_name = config[:method] || :enrich

    start_time = Time.current

    begin
      service = service_class.new(contact)
      result = service.send(method_name)
      duration = ((Time.current - start_time) * 1000).round

      {
        success: true,
        result: result,
        duration: duration
      }
    rescue StandardError => e
      duration = ((Time.current - start_time) * 1000).round

      Rails.logger.error "#{type.to_s.titleize} enrichment failed for contact #{contact.id}: #{e.class} - #{e.message}"

      {
        success: false,
        error: "#{e.class}: #{e.message}",
        duration: duration
      }
    end
  end

  #
  # Check if enrichment type is enabled in credentials
  #
  def enrichment_enabled?(type)
    return false unless credentials

    config = ENRICHMENT_TYPES[type]
    enabled_flag = config[:enabled_flag]

    credentials.send(enabled_flag) if enabled_flag && credentials.respond_to?(enabled_flag)
  end

  #
  # Estimate how long sequential execution would take
  # (for comparison logging)
  #
  def estimated_sequential_time(types)
    # Assume average 500ms per enrichment
    types.count * 500
  end

  #
  # Class method: Enrich multiple contacts in parallel batches
  #
  # This is useful for bulk enrichment jobs
  #
  # @param contacts [Array<Contact>] Contacts to enrich
  # @param batch_size [Integer] Number of contacts to process in parallel
  # @param enrichment_types [Array<Symbol>] Which enrichments to run
  #
  def self.enrich_batch(contacts, batch_size: 5, enrichment_types: nil)
    enrichment_types ||= ENRICHMENT_TYPES.keys

    total_start = Time.current
    all_results = []

    contacts.each_slice(batch_size) do |batch|
      batch_start = Time.current

      # Process each contact in the batch in parallel
      batch_promises = batch.map do |contact|
        Concurrent::Promise.execute do
          service = new(contact)
          {
            contact_id: contact.id,
            results: service.enrich(enrichment_types)
          }
        end
      end

      # Collect batch results
      batch_results = batch_promises.map { |p| p.value!(30) }
      all_results.concat(batch_results)

      batch_duration = ((Time.current - batch_start) * 1000).round
      Rails.logger.info "Batch of #{batch.count} contacts enriched in #{batch_duration}ms"
    end

    total_duration = ((Time.current - total_start) * 1000).round
    Rails.logger.info "Total: #{contacts.count} contacts enriched in #{total_duration}ms " \
                     "(avg #{total_duration / contacts.count}ms per contact)"

    all_results
  end
end
