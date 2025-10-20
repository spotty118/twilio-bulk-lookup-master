class AddBusinessEnrichmentConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # Business enrichment toggle
    add_column :twilio_credentials, :enable_business_enrichment, :boolean, default: true

    # API keys for business enrichment providers
    add_column :twilio_credentials, :clearbit_api_key, :string
    add_column :twilio_credentials, :numverify_api_key, :string

    # Enrichment preferences
    add_column :twilio_credentials, :auto_enrich_businesses, :boolean, default: true
    add_column :twilio_credentials, :enrichment_confidence_threshold, :integer, default: 50
  end
end
