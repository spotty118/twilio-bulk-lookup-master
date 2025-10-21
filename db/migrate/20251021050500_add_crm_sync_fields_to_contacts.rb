class AddCrmSyncFieldsToContacts < ActiveRecord::Migration[7.2]
  def change
    # Salesforce sync
    add_column :contacts, :salesforce_id, :string
    add_column :contacts, :salesforce_synced_at, :datetime
    add_column :contacts, :salesforce_sync_status, :string

    # HubSpot sync
    add_column :contacts, :hubspot_id, :string
    add_column :contacts, :hubspot_synced_at, :datetime
    add_column :contacts, :hubspot_sync_status, :string

    # Pipedrive sync
    add_column :contacts, :pipedrive_id, :string
    add_column :contacts, :pipedrive_synced_at, :datetime
    add_column :contacts, :pipedrive_sync_status, :string

    # General CRM tracking
    add_column :contacts, :crm_sync_enabled, :boolean, default: true
    add_column :contacts, :crm_sync_errors, :jsonb, default: {}
    add_column :contacts, :last_crm_sync_at, :datetime

    # Indexes for CRM lookups
    add_index :contacts, :salesforce_id, unique: true, where: "salesforce_id IS NOT NULL"
    add_index :contacts, :hubspot_id, unique: true, where: "hubspot_id IS NOT NULL"
    add_index :contacts, :pipedrive_id, unique: true, where: "pipedrive_id IS NOT NULL"
    add_index :contacts, :last_crm_sync_at
  end
end
