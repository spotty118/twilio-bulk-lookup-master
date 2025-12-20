# frozen_string_literal: true

# Adds index to raw_phone_number for efficient phone lookup queries
# This addresses the performance issue in webhook processing where
# Contact.where('raw_phone_number = ?', ...) was causing full table scans
class AddIndexToContactsRawPhoneNumber < ActiveRecord::Migration[7.2]
  disable_ddl_transaction! # Required for concurrent index creation

  def change
    # Add index concurrently to avoid locking the table during creation
    # This is especially important for large tables in production
    add_index :contacts, :raw_phone_number,
              algorithm: :concurrently,
              if_not_exists: true
  end
end
