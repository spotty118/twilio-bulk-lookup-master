class LookupRequestJob < ApplicationJob
  queue_as :default
  
  # Retry configuration for transient failures
  retry_on Twilio::REST::RestError, wait: :exponentially_longer, attempts: 3 do |job, exception|
    contact = job.arguments.first
    contact.mark_failed!("Twilio API error after retries: #{exception.message}")
  end
  
  # Retry on network errors (Faraday is loaded by twilio-ruby gem)
  retry_on StandardError, wait: :exponentially_longer, attempts: 3, if: ->(error) {
    error.is_a?(Faraday::Error) rescue false
  } do |job, exception|
    contact = job.arguments.first
    contact.mark_failed!("Network error after retries: #{exception.message}")
  end
  
  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("Contact not found: #{exception.message}")
  end

  def perform(contact)
    # Idempotency check: skip if already completed
    if contact.lookup_completed?
      Rails.logger.info("Skipping contact #{contact.id}: already completed")
      return
    end
    
    # Mark as processing to prevent duplicate processing
    return unless contact.status == 'pending' || contact.status == 'failed'
    contact.mark_processing!
    
    begin
      # Use cached credentials to avoid N+1 queries
      credentials = TwilioCredential.current
      
      unless credentials
        contact.mark_failed!('No Twilio credentials configured')
        return
      end
      
      # Initialize Twilio client
      client = Twilio::REST::Client.new(credentials.account_sid, credentials.auth_token)
      
      # Perform lookup
      lookup_result = client.lookups
                           .v1
                           .phone_numbers(contact.raw_phone_number)
                           .fetch(type: ['carrier'])
      
      # Extract carrier information safely
      carrier = lookup_result.carrier || {}
      
      # Update contact with results
      contact.update!(
        formatted_phone_number: lookup_result.phone_number,
        mobile_network_code: carrier['mobile_network_code'],
        error_code: carrier['error_code'],
        mobile_country_code: carrier['mobile_country_code'],
        carrier_name: carrier['name'],
        device_type: carrier['type']
      )
      
      # Mark as completed
      contact.mark_completed!
      
      Rails.logger.info("Successfully processed contact #{contact.id}: #{contact.formatted_phone_number}")
      
    rescue Twilio::REST::RestError => e
      handle_twilio_error(contact, e)
      raise # Allow retry mechanism to work
      
    rescue StandardError => e
      # Unexpected errors
      Rails.logger.error("Unexpected error for contact #{contact.id}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      contact.mark_failed!("Unexpected error: #{e.message}")
    end
  end
  
  private
  
  def handle_twilio_error(contact, error)
    error_code = error.code
    error_message = error.message
    
    Rails.logger.warn("Twilio error for contact #{contact.id}: [#{error_code}] #{error_message}")
    
    # Determine if error is permanent or transient
    case error_code
    when 20404 # Resource not found - invalid number
      contact.mark_failed!("Invalid phone number: #{error_message}")
      raise Twilio::REST::RestError, 'Permanent failure' # Don't retry
      
    when 20003, 20005 # Authentication errors
      contact.mark_failed!("Authentication error: #{error_message}")
      raise Twilio::REST::RestError, 'Auth failure' # Don't retry (will fail for all)
      
    when 20429 # Rate limit exceeded
      Rails.logger.warn("Rate limit exceeded, will retry")
      # Let retry mechanism handle this
      
    when 21211, 21212, 21213, 21214, 21215, 21216, 21217, 21218, 21219 # Invalid number formats
      contact.mark_failed!("Invalid number format: #{error_message}")
      raise Twilio::REST::RestError, 'Permanent failure' # Don't retry
      
    else
      # Unknown error - allow retry
      Rails.logger.warn("Unknown Twilio error #{error_code}, will retry")
    end
  end
end
