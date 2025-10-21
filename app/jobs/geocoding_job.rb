class GeocodingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

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
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Contact not found for geocoding: #{contact_id}"
  rescue => e
    Rails.logger.error "Geocoding job failed for contact #{contact_id}: #{e.message}"
    raise
  end
end
