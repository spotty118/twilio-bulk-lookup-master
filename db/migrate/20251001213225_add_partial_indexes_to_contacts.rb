class AddPartialIndexesToContacts < ActiveRecord::Migration[7.2]
  def change
    # Partial index for pending contacts (most frequently queried for processing)
    # This index is much smaller and faster than indexing all statuses
    add_index :contacts, :created_at, 
              where: "status = 'pending'",
              name: 'index_contacts_on_created_at_where_pending'
    
    # Partial index for failed contacts (frequently queried for retry operations)
    add_index :contacts, :updated_at,
              where: "status = 'failed'",
              name: 'index_contacts_on_updated_at_where_failed'
    
    # Composite index for status + timestamp queries (dashboard analytics)
    add_index :contacts, [:status, :lookup_performed_at],
              name: 'index_contacts_on_status_and_lookup_performed_at'
    
    # Composite index for carrier analysis queries
    add_index :contacts, [:carrier_name, :device_type],
              where: "status = 'completed'",
              name: 'index_contacts_on_carrier_and_device_where_completed'
  end
end
