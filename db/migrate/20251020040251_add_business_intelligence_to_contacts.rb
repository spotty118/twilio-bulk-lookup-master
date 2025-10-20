class AddBusinessIntelligenceToContacts < ActiveRecord::Migration[7.2]
  def change
    # Business identification
    add_column :contacts, :is_business, :boolean, default: false
    add_column :contacts, :business_name, :string
    add_column :contacts, :business_legal_name, :string
    add_column :contacts, :business_type, :string
    add_column :contacts, :business_category, :string
    add_column :contacts, :business_industry, :string

    # Business size and metrics
    add_column :contacts, :business_employee_count, :integer
    add_column :contacts, :business_employee_range, :string
    add_column :contacts, :business_annual_revenue, :bigint
    add_column :contacts, :business_revenue_range, :string
    add_column :contacts, :business_founded_year, :integer

    # Business location
    add_column :contacts, :business_address, :string
    add_column :contacts, :business_city, :string
    add_column :contacts, :business_state, :string
    add_column :contacts, :business_country, :string
    add_column :contacts, :business_postal_code, :string

    # Business contact info
    add_column :contacts, :business_website, :string
    add_column :contacts, :business_email_domain, :string
    add_column :contacts, :business_linkedin_url, :string
    add_column :contacts, :business_twitter_handle, :string

    # Business description and tags
    add_column :contacts, :business_description, :text
    add_column :contacts, :business_tags, :jsonb, default: []
    add_column :contacts, :business_tech_stack, :jsonb, default: []

    # Enrichment metadata
    add_column :contacts, :business_enriched, :boolean, default: false
    add_column :contacts, :business_enrichment_provider, :string
    add_column :contacts, :business_enriched_at, :datetime
    add_column :contacts, :business_confidence_score, :integer

    # Add indexes for business queries
    add_index :contacts, :is_business
    add_index :contacts, :business_name
    add_index :contacts, :business_type
    add_index :contacts, :business_industry
    add_index :contacts, :business_employee_range
    add_index :contacts, :business_revenue_range
    add_index :contacts, :business_enriched
    add_index :contacts, :business_email_domain

    # Composite indexes for analytics
    add_index :contacts, [:is_business, :business_industry],
              name: 'index_contacts_on_business_and_industry'
    add_index :contacts, [:is_business, :business_employee_range],
              name: 'index_contacts_on_business_and_size'
  end
end
