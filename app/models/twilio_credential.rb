class TwilioCredential < ApplicationRecord
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
  
  # Ensure only one credential record exists
  validate :only_one_credential_allowed, on: :create
  
  # Class method to get current credentials (cached)
  def self.current
    Rails.cache.fetch('twilio_credentials', expires_in: 1.hour) do
      first
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
  
  # Clear cache after save
  after_save :clear_cache
  after_destroy :clear_cache
  
  private
  
  def only_one_credential_allowed
    if TwilioCredential.count >= 1
      errors.add(:base, "Only one Twilio credential record is allowed. Please update the existing record.")
    end
  end
  
  def clear_cache
    Rails.cache.delete('twilio_credentials')
  end
end
