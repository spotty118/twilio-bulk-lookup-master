class AddCompositeIndicesToContacts < ActiveRecord::Migration[7.2]
  def change
    # Index for needs_enrichment scope: where(business_enriched: false, status: 'completed')
    add_index :contacts, [:status, :business_enriched],
              name: 'index_contacts_on_status_and_business_enriched',
              where: "status = 'completed' AND business_enriched = false",
              if_not_exists: true

    # Index for needs_email_enrichment scope: where(email_enriched: false, business_enriched: true)
    add_index :contacts, [:business_enriched, :email_enriched],
              name: 'index_contacts_on_business_and_email_enriched',
              where: "business_enriched = true AND email_enriched = false",
              if_not_exists: true

    # Index for needs_address_enrichment scope: where(is_business: false, address_enriched: false)
    add_index :contacts, [:is_business, :address_enriched],
              name: 'index_contacts_on_is_business_and_address_enriched',
              where: "is_business = false AND address_enriched = false",
              if_not_exists: true

    # Index for needs_verizon_check scope: where(address_enriched: true, verizon_coverage_checked: false)
    add_index :contacts, [:address_enriched, :verizon_coverage_checked],
              name: 'index_contacts_on_address_and_verizon_check',
              where: "address_enriched = true AND verizon_coverage_checked = false",
              if_not_exists: true

    # Index for needs_trust_hub_verification scope
    add_index :contacts, [:is_business, :trust_hub_enriched, :business_enriched],
              name: 'index_contacts_on_trust_hub_needs',
              where: "is_business = true AND trust_hub_enriched = false AND business_enriched = true",
              if_not_exists: true

    # Index for potential_duplicates scope
    add_index :contacts, [:is_duplicate, :duplicate_checked_at],
              name: 'index_contacts_on_duplicate_status',
              where: "is_duplicate = false",
              if_not_exists: true

    # Index for quality filtering
    add_index :contacts, :data_quality_score,
              name: 'index_contacts_on_quality_score',
              if_not_exists: true

    # Index for phone fingerprint lookups (duplicate detection)
    add_index :contacts, :phone_fingerprint,
              name: 'index_contacts_on_phone_fingerprint',
              where: "phone_fingerprint IS NOT NULL",
              if_not_exists: true
  end
end
