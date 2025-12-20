class AddRealPhoneValidation < ActiveRecord::Migration[7.2]
  def change
    # TwilioCredential settings
    add_column :twilio_credentials, :enable_real_phone_validation, :boolean, default: true

    # Contact fields for RPV results
    add_column :contacts, :rpv_status, :string
    add_column :contacts, :rpv_error_text, :string
    add_column :contacts, :rpv_iscell, :string
    add_column :contacts, :rpv_cnam, :string
    add_column :contacts, :rpv_carrier, :string

    add_index :contacts, :rpv_status
  end
end
