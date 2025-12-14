# frozen_string_literal: true

# Migration: Add Webhook Idempotency Protection
#
# Purpose: Prevent replay attacks by enforcing unique constraint on webhook identifiers
#
# Attack Vector: Attackers can replay webhook POST requests with same MessageSid/CallSid,
# causing duplicate processing, wasted API credits, and duplicate data updates.
#
# Solution: Add unique index on (source, external_id) to reject duplicate webhooks
# at database level (defense-in-depth with application-level find_or_create_by).
#
# Query Pattern: WebhooksController creates webhooks with source + external_id
# Found in: app/controllers/webhooks_controller.rb:7-15, :34-42, :61-69
#
# Example: source='twilio_sms', external_id='SM1234567890abcdef1234567890abcdef'
#
class AddWebhookIdempotency < ActiveRecord::Migration[7.2]
  def up
    # Add idempotency key column to track unique webhook requests
    # This is a hash of (source + external_id) for faster lookups
    add_column :webhooks, :idempotency_key, :string, if_not_exists: true

    # Populate idempotency_key for existing webhooks
    # Use reversible migration to maintain rollback capability
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE webhooks
          SET idempotency_key = CONCAT(source, ':', COALESCE(external_id, ''))
          WHERE idempotency_key IS NULL
        SQL
      end
    end

    # Add unique index to enforce idempotency at database level
    # This prevents replay attacks even if application code is bypassed
    add_index :webhooks, :idempotency_key,
              unique: true,
              name: 'index_webhooks_on_idempotency_key',
              if_not_exists: true

    # Alternative: Composite unique index on (source, external_id)
    # This is more explicit and works even if idempotency_key is somehow NULL
    add_index :webhooks, [:source, :external_id],
              unique: true,
              where: "external_id IS NOT NULL",
              name: 'index_webhooks_on_source_and_external_id',
              if_not_exists: true

    # Add timestamp index for cleanup/expiration queries
    # Webhooks older than 30 days can be archived
    add_index :webhooks, :received_at,
              name: 'index_webhooks_on_received_at',
              if_not_exists: true
  end

  def down
    remove_index :webhooks, name: 'index_webhooks_on_idempotency_key', if_exists: true
    remove_index :webhooks, name: 'index_webhooks_on_source_and_external_id', if_exists: true
    remove_index :webhooks, name: 'index_webhooks_on_received_at', if_exists: true
    remove_column :webhooks, :idempotency_key, if_exists: true
  end
end
