# Migration to ensure encrypted columns exist and are string type
# All API key columns already exist in schema.rb, this migration ensures
# they're compatible with ActiveRecord encryption (string/text types)
class EnsureEncryptedColumnsExist < ActiveRecord::Migration[7.2]
  def up
    # Query pattern: TwilioCredential.current.auth_token
    # Used in: Multiple service files for API authentication
    # Note: All columns already exist as string type in schema.rb (lines 306-387)
    # This migration is a safety check for encryption compatibility

    # Ensure columns exist (idempotent - won't fail if they already exist)
    unless column_exists?(:twilio_credentials, :auth_token)
      add_column :twilio_credentials, :auth_token, :string
    end

    unless column_exists?(:twilio_credentials, :clearbit_api_key)
      add_column :twilio_credentials, :clearbit_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :numverify_api_key)
      add_column :twilio_credentials, :numverify_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :hunter_api_key)
      add_column :twilio_credentials, :hunter_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :zerobounce_api_key)
      add_column :twilio_credentials, :zerobounce_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :whitepages_api_key)
      add_column :twilio_credentials, :whitepages_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :truecaller_api_key)
      add_column :twilio_credentials, :truecaller_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :google_places_api_key)
      add_column :twilio_credentials, :google_places_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :yelp_api_key)
      add_column :twilio_credentials, :yelp_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :openai_api_key)
      add_column :twilio_credentials, :openai_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :anthropic_api_key)
      add_column :twilio_credentials, :anthropic_api_key, :string
    end

    unless column_exists?(:twilio_credentials, :google_ai_api_key)
      add_column :twilio_credentials, :google_ai_api_key, :string
    end
  end

  def down
    # Intentionally blank - don't remove columns on rollback
    # as they may contain important data
  end
end
