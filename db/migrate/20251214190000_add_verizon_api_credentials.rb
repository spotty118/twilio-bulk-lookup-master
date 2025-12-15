class AddVerizonApiCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :twilio_credentials, :verizon_api_key, :string
    add_column :twilio_credentials, :verizon_api_secret, :string
    add_column :twilio_credentials, :verizon_account_name, :string
  end
end
