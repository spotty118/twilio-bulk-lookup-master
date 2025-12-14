class Webhook < ApplicationRecord
  belongs_to :contact, optional: true

  # Callbacks
  before_validation :generate_idempotency_key, on: :create

  # Validations
  validates :source, :event_type, :received_at, presence: true
  validates :status, inclusion: { in: %w[pending processing processed failed] }
  validates :idempotency_key, uniqueness: true, allow_nil: false

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :processed, -> { where(status: 'processed') }
  scope :failed, -> { where(status: 'failed') }
  scope :unprocessed, -> { where(status: %w[pending failed]) }
  scope :recent, -> { where('received_at >= ?', 24.hours.ago) }

  # Source scopes
  scope :trust_hub, -> { where(source: 'twilio_trust_hub') }
  scope :sms_status, -> { where(source: 'twilio_sms') }
  scope :voice_status, -> { where(source: 'twilio_voice') }

  # Processing
  def process!
    # Use pessimistic locking to prevent race conditions (TOCTOU vulnerability)
    # Multiple Sidekiq workers could attempt to process the same webhook simultaneously
    with_lock do
      return if status == 'processed'

      # Wrap in transaction to ensure atomicity of multi-step updates
      transaction do
        update!(status: 'processing')

        begin
          case source
          when 'twilio_trust_hub'
            process_trust_hub_webhook
          when 'twilio_sms'
            process_sms_webhook
          when 'twilio_voice'
            process_voice_webhook
          else
            raise "Unknown webhook source: #{source}"
          end

          update!(
            status: 'processed',
            processed_at: Time.current
          )
        rescue StandardError => e
          update!(
            status: 'failed',
            processing_error: e.message,
            retry_count: (retry_count || 0) + 1
          )
          Rails.logger.error "Webhook processing failed: #{e.message}"
          raise
        end
      end
    end
  end

  # Retry failed webhooks
  def self.retry_failed!
    failed.where('retry_count < ?', 3).find_each do |webhook|
      webhook.process!
    end
  end

  # Auto-process pending webhooks (called from background job)
  def self.process_pending!
    pending.order(received_at: :asc).limit(100).find_each do |webhook|
      webhook.process!
    rescue StandardError => e
      Rails.logger.error "Failed to process webhook #{webhook.id}: #{e.message}"
    end
  end

  # Class method to get ransackable attributes
  def self.ransackable_attributes(auth_object = nil)
    ["source", "event_type", "status", "received_at", "processed_at",
     "created_at", "updated_at", "contact_id", "external_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["contact"]
  end

  private

  def generate_idempotency_key
    # Generate unique key from source + external_id for idempotency protection
    # This prevents replay attacks where same webhook is POSTed multiple times
    return if idempotency_key.present?

    if external_id.present?
      self.idempotency_key = "#{source}:#{external_id}"
    else
      # Fallback: Use hash of payload if external_id is missing
      # This handles edge cases where Twilio doesn't provide an ID
      payload_hash = Digest::SHA256.hexdigest(payload.to_json.to_s)[0..31]
      self.idempotency_key = "#{source}:hash:#{payload_hash}"
      Rails.logger.warn("Webhook created without external_id, using payload hash for idempotency")
    end
  end

  def process_trust_hub_webhook
    # Extract Trust Hub data from payload
    # Handle both snake_case (from our code) and PascalCase (from Twilio webhooks)
    trust_hub_sid = payload['customer_profile_sid'] || payload['CustomerProfileSid'] || external_id
    status = payload['status'] || payload['Status']

    return unless trust_hub_sid.present?

    # Find contact by Trust Hub SID
    contact = Contact.find_by(trust_hub_customer_profile_sid: trust_hub_sid)

    if contact
      # Update Trust Hub status
      contact.update!(
        trust_hub_status: status,
        trust_hub_verified: ['twilio-approved', 'compliant'].include?(status),
        trust_hub_verification_score: calculate_trust_hub_score(status),
        trust_hub_enriched_at: Time.current
      )

      # Associate webhook with contact
      update!(contact_id: contact.id)

      Rails.logger.info "Trust Hub webhook processed for contact #{contact.id}: #{status}"
    else
      Rails.logger.warn "No contact found for Trust Hub SID: #{trust_hub_sid}"
    end
  end

  def process_sms_webhook
    # Extract SMS status from payload
    message_sid = payload['MessageSid'] || external_id
    message_status = payload['MessageStatus']
    to_number = payload['To']

    return unless to_number.present?

    # Find contact by phone number (optimized single query with OR condition)
    contact = Contact.where('formatted_phone_number = ? OR raw_phone_number = ?', to_number, to_number).first

    if contact
      # Update SMS tracking
      case message_status
      when 'delivered'
        contact.increment!(:sms_delivered_count)
      when 'failed', 'undelivered'
        contact.increment!(:sms_failed_count)
      end

      contact.update!(last_engagement_at: Time.current)
      update!(contact_id: contact.id)

      Rails.logger.info "SMS webhook processed for contact #{contact.id}: #{message_status}"
    end
  end

  def process_voice_webhook
    # Extract voice call status from payload
    call_sid = payload['CallSid'] || external_id
    call_status = payload['CallStatus']
    to_number = payload['To']

    return unless to_number.present?

    # Find contact by phone number (optimized single query with OR condition)
    contact = Contact.where('formatted_phone_number = ? OR raw_phone_number = ?', to_number, to_number).first

    if contact
      # Update voice tracking
      case call_status
      when 'completed'
        if payload['AnsweredBy'] == 'human'
          contact.increment!(:voice_answered_count)
        else
          contact.increment!(:voice_voicemail_count)
        end
      end

      contact.update!(
        voice_last_called_at: Time.current,
        last_engagement_at: Time.current
      )
      update!(contact_id: contact.id)

      Rails.logger.info "Voice webhook processed for contact #{contact.id}: #{call_status}"
    end
  end

  def calculate_trust_hub_score(status)
    case status
    when 'draft' then 10
    when 'pending-review' then 50
    when 'in-review' then 60
    when 'twilio-rejected', 'rejected' then 0
    when 'twilio-approved' then 100
    when 'compliant' then 95
    else 0
    end
  end
end
