class LookupRequestJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient failures
  # Using custom polynomial backoff for better rate limit handling
  # Merged retry logic: custom wait time + error handling block
  retry_on Twilio::REST::RestError,
           wait: ->(executions) { (executions**4) + 15 + rand(10) }, # 16s, 31s, 96s, 271s... + jitter
           attempts: 5 do |job, exception|
    # Custom error handling for non-transient errors
    unless exception.code == 20_429 # Rate Limit - let retry mechanism handle it
      contact_id = job.arguments.first
      contact = Contact.find_by(id: contact_id)
      contact&.mark_failed!("Twilio API error after retries: #{exception.message}")
    end
  end

  # Retry on network errors (Faraday is loaded by twilio-ruby gem)
  # Use conditional check at class load time - this is safe because
  # if twilio-ruby is loaded, Faraday will be defined
  if defined?(Faraday::Error)
    retry_on Faraday::Error, wait: :exponentially_longer, attempts: 3 do |job, exception|
      contact_id = job.arguments.first
      contact = Contact.find_by(id: contact_id)
      contact&.mark_failed!("Network error after retries: #{exception.message}")
    end
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

      account_sid = app_creds&.dig(:account_sid)
      auth_token = app_creds&.dig(:auth_token)

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

      # Extract SIM Swap data
      sim_swap_data = lookup_result.sim_swap || {}
      sim_swap_last_date = sim_swap_data['last_sim_swap']&.dig('timestamp')
      sim_swap_swapped_period = sim_swap_data['last_sim_swap']&.dig('swapped_period')
      sim_swap_swapped_in_period = sim_swap_data['last_sim_swap']&.dig('swapped_in_period')

      # Extract Reassigned Number data
      reassigned_data = lookup_result.reassigned_number || {}
      reassigned_is_reassigned = reassigned_data['is_reassigned']
      reassigned_last_verified = reassigned_data['last_verified_date']

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

        # SIM Swap
        sim_swap_last_sim_swap_date: sim_swap_last_date,
        sim_swap_swapped_period: sim_swap_swapped_period,
        sim_swap_swapped_in_period: sim_swap_swapped_in_period,

        # Reassigned Number
        reassigned_number_is_reassigned: reassigned_is_reassigned,
        reassigned_number_last_verified_date: reassigned_last_verified,

        # Clear error code on success
        error_code: nil
      )

      # Mark as completed
      contact.mark_completed!

      Rails.logger.info("Successfully processed contact #{contact.id}: #{contact.formatted_phone_number}")

      # Call Real Phone Validation add-on if enabled
      perform_real_phone_validation(client, contact) if credentials&.enable_real_phone_validation

      # Call IceHook Scout add-on if enabled (for porting data)
      perform_icehook_scout(client, contact) if credentials&.enable_icehook_scout

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
      # Notify Slack on completion of a batch with atomic guard to prevent duplicates
      # Uses cache-based atomic fetch to ensure only one notification per batch cycle
      if Contact.pending.count == 0 && Contact.processing.count == 0
        Rails.cache.fetch('bulk_lookup_completion_notified', expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
          begin
            if defined?(SLACK_NOTIFIER) && SLACK_NOTIFIER.respond_to?(:ping)
              SLACK_NOTIFIER.ping "🎉 Bulk Lookup Complete! Total Processed: #{Contact.completed.count} | Failed: #{Contact.failed.count}"
            end
          rescue StandardError => e
            Rails.logger.warn("Slack notification failed: #{e.message}")
          end
          Time.current # Return a truthy value to cache
        end
      end
    end
  end

  private

  # Real Phone Validation (RPV) add-on integration
  # Add-on SID: XB41d31d7c7d90b5456ec9dc5403d08a00
  # Cost: $0.06 per request
  def perform_real_phone_validation(client, contact)
    # Get the unique name from credentials (configurable in admin)
    credentials = TwilioCredential.current
    rpv_unique_name = credentials&.rpv_unique_name.presence || 'real_phone_validation_rpv_turbo'

    Rails.logger.info("Starting RPV for contact #{contact.id} using add-on: #{rpv_unique_name}")

    # Call Lookup v1 with the Real Phone Validation add-on
    # NOTE: Marketplace add-ons only work with Lookup v1 API, not v2
    rpv_result = CircuitBreakerService.call(:twilio) do
      client.lookups
            .v1
            .phone_numbers(contact.raw_phone_number)
            .fetch(add_ons: [rpv_unique_name])
    end

    # Check if circuit breaker returned a fallback error hash
    if rpv_result.is_a?(Hash) && rpv_result[:circuit_open]
      Rails.logger.warn("RPV circuit open for contact #{contact.id}")
      return
    end

    # Extract add-on results
    add_ons = rpv_result.add_ons
    unless add_ons.present?
      Rails.logger.info("RPV response has no add_ons data for contact #{contact.id}")
      return
    end

    # The response key matches the unique name used in the request
    rpv_data = add_ons.dig('results', rpv_unique_name, 'result')
    unless rpv_data.present?
      Rails.logger.warn("RPV response missing data for contact #{contact.id}. Available keys: #{add_ons.dig('results')&.keys}")
      return
    end

    # Update contact with RPV results
    contact.update!(
      rpv_status: rpv_data['status'],
      rpv_error_text: rpv_data['error_text'],
      rpv_iscell: rpv_data['iscell'],
      rpv_cnam: rpv_data['cnam'],
      rpv_carrier: rpv_data['carrier']
    )

    Rails.logger.info("RPV completed for contact #{contact.id}: status=#{rpv_data['status']}")
  rescue Twilio::REST::RestError => e
    # Log RPV errors but don't fail the main lookup
    Rails.logger.warn("RPV error for contact #{contact.id}: #{e.message}")
  rescue StandardError => e
    Rails.logger.warn("RPV unexpected error for contact #{contact.id}: #{e.message}")
  end

  # IceHook Scout add-on integration (for porting data)
  # Add-on provides: ported status, LRN, operating company info
  def perform_icehook_scout(client, contact)
    Rails.logger.info("Starting IceHook Scout for contact #{contact.id}")

    # Call Lookup v1 with the IceHook Scout add-on
    # NOTE: Marketplace add-ons only work with Lookup v1 API, not v2
    scout_result = CircuitBreakerService.call(:twilio) do
      client.lookups
            .v1
            .phone_numbers(contact.raw_phone_number)
            .fetch(add_ons: ['icehook_scout'])
    end

    # Check if circuit breaker returned a fallback error hash
    if scout_result.is_a?(Hash) && scout_result[:circuit_open]
      Rails.logger.warn("Scout circuit open for contact #{contact.id}")
      return
    end

    # Extract add-on results
    add_ons = scout_result.add_ons
    unless add_ons.present?
      Rails.logger.info("Scout response has no add_ons data for contact #{contact.id}")
      return
    end

    scout_data = add_ons.dig('results', 'icehook_scout', 'result')
    unless scout_data.present?
      Rails.logger.warn("Scout response missing data for contact #{contact.id}. Available keys: #{add_ons.dig('results')&.keys}")
      return
    end

    # Parse ported as boolean (API returns "true"/"false" as strings)
    ported_value = scout_data['ported']
    ported_bool = case ported_value
                  when 'true', true then true
                  when 'false', false then false
                  else nil
                  end

    # Update contact with Scout results
    contact.update!(
      scout_ported: ported_bool,
      scout_location_routing_number: scout_data['location_routing_number'],
      scout_operating_company_name: scout_data['operating_company_name'],
      scout_operating_company_type: scout_data['operating_company_type']
    )

    Rails.logger.info("Scout completed for contact #{contact.id}: ported=#{ported_bool}")
  rescue Twilio::REST::RestError => e
    # Log Scout errors but don't fail the main lookup
    Rails.logger.warn("Scout error for contact #{contact.id}: #{e.message}")
  rescue StandardError => e
    Rails.logger.warn("Scout unexpected error for contact #{contact.id}: #{e.message}")
  end

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
