class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_twilio_signature, only: %i[twilio_sms_status twilio_voice_status twilio_trust_hub]

  # Twilio SMS Status Webhook
  def twilio_sms_status
    # Use find_or_initialize_by to detect if it's a new record
    webhook = Webhook.find_or_initialize_by(
      source: 'twilio_sms',
      external_id: params[:MessageSid]
    )

    if webhook.new_record?
      webhook.event_type = 'sms_status'
      webhook.payload = webhook_params
      webhook.headers = extract_headers
      webhook.status = 'pending'
      webhook.received_at = Time.current

      if webhook.save
        WebhookProcessorJob.perform_later(webhook.id)
      else
        Rails.logger.error("Failed to create SMS webhook: #{webhook.errors.full_messages.join(', ')}")
      end
    elsif webhook.status != 'pending'
      Rails.logger.info("Duplicate SMS webhook rejected (already #{webhook.status}): #{params[:MessageSid]}")
    else
      # Duplicate request for pending webhook - ignore (idempotent)
      Rails.logger.info("Duplicate SMS webhook ignored (pending): #{params[:MessageSid]}")
    end

    head :ok
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.warn("Duplicate SMS webhook (race condition): #{params[:MessageSid]}")
    head :ok
  rescue StandardError => e
    Rails.logger.error("SMS webhook error: #{e.class} - #{e.message}")
    head :ok
  end

  # Twilio Voice Status Webhook
  def twilio_voice_status
    webhook = Webhook.find_or_initialize_by(
      source: 'twilio_voice',
      external_id: params[:CallSid]
    )

    if webhook.new_record?
      webhook.event_type = 'voice_status'
      webhook.payload = webhook_params
      webhook.headers = extract_headers
      webhook.status = 'pending'
      webhook.received_at = Time.current

      if webhook.save
        WebhookProcessorJob.perform_later(webhook.id)
      else
        Rails.logger.error("Failed to create Voice webhook: #{webhook.errors.full_messages.join(', ')}")
      end
    elsif webhook.status != 'pending'
      Rails.logger.info("Duplicate Voice webhook rejected (already #{webhook.status}): #{params[:CallSid]}")
    else
      Rails.logger.info("Duplicate Voice webhook ignored (pending): #{params[:CallSid]}")
    end

    head :ok
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.warn("Duplicate Voice webhook (race condition): #{params[:CallSid]}")
    head :ok
  rescue StandardError => e
    Rails.logger.error("Voice webhook error: #{e.class} - #{e.message}")
    head :ok
  end

  # Twilio Trust Hub Status Webhook
  def twilio_trust_hub
    webhook = Webhook.find_or_initialize_by(
      source: 'twilio_trust_hub',
      external_id: params[:CustomerProfileSid]
    )

    if webhook.new_record?
      webhook.event_type = params[:StatusCallbackEvent] || 'status_update'
      webhook.payload = webhook_params
      webhook.headers = extract_headers
      webhook.status = 'pending'
      webhook.received_at = Time.current

      if webhook.save
        WebhookProcessorJob.perform_later(webhook.id)
      else
        Rails.logger.error("Failed to create Trust Hub webhook: #{webhook.errors.full_messages.join(', ')}")
      end
    elsif webhook.status != 'pending'
      Rails.logger.info("Duplicate Trust Hub webhook rejected (already #{webhook.status}): #{params[:CustomerProfileSid]}")
    else
      Rails.logger.info("Duplicate Trust Hub webhook ignored (pending): #{params[:CustomerProfileSid]}")
    end

    head :ok
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.warn("Duplicate Trust Hub webhook (race condition): #{params[:CustomerProfileSid]}")
    head :ok
  rescue StandardError => e
    Rails.logger.error("Trust Hub webhook error: #{e.class} - #{e.message}")
    head :ok
  end

  # Generic webhook endpoint (requires API key authentication)
  # Usage: POST /webhooks/receive with Authorization: Bearer <api_token>
  def generic
    # Verify API key authentication
    unless authenticate_webhook_api_key
      render json: { success: false, error: 'Unauthorized: Invalid or missing API key' }, status: :unauthorized
      return
    end

    webhook = Webhook.create(
      source: params[:source] || 'unknown',
      event_type: params[:event_type] || 'unknown',
      external_id: params[:external_id],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    if webhook.persisted?
      WebhookProcessorJob.perform_later(webhook.id)
      render json: { success: true, webhook_id: webhook.id }
    else
      render json: { success: false, errors: webhook.errors.full_messages }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("Generic webhook error: #{e.class} - #{e.message}")
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  # Authenticate generic webhook using API key from Authorization header
  def authenticate_webhook_api_key
    auth_header = request.headers['Authorization']
    return false unless auth_header.present?

    # Extract Bearer token
    token = auth_header.split(' ').last
    return false unless token.present?

    # Validate against admin user API tokens
    AdminUser.exists?(api_token: token)
  end

  def verify_twilio_signature
    # Verify webhook is from Twilio using signature validation
    app_creds = defined?(AppConfig) ? AppConfig.twilio_credentials : nil
    auth_token = app_creds&.dig(:auth_token) || TwilioCredential.current&.auth_token
    return head :forbidden unless auth_token.present?

    validator = Twilio::Security::RequestValidator.new(auth_token)
    signature = request.headers['HTTP_X_TWILIO_SIGNATURE']
    url = request.original_url

    # Combine POST parameters and query parameters for signature validation
    # Twilio may send data in either or both locations
    params_for_validation = request.POST.merge(request.query_parameters)

    unless validator.validate(url, params_for_validation, signature)
      Rails.logger.warn "Invalid Twilio signature for webhook: #{request.path}"
      head :forbidden
    end
  rescue ArgumentError, TypeError => e
    # Handle invalid auth token or malformed signature
    Rails.logger.error "Signature verification error: #{e.class} - #{e.message}"
    head :forbidden
  rescue StandardError => e
    # Unexpected errors during validation
    Rails.logger.error "Unexpected signature verification error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    head :forbidden
  end

  def webhook_params
    params.except(:controller, :action, :format).to_unsafe_h
  end

  def extract_headers
    {
      'User-Agent' => request.headers['HTTP_USER_AGENT'],
      'X-Twilio-Signature' => request.headers['HTTP_X_TWILIO_SIGNATURE'],
      'Content-Type' => request.headers['CONTENT_TYPE']
    }
  end
end
