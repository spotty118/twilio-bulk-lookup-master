# frozen_string_literal: true

class AddRpvUniqueNameToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :twilio_credentials, :rpv_unique_name, :string, default: 'real_phone_validation_rpv_turbo'
  end
end
