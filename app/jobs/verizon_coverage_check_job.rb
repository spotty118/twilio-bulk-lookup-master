class VerizonCoverageCheckJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(contact_id)
    contact = Contact.find(contact_id)

    Rails.logger.info "[VerizonCoverageCheckJob] Starting Verizon coverage check for contact #{contact.id}"

    service = VerizonCoverageService.new(contact)
    success = service.check_coverage

    if success
      Rails.logger.info "[VerizonCoverageCheckJob] Successfully checked Verizon coverage for contact #{contact.id}"
      
      # Trigger probability calculation if contact has coordinates
      if contact.latitude.present? && contact.longitude.present?
        VerizonProbabilityCalculationJob.perform_later(contact.id)
        Rails.logger.info "[VerizonCoverageCheckJob] Enqueued probability calculation for contact #{contact.id}"
      end
    else
      Rails.logger.warn "[VerizonCoverageCheckJob] Verizon coverage check returned false for contact #{contact.id}"
    end

  rescue => e
    Rails.logger.error "[VerizonCoverageCheckJob] Error checking coverage for contact #{contact.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
