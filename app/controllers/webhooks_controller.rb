class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_twilio_signature, only: [:twilio_sms_status, :twilio_voice_status, :twilio_trust_hub]

  # Twilio SMS Status Webhook
  def twilio_sms_status
    webhook = Webhook.create!(
      source: 'twilio_sms',
      event_type: 'sms_status',
      external_id: params[:MessageSid],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    # Process asynchronously
    WebhookProcessorJob.perform_later(webhook.id)

    head :ok
  end

  # Twilio Voice Status Webhook
  def twilio_voice_status
    webhook = Webhook.create!(
      source: 'twilio_voice',
      event_type: 'voice_status',
      external_id: params[:CallSid],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    # Process asynchronously
    WebhookProcessorJob.perform_later(webhook.id)

    head :ok
  end

  # Twilio Trust Hub Status Webhook
  def twilio_trust_hub
    webhook = Webhook.create!(
      source: 'twilio_trust_hub',
      event_type: params[:StatusCallbackEvent] || 'status_update',
      external_id: params[:CustomerProfileSid],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    # Process asynchronously
    WebhookProcessorJob.perform_later(webhook.id)

    head :ok
  end

  # Generic webhook endpoint (for testing)
  def generic
    webhook = Webhook.create!(
      source: params[:source] || 'unknown',
      event_type: params[:event_type] || 'unknown',
      external_id: params[:external_id],
      payload: webhook_params,
      headers: extract_headers,
      status: 'pending',
      received_at: Time.current
    )

    WebhookProcessorJob.perform_later(webhook.id)

    render json: { success: true, webhook_id: webhook.id }
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
  rescue => e
    Rails.logger.error "Signature verification error: #{e.message}"
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
