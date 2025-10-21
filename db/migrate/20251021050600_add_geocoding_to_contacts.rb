class AddGeocodingToContacts < ActiveRecord::Migration[7.2]
  def change
    # Geocoded coordinates
    add_column :contacts, :latitude, :decimal, precision: 10, scale: 6
    add_column :contacts, :longitude, :decimal, precision: 10, scale: 6
    add_column :contacts, :geocoded_at, :datetime
    add_column :contacts, :geocoding_accuracy, :string # rooftop, range_interpolated, geometric_center, approximate
    add_column :contacts, :geocoding_provider, :string # google, manual

    # Indexes for geospatial queries
    add_index :contacts, [:latitude, :longitude]
    add_index :contacts, :geocoded_at
  end
end
