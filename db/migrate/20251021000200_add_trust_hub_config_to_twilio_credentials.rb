class AddTrustHubConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # Trust Hub enrichment toggle
    add_column :twilio_credentials, :enable_trust_hub, :boolean, default: false

    # Trust Hub policy SID (specific to business type/use case)
    add_column :twilio_credentials, :trust_hub_policy_sid, :string

    # Webhook URL for Trust Hub status updates
    add_column :twilio_credentials, :trust_hub_webhook_url, :string

    # Auto-create Trust Hub profiles for verified businesses
    add_column :twilio_credentials, :auto_create_trust_hub_profiles, :boolean, default: false

    # Re-verification interval in days
    add_column :twilio_credentials, :trust_hub_reverification_days, :integer, default: 90
  end
end
