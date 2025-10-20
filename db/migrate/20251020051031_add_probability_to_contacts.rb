class AddProbabilityToContacts < ActiveRecord::Migration[7.2]
  def change
    add_column :contacts, :verizon_5g_probability, :integer
    add_column :contacts, :verizon_lte_probability, :integer

    add_index :contacts, :verizon_5g_probability
    add_index :contacts, :verizon_lte_probability
  end
end
