class VerizonCoverageCheckJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: ->(executions) { (executions ** 4) + rand(30) }, attempts: 3

  # Don't retry if contact was deleted
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("[VerizonCoverageCheckJob] Contact not found: #{exception.message}")
  end

  # Note: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)

    # Skip if Verizon coverage check disabled
    credentials = TwilioCredential.current
    unless credentials&.enable_verizon_coverage_check
      Rails.logger.info("[VerizonCoverageCheckJob] Verizon coverage check disabled in settings")
      return
    end

    Rails.logger.info "[VerizonCoverageCheckJob] Starting Verizon coverage check for contact #{contact.id}"

    service = VerizonCoverageService.new(contact)
    success = service.check_coverage

    if success
      Rails.logger.info "[VerizonCoverageCheckJob] Successfully checked Verizon coverage for contact #{contact.id}"
    else
      Rails.logger.warn "[VerizonCoverageCheckJob] Verizon coverage check returned false for contact #{contact.id}"
    end

  rescue StandardError => e
    Rails.logger.error "[VerizonCoverageCheckJob] Error checking coverage for contact #{contact.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
