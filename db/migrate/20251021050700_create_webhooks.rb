class CreateWebhooks < ActiveRecord::Migration[7.2]
  def change
    create_table :webhooks do |t|
      t.references :contact, null: true, foreign_key: true

      # Webhook identification
      t.string :source, null: false # twilio_trust_hub, twilio_sms, twilio_voice, etc.
      t.string :event_type, null: false # status_update, delivery_report, etc.
      t.string :external_id # external reference ID (e.g., Trust Hub SID)

      # Payload
      t.jsonb :payload, default: {}
      t.jsonb :headers, default: {}

      # Processing status
      t.string :status, default: 'pending' # pending, processing, processed, failed
      t.datetime :processed_at
      t.text :processing_error
      t.integer :retry_count, default: 0

      # Timestamps
      t.datetime :received_at, null: false
      t.timestamps
    end

    # Indexes
    add_index :webhooks, :source
    add_index :webhooks, :event_type
    add_index :webhooks, :external_id
    add_index :webhooks, :status
    add_index :webhooks, :received_at
    add_index :webhooks, [:source, :event_type]
  end
end
