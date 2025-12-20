class AddSimSwapToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :sim_swap_last_sim_swap_date, :datetime
    add_column :contacts, :sim_swap_swapped_period, :string
    add_column :contacts, :sim_swap_swapped_in_period, :boolean
  end
end
