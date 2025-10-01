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
