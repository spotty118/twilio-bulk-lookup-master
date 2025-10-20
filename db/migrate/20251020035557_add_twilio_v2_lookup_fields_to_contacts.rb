class AddTwilioV2LookupFieldsToContacts < ActiveRecord::Migration[7.2]
  def change
    # Phone number validation fields
    add_column :contacts, :valid, :boolean
    add_column :contacts, :validation_errors, :jsonb, default: []
    add_column :contacts, :country_code, :string
    add_column :contacts, :calling_country_code, :string

    # Line Type Intelligence (enhanced device type)
    add_column :contacts, :line_type, :string
    add_column :contacts, :line_type_confidence, :string

    # Caller Name (CNAM) - US only
    add_column :contacts, :caller_name, :string
    add_column :contacts, :caller_type, :string

    # SMS Pumping Risk Score (fraud detection)
    add_column :contacts, :sms_pumping_risk_score, :integer
    add_column :contacts, :sms_pumping_risk_level, :string
    add_column :contacts, :sms_pumping_carrier_risk_category, :string
    add_column :contacts, :sms_pumping_number_blocked, :boolean

    # Reassigned Number (US only)
    add_column :contacts, :reassigned_number_last_verified_date, :date
    add_column :contacts, :reassigned_number_is_reassigned, :boolean

    # Add indexes for commonly queried fields
    add_index :contacts, :valid
    add_index :contacts, :line_type
    add_index :contacts, :sms_pumping_risk_level
    add_index :contacts, :sms_pumping_risk_score
    add_index :contacts, :country_code

    # Composite index for fraud analysis
    add_index :contacts, [:sms_pumping_risk_level, :country_code],
              name: 'index_contacts_on_risk_and_country'
  end
end
