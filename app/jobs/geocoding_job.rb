class GeocodingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: ->(executions) { (executions ** 4) + rand(30) }, attempts: 3

  # Don't retry if contact was deleted
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("[GeocodingJob] Contact not found: #{exception.message}")
  end

  def perform(contact_id)
    contact = Contact.find(contact_id)
    credentials = TwilioCredential.current

    return unless credentials&.enable_geocoding

    service = GeocodingService.new(contact)
    result = service.geocode!

    if result[:success]
      Rails.logger.info "Successfully geocoded contact #{contact_id}: #{result[:latitude]}, #{result[:longitude]}"
    else
      Rails.logger.warn "Geocoding failed for contact #{contact_id}: #{result[:error]}"
    end

    result
  rescue StandardError => e
    Rails.logger.error "Geocoding job failed for contact #{contact_id}: #{e.message}"
    raise
  end
end
