class AddConsumerAddressToContacts < ActiveRecord::Migration[7.2]
  def change
    # Consumer residential address fields
    add_column :contacts, :consumer_address, :string
    add_column :contacts, :consumer_city, :string
    add_column :contacts, :consumer_state, :string
    add_column :contacts, :consumer_postal_code, :string
    add_column :contacts, :consumer_country, :string, default: 'USA'

    # Address metadata
    add_column :contacts, :address_type, :string # residential, business, po_box, apartment
    add_column :contacts, :address_verified, :boolean
    add_column :contacts, :address_enriched, :boolean, default: false
    add_column :contacts, :address_enrichment_provider, :string
    add_column :contacts, :address_enriched_at, :datetime
    add_column :contacts, :address_confidence_score, :integer

    # Indexes for filtering and searching
    add_index :contacts, :consumer_postal_code
    add_index :contacts, :consumer_state
    add_index :contacts, :address_enriched
  end
end
