class AddSmsVoiceConfigToTwilioCredentials < ActiveRecord::Migration[7.2]
  def change
    # SMS & Voice messaging features
    add_column :twilio_credentials, :enable_sms_messaging, :boolean, default: false
    add_column :twilio_credentials, :enable_voice_messaging, :boolean, default: false

    # Twilio phone number for outbound messaging
    add_column :twilio_credentials, :twilio_phone_number, :string
    add_column :twilio_credentials, :twilio_messaging_service_sid, :string

    # Voice call settings
    add_column :twilio_credentials, :voice_call_webhook_url, :string
    add_column :twilio_credentials, :voice_recording_enabled, :boolean, default: false

    # SMS templates
    add_column :twilio_credentials, :sms_intro_template, :text
    add_column :twilio_credentials, :sms_follow_up_template, :text

    # Rate limiting for outreach
    add_column :twilio_credentials, :max_sms_per_hour, :integer, default: 100
    add_column :twilio_credentials, :max_calls_per_hour, :integer, default: 50
  end
end
