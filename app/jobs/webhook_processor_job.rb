class WebhookProcessorJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(webhook_id)
    webhook = Webhook.find(webhook_id)
    webhook.process!
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Webhook not found: #{webhook_id}"
  rescue => e
    Rails.logger.error "Webhook processing job failed for webhook #{webhook_id}: #{e.message}"
    raise
  end
end
