class AddAiAndEmailConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # Email enrichment configuration
    add_column :twilio_credentials, :enable_email_enrichment, :boolean, default: true
    add_column :twilio_credentials, :hunter_api_key, :string
    add_column :twilio_credentials, :zerobounce_api_key, :string
    add_column :twilio_credentials, :email_verification_confidence_threshold, :integer, default: 70

    # Duplicate detection configuration
    add_column :twilio_credentials, :enable_duplicate_detection, :boolean, default: true
    add_column :twilio_credentials, :duplicate_confidence_threshold, :integer, default: 80
    add_column :twilio_credentials, :auto_merge_duplicates, :boolean, default: false

    # AI/GPT configuration
    add_column :twilio_credentials, :enable_ai_features, :boolean, default: true
    add_column :twilio_credentials, :openai_api_key, :string
    add_column :twilio_credentials, :ai_model, :string, default: 'gpt-4o-mini'
    add_column :twilio_credentials, :ai_max_tokens, :integer, default: 500
  end
end
