class AddAddressEnrichmentConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :twilio_credentials, :enable_address_enrichment, :boolean, default: false
    add_column :twilio_credentials, :enable_verizon_coverage_check, :boolean, default: false
    add_column :twilio_credentials, :whitepages_api_key, :string
    add_column :twilio_credentials, :truecaller_api_key, :string
    add_column :twilio_credentials, :auto_check_verizon_coverage, :boolean, default: true
  end
end
