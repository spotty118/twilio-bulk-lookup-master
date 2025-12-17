class AddCostTrackingToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :api_cost, :decimal, precision: 8, scale: 4
    add_column :contacts, :api_response_time_ms, :integer
  end
end
