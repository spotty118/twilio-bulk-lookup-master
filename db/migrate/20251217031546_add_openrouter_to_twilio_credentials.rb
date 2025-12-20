class AddOpenrouterToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :twilio_credentials, :openrouter_api_key, :string
    add_column :twilio_credentials, :enable_openrouter, :boolean, default: false
    add_column :twilio_credentials, :openrouter_model, :string, default: 'openai/gpt-4o-mini'
    add_column :twilio_credentials, :preferred_llm_provider, :string, default: 'openai'
  end
end
