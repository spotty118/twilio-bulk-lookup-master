class RenameContactValidToPhoneValid < ActiveRecord::Migration[7.2]
  def change
    rename_column :contacts, :valid, :phone_valid

    if index_name_exists?(:contacts, 'index_contacts_on_valid') && !index_name_exists?(:contacts, 'index_contacts_on_phone_valid')
      rename_index :contacts, 'index_contacts_on_valid', 'index_contacts_on_phone_valid'
    end
  end
end
