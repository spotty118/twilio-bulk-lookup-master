class AddEnableIcehookScoutToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :twilio_credentials, :enable_icehook_scout, :boolean, default: false
  end
end
