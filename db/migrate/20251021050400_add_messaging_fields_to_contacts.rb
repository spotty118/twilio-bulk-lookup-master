class AddMessagingFieldsToContacts < ActiveRecord::Migration[7.2]
  def change
    # SMS outreach tracking
    add_column :contacts, :sms_sent_count, :integer, default: 0
    add_column :contacts, :sms_delivered_count, :integer, default: 0
    add_column :contacts, :sms_failed_count, :integer, default: 0
    add_column :contacts, :sms_last_sent_at, :datetime
    add_column :contacts, :sms_opt_out, :boolean, default: false
    add_column :contacts, :sms_opt_out_at, :datetime

    # Voice outreach tracking
    add_column :contacts, :voice_calls_count, :integer, default: 0
    add_column :contacts, :voice_answered_count, :integer, default: 0
    add_column :contacts, :voice_voicemail_count, :integer, default: 0
    add_column :contacts, :voice_last_called_at, :datetime
    add_column :contacts, :voice_opt_out, :boolean, default: false

    # Engagement tracking
    add_column :contacts, :last_engagement_at, :datetime
    add_column :contacts, :engagement_score, :integer, default: 0
    add_column :contacts, :engagement_status, :string # cold, warm, hot, unresponsive

    # Indexes
    add_index :contacts, :sms_opt_out
    add_index :contacts, :voice_opt_out
    add_index :contacts, :engagement_status
    add_index :contacts, :last_engagement_at
  end
end
