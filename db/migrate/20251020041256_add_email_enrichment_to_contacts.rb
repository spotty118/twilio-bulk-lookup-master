class AddEmailEnrichmentToContacts < ActiveRecord::Migration[7.2]
  def change
    # Email data
    add_column :contacts, :email, :string
    add_column :contacts, :email_verified, :boolean
    add_column :contacts, :email_score, :integer
    add_column :contacts, :email_status, :string
    add_column :contacts, :email_type, :string
    add_column :contacts, :additional_emails, :jsonb, default: []

    # Email enrichment metadata
    add_column :contacts, :email_enriched, :boolean, default: false
    add_column :contacts, :email_enrichment_provider, :string
    add_column :contacts, :email_enriched_at, :datetime

    # Personal contact info (from email lookup)
    add_column :contacts, :first_name, :string
    add_column :contacts, :last_name, :string
    add_column :contacts, :full_name, :string
    add_column :contacts, :position, :string
    add_column :contacts, :department, :string
    add_column :contacts, :seniority, :string

    # Social profiles from email
    add_column :contacts, :linkedin_url, :string
    add_column :contacts, :twitter_url, :string
    add_column :contacts, :facebook_url, :string

    # Add indexes
    add_index :contacts, :email
    add_index :contacts, :email_verified
    add_index :contacts, :email_enriched
    add_index :contacts, :full_name
    add_index :contacts, [:last_name, :first_name], name: 'index_contacts_on_name'
  end
end
