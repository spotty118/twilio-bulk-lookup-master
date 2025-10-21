class CreateApiUsageLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :api_usage_logs do |t|
      t.references :contact, null: true, foreign_key: true

      # API identification
      t.string :provider, null: false # twilio, clearbit, hunter, etc.
      t.string :service, null: false # lookup, enrichment, verification, etc.
      t.string :endpoint # specific API endpoint called

      # Cost tracking
      t.decimal :cost, precision: 10, scale: 4, default: 0.0
      t.string :currency, default: 'USD'
      t.integer :credits_used, default: 0

      # Request details
      t.string :request_id
      t.string :status # success, failed, rate_limited, etc.
      t.integer :response_time_ms
      t.integer :http_status_code

      # Metadata
      t.jsonb :request_params, default: {}
      t.jsonb :response_data, default: {}
      t.text :error_message

      # Timestamps
      t.datetime :requested_at, null: false
      t.timestamps
    end

    # Indexes for efficient querying
    add_index :api_usage_logs, :provider
    add_index :api_usage_logs, :service
    add_index :api_usage_logs, :status
    add_index :api_usage_logs, :requested_at
    add_index :api_usage_logs, [:provider, :requested_at]
    add_index :api_usage_logs, [:contact_id, :provider]
  end
end
