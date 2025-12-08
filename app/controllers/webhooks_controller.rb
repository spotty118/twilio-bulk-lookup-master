class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_twilio_signature, only: [:twilio_sms_status, :twilio_voice_status, :twilio_trust_hub]

  # Twilio SMS Status Webhook
  def twilio_sms_status
    webhook = Webhook.create(
      source: 'twilio_sms',
      event_type: 'sms_status',
      external_id: params[:MessageSid],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    if webhook.persisted?
      # Process asynchronously
      WebhookProcessorJob.perform_later(webhook.id)
    else
      Rails.logger.error("Failed to create SMS webhook: #{webhook.errors.full_messages.join(', ')}")
    end

    # Always return 200 to prevent Twilio retry storms
    head :ok
  rescue StandardError => e
    Rails.logger.error("SMS webhook error: #{e.class} - #{e.message}")
    # Still return 200 to acknowledge receipt
    head :ok
  end

  # Twilio Voice Status Webhook
  def twilio_voice_status
    webhook = Webhook.create(
      source: 'twilio_voice',
      event_type: 'voice_status',
      external_id: params[:CallSid],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    if webhook.persisted?
      # Process asynchronously
      WebhookProcessorJob.perform_later(webhook.id)
    else
      Rails.logger.error("Failed to create Voice webhook: #{webhook.errors.full_messages.join(', ')}")
    end

    # Always return 200 to prevent Twilio retry storms
    head :ok
  rescue StandardError => e
    Rails.logger.error("Voice webhook error: #{e.class} - #{e.message}")
    # Still return 200 to acknowledge receipt
    head :ok
  end

  # Twilio Trust Hub Status Webhook
  def twilio_trust_hub
    webhook = Webhook.create(
      source: 'twilio_trust_hub',
      event_type: params[:StatusCallbackEvent] || 'status_update',
      external_id: params[:CustomerProfileSid],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    if webhook.persisted?
      # Process asynchronously
      WebhookProcessorJob.perform_later(webhook.id)
    else
      Rails.logger.error("Failed to create Trust Hub webhook: #{webhook.errors.full_messages.join(', ')}")
    end

    # Always return 200 to prevent Twilio retry storms
    head :ok
  rescue StandardError => e
    Rails.logger.error("Trust Hub webhook error: #{e.class} - #{e.message}")
    # Still return 200 to acknowledge receipt
    head :ok
  end

  # Generic webhook endpoint (for testing)
  def generic
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

  def verify_twilio_signature
    # Verify webhook is from Twilio using signature validation
    credentials = TwilioCredential.current
    return head :forbidden unless credentials

    validator = Twilio::Security::RequestValidator.new(credentials.auth_token)
    signature = request.headers['HTTP_X_TWILIO_SIGNATURE']
    url = request.original_url

    unless validator.validate(url, request.POST, signature)
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
