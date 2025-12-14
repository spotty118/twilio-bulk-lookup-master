class AddMissingIndicesForPerformance < ActiveRecord::Migration[7.2]
  def change
    # Composite indices for common query patterns identified in Darwin-Gödel analysis

    # Contact enrichment status queries
    add_index :contacts, [:status, :business_enriched],
              name: 'index_contacts_on_status_and_business_enriched',
              if_not_exists: true

    add_index :contacts, [:status, :email_enriched],
              name: 'index_contacts_on_status_and_email_enriched',
              if_not_exists: true

    add_index :contacts, [:status, :address_enriched],
              name: 'index_contacts_on_status_and_address_enriched',
              if_not_exists: true

    # Duplicate detection queries
    add_index :contacts, :phone_fingerprint,
              where: "phone_fingerprint IS NOT NULL",
              name: 'index_contacts_on_phone_fingerprint_partial',
              if_not_exists: true

    add_index :contacts, :email_fingerprint,
              where: "email_fingerprint IS NOT NULL",
              name: 'index_contacts_on_email_fingerprint_partial',
              if_not_exists: true

    add_index :contacts, :name_fingerprint,
              where: "name_fingerprint IS NOT NULL",
              name: 'index_contacts_on_name_fingerprint_partial',
              if_not_exists: true

    add_index :contacts, [:duplicate_of_id, :is_duplicate],
              name: 'index_contacts_on_duplicate_of_id_and_is_duplicate',
              if_not_exists: true

    # Business intelligence queries
    add_index :contacts, :business_industry,
              where: "business_industry IS NOT NULL",
              name: 'index_contacts_on_business_industry_partial',
              if_not_exists: true

    add_index :contacts, [:is_business, :business_enriched],
              name: 'index_contacts_on_is_business_and_enriched',
              if_not_exists: true

    # Quality and risk queries
    add_index :contacts, :data_quality_score,
              name: 'index_contacts_on_data_quality_score',
              if_not_exists: true

    add_index :contacts, :sms_pumping_risk_level,
              where: "sms_pumping_risk_level IS NOT NULL",
              name: 'index_contacts_on_sms_pumping_risk_level_partial',
              if_not_exists: true

    # CRM sync queries
    add_index :contacts, :salesforce_id,
              where: "salesforce_id IS NOT NULL",
              name: 'index_contacts_on_salesforce_id_partial',
              if_not_exists: true

    add_index :contacts, :hubspot_id,
              where: "hubspot_id IS NOT NULL",
              name: 'index_contacts_on_hubspot_id_partial',
              if_not_exists: true

    add_index :contacts, :pipedrive_id,
              where: "pipedrive_id IS NOT NULL",
              name: 'index_contacts_on_pipedrive_id_partial',
              if_not_exists: true
  end
end
