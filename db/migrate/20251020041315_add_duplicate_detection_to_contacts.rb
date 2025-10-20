class AddDuplicateDetectionToContacts < ActiveRecord::Migration[7.2]
  def change
    # Duplicate tracking
    add_column :contacts, :duplicate_of_id, :bigint
    add_column :contacts, :is_duplicate, :boolean, default: false
    add_column :contacts, :duplicate_confidence, :integer
    add_column :contacts, :duplicate_checked_at, :datetime
    add_column :contacts, :merge_history, :jsonb, default: []

    # Fingerprinting for fast duplicate detection
    add_column :contacts, :phone_fingerprint, :string
    add_column :contacts, :name_fingerprint, :string
    add_column :contacts, :email_fingerprint, :string

    # Quality score for merge decisions
    add_column :contacts, :data_quality_score, :integer
    add_column :contacts, :completeness_percentage, :integer

    # Add indexes
    add_index :contacts, :duplicate_of_id
    add_index :contacts, :is_duplicate
    add_index :contacts, :phone_fingerprint
    add_index :contacts, :name_fingerprint
    add_index :contacts, :email_fingerprint
    add_index :contacts, :data_quality_score

    # Add foreign key
    add_foreign_key :contacts, :contacts, column: :duplicate_of_id
  end
end
