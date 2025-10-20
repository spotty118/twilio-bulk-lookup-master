class BusinessLookupJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

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

  rescue => e
    Rails.logger.error "[BusinessLookupJob] Error processing zipcode #{zipcode_lookup.zipcode}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    zipcode_lookup.mark_failed!(e)
    raise e
  end
end
