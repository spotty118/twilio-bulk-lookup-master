class AddBusinessDirectoryConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :twilio_credentials, :enable_zipcode_lookup, :boolean, default: false
    add_column :twilio_credentials, :google_places_api_key, :string
    add_column :twilio_credentials, :yelp_api_key, :string
    add_column :twilio_credentials, :results_per_zipcode, :integer, default: 20
    add_column :twilio_credentials, :auto_enrich_zipcode_results, :boolean, default: true
  end
end
