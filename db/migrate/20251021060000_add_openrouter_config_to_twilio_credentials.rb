class AddOpenrouterConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # OpenRouter API configuration
    add_column :twilio_credentials, :openrouter_api_key, :string
    add_column :twilio_credentials, :enable_openrouter, :boolean, default: false
    add_column :twilio_credentials, :openrouter_model, :string, default: 'openai/gpt-4o-mini'

    # Optional: Site identification for OpenRouter rankings
    add_column :twilio_credentials, :openrouter_site_url, :string
    add_column :twilio_credentials, :openrouter_site_name, :string
  end
end
