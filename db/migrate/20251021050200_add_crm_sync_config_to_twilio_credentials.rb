class AddCrmSyncConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # Salesforce integration
    add_column :twilio_credentials, :enable_salesforce_sync, :boolean, default: false
    add_column :twilio_credentials, :salesforce_instance_url, :string
    add_column :twilio_credentials, :salesforce_client_id, :string
    add_column :twilio_credentials, :salesforce_client_secret, :string
    add_column :twilio_credentials, :salesforce_access_token, :string
    add_column :twilio_credentials, :salesforce_refresh_token, :string
    add_column :twilio_credentials, :salesforce_auto_sync, :boolean, default: false

    # HubSpot integration
    add_column :twilio_credentials, :enable_hubspot_sync, :boolean, default: false
    add_column :twilio_credentials, :hubspot_api_key, :string
    add_column :twilio_credentials, :hubspot_portal_id, :string
    add_column :twilio_credentials, :hubspot_auto_sync, :boolean, default: false

    # Pipedrive integration
    add_column :twilio_credentials, :enable_pipedrive_sync, :boolean, default: false
    add_column :twilio_credentials, :pipedrive_api_key, :string
    add_column :twilio_credentials, :pipedrive_company_domain, :string
    add_column :twilio_credentials, :pipedrive_auto_sync, :boolean, default: false

    # General sync settings
    add_column :twilio_credentials, :crm_sync_interval_minutes, :integer, default: 60
    add_column :twilio_credentials, :crm_sync_direction, :string, default: 'bidirectional' # bidirectional, push, pull
  end
end
