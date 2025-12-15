# ActiveRecord Encryption Configuration
# Sets up encryption keys for sensitive model attributes (API keys, tokens, etc.)
#
# Key Generation:
# Run these commands to generate encryption keys:
#   ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(rails db:encryption:init | grep primary_key | awk '{print $2}')
#   ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(rails db:encryption:init | grep deterministic_key | awk '{print $2}')
#   ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(rails db:encryption:init | grep key_derivation_salt | awk '{print $2}')
#
# Or manually run: rails db:encryption:init
#
# Key Storage:
# - Development: Use Rails credentials or .env file
# - Production: Set as environment variables in hosting platform
#
# Security Notes:
# - Keys must be kept secret and never committed to version control
# - Changing keys will make existing encrypted data unreadable
# - Back up keys securely before deploying to production
# - Use different keys for each environment (dev, staging, production)

Rails.application.configure do
  # Primary key: Used for encrypting attribute values
  config.active_record.encryption.primary_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY') do
    Rails.application.credentials.active_record_encryption&.dig(:primary_key)
  end

  # Deterministic key: Used for deterministic encryption (allows querying encrypted fields)
  config.active_record.encryption.deterministic_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY') do
    Rails.application.credentials.active_record_encryption&.dig(:deterministic_key)
  end

  # Key derivation salt: Used to derive encryption keys
  config.active_record.encryption.key_derivation_salt = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT') do
    Rails.application.credentials.active_record_encryption&.dig(:key_derivation_salt)
  end
end
