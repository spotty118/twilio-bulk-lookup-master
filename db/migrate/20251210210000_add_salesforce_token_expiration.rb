class AddSalesforceTokenExpiration < ActiveRecord::Migration[7.2]
  def change
    add_column :twilio_credentials, :salesforce_token_expires_at, :datetime
  end
end
