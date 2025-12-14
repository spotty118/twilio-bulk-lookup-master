class TrustHubEnrichmentJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient failures
  retry_on StandardError, wait: :exponentially_longer, attempts: 2 do |job, exception|
    contact_id = job.arguments.first
    contact = Contact.find_by(id: contact_id)
    Rails.logger.warn("Trust Hub enrichment failed for contact #{contact_id}: #{exception.message}")
  end

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("Contact not found for Trust Hub enrichment: #{exception.message}")
  end

  discard_on Twilio::REST::TwilioError do |job, exception|
    contact_id = job.arguments.first
    contact = Contact.find_by(id: contact_id)
    Rails.logger.error("Twilio API error for contact #{contact_id}: #{exception.message}")
    contact&.update(trust_hub_error: exception.message)
  end

  # Note: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)
    # Skip if already enriched and verified
    if contact.trust_hub_enriched? && contact.trust_hub_verified? && !needs_reverification?(contact)
      Rails.logger.info("Skipping contact #{contact.id}: already Trust Hub verified")
      return
    end

    # Skip if not a business
    unless contact.is_business?
      Rails.logger.info("Skipping contact #{contact.id}: not identified as business")
      return
    end

    # Skip if business enrichment not completed yet
    unless contact.business_enriched?
      Rails.logger.info("Skipping contact #{contact.id}: business enrichment not completed")
      return
    end

    # Check if Trust Hub enrichment is enabled
    credentials = TwilioCredential.current
    unless credentials&.enable_trust_hub
      Rails.logger.info("Trust Hub enrichment disabled in settings")
      return
    end

    # Perform enrichment
    Rails.logger.info("Enriching Trust Hub data for contact #{contact.id}")

    success = TrustHubService.enrich(contact)

    if success
      Rails.logger.info("Successfully enriched contact #{contact.id} with Trust Hub data")
      log_verification_status(contact)
    else
      Rails.logger.info("No Trust Hub data found for contact #{contact.id}")
      # Don't mark as enriched if no data found - allows future re-attempts
      # Contact will be eligible for re-enrichment on next lookup
    end

  rescue Twilio::REST::RestError => e
    Rails.logger.error("Twilio REST error enriching contact #{contact.id}: #{e.message}")
    contact.update(
      trust_hub_error: e.message,
      trust_hub_enriched: true,
      trust_hub_enriched_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Unexpected error enriching contact #{contact.id}: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  private

  def needs_reverification?(contact)
    # Re-verify if status is pending/rejected or if enriched more than 90 days ago
    return true if %w[pending-review twilio-rejected draft].include?(contact.trust_hub_status)
    return false unless contact.trust_hub_enriched_at

    contact.trust_hub_enriched_at < 90.days.ago
  end

  def log_verification_status(contact)
    status = contact.trust_hub_status
    score = contact.trust_hub_verification_score

    case status
    when 'twilio-approved', 'compliant'
      Rails.logger.info("Contact #{contact.id} is Trust Hub verified (score: #{score})")
    when 'pending-review', 'in-review'
      Rails.logger.info("Contact #{contact.id} Trust Hub verification pending (score: #{score})")
    when 'twilio-rejected', 'rejected'
      Rails.logger.warn("Contact #{contact.id} Trust Hub verification rejected (score: #{score})")
    when 'draft'
      Rails.logger.info("Contact #{contact.id} Trust Hub profile created as draft (score: #{score})")
    else
      Rails.logger.info("Contact #{contact.id} Trust Hub status: #{status} (score: #{score})")
    end
  end
end
