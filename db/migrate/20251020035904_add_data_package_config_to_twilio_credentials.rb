class AddDataPackageConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # Add configuration flags for Twilio Lookup v2 data packages
    add_column :twilio_credentials, :enable_line_type_intelligence, :boolean, default: true
    add_column :twilio_credentials, :enable_caller_name, :boolean, default: true
    add_column :twilio_credentials, :enable_sms_pumping_risk, :boolean, default: true
    add_column :twilio_credentials, :enable_sim_swap, :boolean, default: false
    add_column :twilio_credentials, :enable_reassigned_number, :boolean, default: false

    # Add notes field for admin reference
    add_column :twilio_credentials, :notes, :text
  end
end
