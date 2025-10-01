class Contact < ApplicationRecord
  validates :raw_phone_number, :presence => true

  # Define searchable attributes for ActiveAdmin/Ransack
  def self.ransackable_attributes(auth_object = nil)
    ["carrier_name", "created_at", "device_type", "error_code", 
     "formatted_phone_number", "id", "mobile_country_code", 
     "mobile_network_code", "raw_phone_number", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
end
