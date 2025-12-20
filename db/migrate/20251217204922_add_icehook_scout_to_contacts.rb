class AddIcehookScoutToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :scout_ported, :boolean
    add_column :contacts, :scout_location_routing_number, :string
    add_column :contacts, :scout_operating_company_name, :string
    add_column :contacts, :scout_operating_company_type, :string

    add_index :contacts, :scout_ported
  end
end
