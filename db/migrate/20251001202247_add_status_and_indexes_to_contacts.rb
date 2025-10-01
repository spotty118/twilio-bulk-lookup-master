class AddStatusAndIndexesToContacts < ActiveRecord::Migration[7.2]
  def change
    # Add status tracking column with default value
    add_column :contacts, :status, :string, default: 'pending', null: false
    add_column :contacts, :lookup_performed_at, :datetime
    
    # Add indexes for performance
    add_index :contacts, :status
    add_index :contacts, :formatted_phone_number
    add_index :contacts, :error_code
    add_index :contacts, :lookup_performed_at
    
    # Backfill existing records: mark as completed if they have results
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE contacts
          SET status = 'completed'
          WHERE formatted_phone_number IS NOT NULL;
        SQL
        
        execute <<-SQL
          UPDATE contacts
          SET status = 'failed'
          WHERE error_code IS NOT NULL AND formatted_phone_number IS NULL;
        SQL
      end
    end
  end
end
