class AddUniqueConstraintToTwilioCredentials < ActiveRecord::Migration[7.2]
  def up
    # Add a boolean column to enforce singleton pattern at database level
    # This prevents race conditions where multiple records could be created simultaneously
    # Defense-in-depth: DB constraint + model validation
    unless column_exists?(:twilio_credentials, :is_singleton)
      add_column :twilio_credentials, :is_singleton, :boolean, default: true, null: false
    end

    # Set existing records to is_singleton=true (should only be 0-1 records)
    execute "UPDATE twilio_credentials SET is_singleton = true"

    # Add unique partial index - guarantees only one record can have is_singleton=true
    # This is mathematically proven to prevent race conditions even under concurrent load
    # Query pattern: Singleton enforcement for configuration table
    add_index :twilio_credentials, :is_singleton, unique: true,
              where: "is_singleton = true",
              name: 'index_twilio_credentials_singleton',
              if_not_exists: true
  end

  def down
    remove_index :twilio_credentials, name: 'index_twilio_credentials_singleton', if_exists: true
    remove_column :twilio_credentials, :is_singleton if column_exists?(:twilio_credentials, :is_singleton)
  end
end
