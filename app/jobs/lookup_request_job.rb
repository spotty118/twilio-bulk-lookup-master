class LookupRequestJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient failures
  # Retry configuration for transient failures
  # Using custom polynomial backoff for better rate limit handling
  retry_on Twilio::REST::RestError, attempts: 5 do |job, exception|
    # Custom error handling block
    if exception.code == 20_429 # Rate Limit
      # Don't mark failed, just let it retry with the custom wait below
    else
      contact_id = job.arguments.first
      contact = Contact.find_by(id: contact_id)
      contact&.mark_failed!("Twilio API error after retries: #{exception.message}")
    end
  end

  # Custom retry wait logic
  # Return wait time in seconds based on execution count
  retry_on Twilio::REST::RestError,
           wait: ->(executions) { (executions**4) + 15 + rand(10) }, # 16s, 31s, 96s, 271s... + jitter
           attempts: 5

  # Retry on network errors (Faraday is loaded by twilio-ruby gem)
  # Explicit rescue is safer than conditional StandardError filtering
  begin
    retry_on Faraday::Error, wait: :exponentially_longer, attempts: 3 do |job, exception|
      contact_id = job.arguments.first
      contact = Contact.find_by(id: contact_id)
      contact&.mark_failed!("Network error after retries: #{exception.message}")
    end
  rescue NameError
    # Faraday not loaded - skip network retry configuration
    Rails.logger.debug('Faraday::Error not defined, network retry logic disabled')
  end

  # Don't retry on permanent failures
  discard_on ActiveRecord::RecordNotFound do |_job, exception|
    Rails.logger.error("Contact not found: #{exception.message}")
  end

  # NOTE: This job expects a contact_id (Integer), not a Contact object
  # This follows Sidekiq best practice of passing IDs to avoid serialization issues
  def perform(contact_id)
    contact = Contact.find(contact_id)

    # Idempotency check: skip if already completed
    if contact.lookup_completed?
      Rails.logger.info("Skipping contact #{contact.id}: already completed")
      return
    end

    # Atomic status transition to prevent race conditions
    # Use pessimistic locking to ensure only one job processes this contact
    updated = contact.with_lock do
      if %w[pending failed].include?(contact.status)
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
      app_creds = defined?(AppConfig) ? AppConfig.twilio_credentials : nil

      # Follow AppConfig priority (env/credentials before DB) and treat blanks as missing
      account_sid = app_creds&.dig(:account_sid)&.presence || credentials&.account_sid&.presence
      auth_token = app_creds&.dig(:auth_token)&.presence || credentials&.auth_token&.presence

      unless account_sid.present? && auth_token.present?
        contact.mark_failed!('No Twilio credentials configured')
        return
      end

      # Initialize Twilio client
      client = Twilio::REST::Client.new(account_sid, auth_token)

      # Perform Twilio Lookup API v2 with configured data packages
      # Build fields parameter from enabled packages
      fields = credentials&.data_packages

      # Wrap Twilio API call with circuit breaker to prevent cascade failures
      # when Twilio is degraded or experiencing issues
      lookup_result = CircuitBreakerService.call(:twilio) do
        if fields.present?
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
      end

      # Check if circuit breaker returned a fallback error hash
      if lookup_result.is_a?(Hash) && lookup_result[:circuit_open]
        contact.mark_failed!('Twilio API temporarily unavailable (circuit open)')
        return
      end

      # Extract basic validation data
      phone_number = lookup_result.phone_number
      valid = lookup_result.valid
      validation_errors = lookup_result.validation_errors || []
      country_code = lookup_result.country_code
      calling_country_code = lookup_result.calling_country_code
      # national_format unused

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
      sms_risk_score = sms_risk_data['sms_pumping_risk_score']&.to_i

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
        phone_valid: valid,
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

      # Enqueue enrichment coordinator to fan-out enrichment jobs in parallel
      # Enqueue enrichment coordinator to fan-out enrichment jobs in parallel
      EnrichmentCoordinatorJob.perform_later(contact.id)
    rescue Twilio::REST::RestError => e
      handle_twilio_error(contact, e)
      # handle_twilio_error will re-raise for transient errors only
    rescue StandardError => e
      # Keep broad StandardError rescue at outermost level to catch any unexpected errors
      # and prevent silent failures. This ensures all errors are logged and job state is updated.

      # Network errors from twilio-ruby/Faraday should be retried (if configured)
      if defined?(Faraday::Error) && e.is_a?(Faraday::Error)
        Rails.logger.warn("Network error for contact #{contact.id}: #{e.class} - #{e.message}")
        contact.mark_failed!("Network error: #{e.message}")
        raise
      end

      # Unexpected errors - log and mark as failed but don't retry
      Rails.logger.error("Unexpected error for contact #{contact.id}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      contact.mark_failed!("Unexpected error: #{e.message}")
    ensure
      # Notify Slack on completion of a batch (simple heuristic: if this was the last pending contact)
      # Note: In a high-concurrency environment, this count might be slightly off due to race conditions,
      # but it's sufficient for a "job done" notification. A more robust approach would be a BatchJob tracker.
      if Contact.pending.count == 0 && Contact.processing.count == 0
        SLACK_NOTIFIER.ping "🎉 Bulk Lookup Complete! Total Processed: #{Contact.completed.count} | Failed: #{Contact.failed.count}"
      end
    end
  end

  private

  def handle_twilio_error(contact, error)
    error_code = error.code
    error_message = error.message

    Rails.logger.warn("Twilio error for contact #{contact.id}: [#{error_code}] #{error_message}")

    # Determine if error is permanent or transient
    case error_code
    when 20_404 # Resource not found - invalid number
      contact.mark_failed!("Invalid phone number: #{error_message}")
      # Don't re-raise for permanent failures - prevent retries

    when 20_003, 20_005 # Authentication errors
      contact.mark_failed!("Authentication error: #{error_message}")
      # Don't re-raise for auth failures - will fail for all contacts

    when 20_429 # Rate limit exceeded
      contact.mark_failed!("Rate limit exceeded: #{error_message}")
      Rails.logger.warn('Rate limit exceeded, will retry')
      # Let retry mechanism handle this by re-raising
      raise error

    when 21_211, 21_212, 21_213, 21_214, 21_215, 21_216, 21_217, 21_218, 21_219 # Invalid number formats
      contact.mark_failed!("Invalid number format: #{error_message}")
      # Don't re-raise for permanent failures - prevent retries

    else
      # Unknown error - allow retry by re-raising
      contact.mark_failed!("Twilio error #{error_code}: #{error_message}")
      Rails.logger.warn("Unknown Twilio error #{error_code}, will retry")
      raise error
    end
  end
end
