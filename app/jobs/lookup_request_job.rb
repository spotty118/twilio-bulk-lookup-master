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

    # Atomic status transition to prevent race conditions
    # Use pessimistic locking to ensure only one job processes this contact
    updated = contact.with_lock do
      if contact.status == 'pending' || contact.status == 'failed'
        contact.mark_processing!
        true
      else
        false
      end
    end

    unless updated
      Rails.logger.info("Skipping contact #{contact.id}: already being processed (status: #{contact.status})")
      return
    end
    
    begin
      # Use cached credentials to avoid N+1 queries
      credentials = TwilioCredential.current
      
      unless credentials
        contact.mark_failed!('No Twilio credentials configured')
        return
      end
      
      # Initialize Twilio client
      client = Twilio::REST::Client.new(credentials.account_sid, credentials.auth_token)
      
      # Perform Twilio Lookup API v2 with configured data packages
      # Build fields parameter from enabled packages
      fields = credentials.data_packages
      
      lookup_result = if fields.present?
                        client.lookups
                              .v2
                              .phone_numbers(contact.raw_phone_number)
                              .fetch(fields: fields)
                      else
                        # Basic lookup if no packages enabled
                        client.lookups
                              .v2
                              .phone_numbers(contact.raw_phone_number)
                              .fetch
                      end
      
      # Extract basic validation data
      phone_number = lookup_result.phone_number
      valid = lookup_result.valid
      validation_errors = lookup_result.validation_errors || []
      country_code = lookup_result.country_code
      calling_country_code = lookup_result.calling_country_code
      national_format = lookup_result.national_format
      
      # Extract Line Type Intelligence data
      line_type_data = lookup_result.line_type_intelligence || {}
      line_type = line_type_data['type']
      line_type_confidence = line_type_data['confidence']
      carrier_name = line_type_data['carrier_name']
      mobile_network_code = line_type_data['mobile_network_code']
      mobile_country_code = line_type_data['mobile_country_code']
      
      # Extract Caller Name (CNAM) data - US only
      caller_name_data = lookup_result.caller_name || {}
      caller_name = caller_name_data['caller_name']
      caller_type = caller_name_data['caller_type']
      
      # Extract SMS Pumping Risk data
      sms_risk_data = lookup_result.sms_pumping_risk || {}
      sms_risk_score = sms_risk_data['sms_pumping_risk_ratio']&.to_i
      
      # Determine risk level based on score
      sms_risk_level = case sms_risk_score
                       when 0..25 then 'low'
                       when 26..74 then 'medium'
                       when 75..100 then 'high'
                       else nil
                       end
      
      sms_carrier_risk = sms_risk_data['carrier_risk_category']
      sms_number_blocked = sms_risk_data['number_blocked']
      
      # Update contact with all v2 results
      contact.update!(
        # Basic validation
        formatted_phone_number: phone_number,
        valid: valid,
        validation_errors: validation_errors,
        country_code: country_code,
        calling_country_code: calling_country_code,
        
        # Line Type Intelligence
        line_type: line_type,
        line_type_confidence: line_type_confidence,
        carrier_name: carrier_name,
        mobile_network_code: mobile_network_code,
        mobile_country_code: mobile_country_code,
        device_type: line_type, # Keep device_type for backwards compatibility
        
        # Caller Name (CNAM)
        caller_name: caller_name,
        caller_type: caller_type,
        
        # SMS Pumping Risk
        sms_pumping_risk_score: sms_risk_score,
        sms_pumping_risk_level: sms_risk_level,
        sms_pumping_carrier_risk_category: sms_carrier_risk,
        sms_pumping_number_blocked: sms_number_blocked,
        
        # Clear error code on success
        error_code: nil
      )
      
      # Mark as completed
      contact.mark_completed!
      
      Rails.logger.info("Successfully processed contact #{contact.id}: #{contact.formatted_phone_number}")

      # Queue business enrichment if enabled
      credentials = TwilioCredential.current
      if credentials&.enable_business_enrichment
        BusinessEnrichmentJob.perform_later(contact)
      end

      # Queue address enrichment for consumers if enabled
      if credentials&.enable_address_enrichment && contact.consumer?
        AddressEnrichmentJob.perform_later(contact)
      end
      
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
