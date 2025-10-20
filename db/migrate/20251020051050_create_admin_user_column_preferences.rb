class CreateAdminUserColumnPreferences < ActiveRecord::Migration[7.2]
  def change
    create_table :admin_user_column_preferences do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :resource_name, null: false  # e.g., "Contact"
      t.jsonb :preferences, default: {}     # Stores column config

      t.timestamps
    end

    add_index :admin_user_column_preferences, [:admin_user_id, :resource_name],
              unique: true, name: 'index_column_prefs_on_user_and_resource'
  end
end
