class TwilioCredential < ApplicationRecord
  # Encrypted attributes for secure API key storage
  encrypts :auth_token
  encrypts :clearbit_api_key
  encrypts :numverify_api_key
  encrypts :hunter_api_key
  encrypts :zerobounce_api_key
  encrypts :whitepages_api_key
  encrypts :truecaller_api_key
  encrypts :google_places_api_key
  encrypts :yelp_api_key
  encrypts :openai_api_key
  encrypts :anthropic_api_key
  encrypts :google_ai_api_key

  # Validations
  validates :account_sid, :auth_token, presence: true
  validates :account_sid,
            format: {
              with: /\AAC[a-z0-9]{32}\z/i,
              message: "must be a valid Twilio Account SID (AC followed by 32 characters)"
            },
            uniqueness: true
  validates :auth_token,
            format: {
              with: /\A[a-z0-9]{32}\z/i,
              message: "must be a valid Twilio Auth Token (32 alphanumeric characters)"
            }

  # Singleton enforcement via defense-in-depth:
  # Layer 1 (this validation): User-friendly error message
  # Layer 2 (DB unique index): Absolute guarantee even if validation bypassed
  validate :singleton_constraint, on: :create

  def singleton_constraint
    # Only enforce if creating an active singleton record
    return unless is_singleton?

    if TwilioCredential.where(is_singleton: true).exists?
      errors.add(:base, "Only one Twilio credential record is allowed. Please update the existing record.")
    end
  end

  # Class method to get current credentials (cached)
  # race_condition_ttl prevents cache stampede during concurrent updates
  def self.current
    Rails.cache.fetch('twilio_credential_singleton',
                      expires_in: 1.hour,
                      race_condition_ttl: 10.seconds) do
      find_by(is_singleton: true)
    end
  end

  # Build data packages string for Twilio Lookup v2 API
  # Returns comma-separated list of enabled packages
  def data_packages
    packages = []
    packages << 'line_type_intelligence' if enable_line_type_intelligence
    packages << 'caller_name' if enable_caller_name
    packages << 'sms_pumping_risk' if enable_sms_pumping_risk
    packages << 'sim_swap' if enable_sim_swap
    packages << 'reassigned_number' if enable_reassigned_number
    packages.join(',')
  end

  # Check if any data packages are enabled
  def data_packages_enabled?
    enable_line_type_intelligence || enable_caller_name || enable_sms_pumping_risk ||
      enable_sim_swap || enable_reassigned_number
  end

  # Clear singleton cache after save/destroy to prevent stale credentials
  after_save :clear_singleton_cache
  after_destroy :clear_singleton_cache

  private

  # Invalidate cached singleton credentials
  # Only runs for singleton records to avoid unnecessary cache churn
  def clear_singleton_cache
    return unless is_singleton?

    Rails.cache.delete('twilio_credential_singleton')
    Rails.logger.info("TwilioCredential cache invalidated for singleton record (ID: #{id})")
  end
end
