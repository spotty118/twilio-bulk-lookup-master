class CreateZipcodeLookups < ActiveRecord::Migration[7.2]
  def change
    create_table :zipcode_lookups do |t|
      t.string :zipcode, null: false
      t.string :status, default: 'pending', null: false # pending, processing, completed, failed
      t.integer :businesses_found, default: 0
      t.integer :businesses_imported, default: 0
      t.integer :businesses_updated, default: 0
      t.integer :businesses_skipped, default: 0
      t.string :provider # google_places, yelp, etc.
      t.text :search_params # JSON with search parameters
      t.text :error_message
      t.datetime :lookup_started_at
      t.datetime :lookup_completed_at

      t.timestamps
    end

    add_index :zipcode_lookups, :zipcode
    add_index :zipcode_lookups, :status
    add_index :zipcode_lookups, :created_at
  end
end
