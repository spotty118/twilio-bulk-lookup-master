class BusinessLookupJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on BusinessLookupService::ProviderError do |job, exception|
    zipcode_lookup_id = job.arguments.first
    zipcode_lookup = ZipcodeLookup.find_by(id: zipcode_lookup_id)

    if zipcode_lookup
      Rails.logger.error "[BusinessLookupJob] Provider error for zipcode #{zipcode_lookup.zipcode}: #{exception.message}"
      zipcode_lookup.mark_failed!(exception)
    else
      Rails.logger.error "[BusinessLookupJob] Provider error for missing zipcode_lookup_id #{zipcode_lookup_id}: #{exception.message}"
    end
  end

  # Don't retry if zipcode lookup was deleted
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("[BusinessLookupJob] ZipcodeLookup not found: #{exception.message}")
  end

  def perform(zipcode_lookup_id)
    zipcode_lookup = ZipcodeLookup.find(zipcode_lookup_id)

    # Mark as processing
    zipcode_lookup.mark_processing!

    Rails.logger.info "[BusinessLookupJob] Starting lookup for zipcode: #{zipcode_lookup.zipcode}"

    # Perform the lookup
    service = BusinessLookupService.new(
      zipcode_lookup.zipcode,
      zipcode_lookup: zipcode_lookup
    )

    stats = service.lookup_businesses

    # Mark as completed with stats
    zipcode_lookup.mark_completed!(stats)

    Rails.logger.info "[BusinessLookupJob] Completed lookup for zipcode: #{zipcode_lookup.zipcode} - " \
                      "Found: #{stats[:found]}, Imported: #{stats[:imported]}, " \
                      "Updated: #{stats[:updated]}, Skipped: #{stats[:skipped]}"

  rescue StandardError => e
    # Guard against undefined zipcode_lookup if error occurred during find
    if defined?(zipcode_lookup) && zipcode_lookup
      Rails.logger.error "[BusinessLookupJob] Error processing zipcode #{zipcode_lookup.zipcode}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      zipcode_lookup.mark_failed!(e)
    else
      Rails.logger.error "[BusinessLookupJob] Error processing zipcode_lookup_id #{zipcode_lookup_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
    raise e
  end
end
