require 'twilio-ruby'

class MessagingService
  attr_reader :contact

  def initialize(contact)
    @contact = contact
    @credentials = TwilioCredential.current
    @client = initialize_twilio_client
  end

  # Send SMS message
  def send_sms(message_body, options = {})
    return { success: false, error: 'SMS messaging not enabled' } unless @credentials&.enable_sms_messaging
    return { success: false, error: 'No Twilio phone number configured' } unless @credentials.twilio_phone_number.present?
    return { success: false, error: 'Contact has opted out of SMS' } if @contact.sms_opt_out
    return { success: false, error: 'Invalid phone number' } unless @contact.formatted_phone_number.present?

    # Check rate limits
    rate_limit_check = check_sms_rate_limit
    return rate_limit_check unless rate_limit_check[:success]

    start_time = Time.current

    begin
      message = @client.messages.create(
        from: @credentials.twilio_phone_number,
        to: @contact.formatted_phone_number,
        body: message_body,
        status_callback: options[:status_callback] || build_status_callback_url('sms')
      )

      # Update contact
      @contact.increment!(:sms_sent_count)
      @contact.update!(
        sms_last_sent_at: Time.current,
        last_engagement_at: Time.current
      )

      # Log API usage
      log_api_usage(
        service: 'sms_send',
        status: 'success',
        response_time_ms: ((Time.current - start_time) * 1000).to_i,
        request_params: { to: @contact.formatted_phone_number, body: message_body },
        response_data: { message_sid: message.sid, status: message.status }
      )

      {
        success: true,
        message_sid: message.sid,
        status: message.status,
        to: message.to,
        from: message.from
      }
    rescue Twilio::REST::TwilioError => e
      Rails.logger.error "SMS send error for contact #{@contact.id}: #{e.message}"

      @contact.increment!(:sms_failed_count)

      log_api_usage(
        service: 'sms_send',
        status: 'failed',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: e.message }
    end
  end

  # Send SMS using template
  def send_sms_from_template(template_type: 'intro', options: {})
    template = case template_type
    when 'intro'
      @credentials.sms_intro_template
    when 'follow_up'
      @credentials.sms_follow_up_template
    else
      nil
    end

    return { success: false, error: "No template found for type: #{template_type}" } unless template.present?

    # Replace variables in template
    message_body = interpolate_template(template)

    send_sms(message_body, options)
  end

  # Send SMS with AI-generated content
  def send_ai_generated_sms(message_type: 'intro', options: {})
    llm_service = MultiLlmService.new
    result = llm_service.generate_outreach_message(@contact, message_type: message_type, options: options)

    if result[:success]
      send_sms(result[:response], options)
    else
      result
    end
  end

  # Make voice call
  def make_voice_call(options = {})
    return { success: false, error: 'Voice messaging not enabled' } unless @credentials&.enable_voice_messaging
    return { success: false, error: 'No Twilio phone number configured' } unless @credentials.twilio_phone_number.present?
    return { success: false, error: 'Contact has opted out of voice calls' } if @contact.voice_opt_out
    return { success: false, error: 'Invalid phone number' } unless @contact.formatted_phone_number.present?
    return { success: false, error: 'No voice webhook URL configured' } unless @credentials.voice_call_webhook_url.present?

    # Check rate limits
    rate_limit_check = check_voice_rate_limit
    return rate_limit_check unless rate_limit_check[:success]

    start_time = Time.current

    begin
      call = @client.calls.create(
        from: @credentials.twilio_phone_number,
        to: @contact.formatted_phone_number,
        url: @credentials.voice_call_webhook_url,
        status_callback: options[:status_callback] || build_status_callback_url('voice'),
        record: @credentials.voice_recording_enabled || false
      )

      # Update contact
      @contact.increment!(:voice_calls_count)
      @contact.update!(
        voice_last_called_at: Time.current,
        last_engagement_at: Time.current
      )

      # Log API usage
      log_api_usage(
        service: 'voice_call',
        status: 'success',
        response_time_ms: ((Time.current - start_time) * 1000).to_i,
        request_params: { to: @contact.formatted_phone_number },
        response_data: { call_sid: call.sid, status: call.status }
      )

      {
        success: true,
        call_sid: call.sid,
        status: call.status,
        to: call.to,
        from: call.from
      }
    rescue Twilio::REST::TwilioError => e
      Rails.logger.error "Voice call error for contact #{@contact.id}: #{e.message}"

      log_api_usage(
        service: 'voice_call',
        status: 'failed',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: e.message }
    end
  end

  # Batch SMS sending
  def self.send_bulk_sms(contacts, message_body, options = {})
    results = {
      total: contacts.count,
      sent: 0,
      failed: 0,
      rate_limited: 0,
      errors: []
    }

    contacts.each do |contact|
      service = new(contact)
      result = service.send_sms(message_body, options)

      if result[:success]
        results[:sent] += 1
      elsif result[:error]&.include?('rate limit')
        results[:rate_limited] += 1
        results[:errors] << { contact_id: contact.id, error: result[:error] }
        break # Stop if rate limited
      else
        results[:failed] += 1
        results[:errors] << { contact_id: contact.id, error: result[:error] }
      end

      # Small delay between messages
      sleep(0.1)
    end

    results
  end

  # Handle opt-out request
  def opt_out_sms!
    @contact.update!(
      sms_opt_out: true,
      sms_opt_out_at: Time.current
    )

    Rails.logger.info "Contact #{@contact.id} opted out of SMS"
    { success: true, message: 'Contact opted out of SMS' }
  end

  def opt_out_voice!
    @contact.update!(voice_opt_out: true)
    Rails.logger.info "Contact #{@contact.id} opted out of voice calls"
    { success: true, message: 'Contact opted out of voice calls' }
  end

  private

  def initialize_twilio_client
    return nil unless @credentials
    Twilio::REST::Client.new(@credentials.account_sid, @credentials.auth_token)
  end

  def check_sms_rate_limit
    max_per_hour = @credentials.max_sms_per_hour || 100
    sent_this_hour = Contact.where('sms_last_sent_at >= ?', 1.hour.ago).count

    if sent_this_hour >= max_per_hour
      { success: false, error: "Rate limit exceeded: #{sent_this_hour}/#{max_per_hour} SMS sent in the last hour" }
    else
      { success: true }
    end
  end

  def check_voice_rate_limit
    max_per_hour = @credentials.max_calls_per_hour || 50
    calls_this_hour = Contact.where('voice_last_called_at >= ?', 1.hour.ago).count

    if calls_this_hour >= max_per_hour
      { success: false, error: "Rate limit exceeded: #{calls_this_hour}/#{max_per_hour} calls in the last hour" }
    else
      { success: true }
    end
  end

  def build_status_callback_url(type)
    # This would be your Rails app's webhook endpoint
    # For example: https://yourdomain.com/webhooks/twilio/sms_status
    if defined?(Rails) && Rails.application
      case type
      when 'sms'
        "#{Rails.application.config.action_mailer.default_url_options[:host]}/webhooks/twilio/sms_status"
      when 'voice'
        "#{Rails.application.config.action_mailer.default_url_options[:host]}/webhooks/twilio/voice_status"
      end
    end
  end

  def interpolate_template(template)
    template.gsub(/\{\{(\w+)\}\}/) do |match|
      field = $1
      @contact.send(field) rescue match
    end
  end

  def log_api_usage(params)
    ApiUsageLog.log_api_call(
      contact_id: @contact.id,
      provider: 'twilio',
      service: params[:service],
      status: params[:status],
      response_time_ms: params[:response_time_ms],
      request_params: params[:request_params],
      response_data: params[:response_data],
      error_message: params[:error_message],
      requested_at: Time.current
    )
  end
end
