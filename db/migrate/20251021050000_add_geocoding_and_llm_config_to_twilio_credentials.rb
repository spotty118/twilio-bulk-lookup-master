class AddGeocodingAndLlmConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # Google Geocoding API for address to coordinates conversion
    add_column :twilio_credentials, :google_geocoding_api_key, :string
    add_column :twilio_credentials, :enable_geocoding, :boolean, default: false

    # Additional LLM model support
    add_column :twilio_credentials, :anthropic_api_key, :string
    add_column :twilio_credentials, :google_ai_api_key, :string
    add_column :twilio_credentials, :enable_anthropic, :boolean, default: false
    add_column :twilio_credentials, :enable_google_ai, :boolean, default: false

    # LLM model selection (openai, anthropic, google)
    add_column :twilio_credentials, :preferred_llm_provider, :string, default: 'openai'
    add_column :twilio_credentials, :anthropic_model, :string, default: 'claude-3-5-sonnet-20241022'
    add_column :twilio_credentials, :google_ai_model, :string, default: 'gemini-1.5-flash'
  end
end
