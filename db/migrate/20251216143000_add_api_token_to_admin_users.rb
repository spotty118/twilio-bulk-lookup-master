class AddApiTokenToAdminUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :admin_users, :api_token, :string
    add_index :admin_users, :api_token, unique: true
  end
end
