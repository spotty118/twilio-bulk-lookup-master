class AddTrustHubToContacts < ActiveRecord::Migration[7.2]
  def change
    # Trust Hub verification status
    add_column :contacts, :trust_hub_verified, :boolean, default: false
    add_column :contacts, :trust_hub_status, :string
    add_column :contacts, :trust_hub_business_sid, :string
    add_column :contacts, :trust_hub_customer_profile_sid, :string

    # Business verification details
    add_column :contacts, :trust_hub_business_name, :string
    add_column :contacts, :trust_hub_business_type, :string
    add_column :contacts, :trust_hub_registration_number, :string
    add_column :contacts, :trust_hub_tax_id, :string
    add_column :contacts, :trust_hub_website, :string

    # Regulatory compliance
    add_column :contacts, :trust_hub_regulatory_status, :string
    add_column :contacts, :trust_hub_compliance_type, :string
    add_column :contacts, :trust_hub_country, :string
    add_column :contacts, :trust_hub_region, :string

    # Verification metadata
    add_column :contacts, :trust_hub_verified_at, :datetime
    add_column :contacts, :trust_hub_verification_score, :integer
    add_column :contacts, :trust_hub_verification_data, :jsonb, default: {}
    add_column :contacts, :trust_hub_checks_completed, :jsonb, default: []
    add_column :contacts, :trust_hub_checks_failed, :jsonb, default: []

    # Enrichment tracking
    add_column :contacts, :trust_hub_enriched, :boolean, default: false
    add_column :contacts, :trust_hub_enriched_at, :datetime
    add_column :contacts, :trust_hub_error, :text

    # Add indexes for Trust Hub queries
    add_index :contacts, :trust_hub_verified
    add_index :contacts, :trust_hub_status
    add_index :contacts, :trust_hub_business_sid
    add_index :contacts, :trust_hub_regulatory_status
    add_index :contacts, :trust_hub_compliance_type
    add_index :contacts, :trust_hub_enriched

    # Composite indexes
    add_index :contacts, [:is_business, :trust_hub_verified],
              name: 'index_contacts_on_business_and_trust_verified'
    add_index :contacts, [:trust_hub_verified, :trust_hub_status],
              name: 'index_contacts_on_trust_verified_and_status'
  end
end
