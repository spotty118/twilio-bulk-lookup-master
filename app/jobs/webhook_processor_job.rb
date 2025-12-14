class WebhookProcessorJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Don't retry if webhook was deleted
  discard_on ActiveRecord::RecordNotFound do |job, exception|
    Rails.logger.error("[WebhookProcessorJob] Webhook not found: #{exception.message}")
  end

  def perform(webhook_id)
    webhook = Webhook.find(webhook_id)
    webhook.process!
  rescue StandardError => e
    Rails.logger.error "Webhook processing job failed for webhook #{webhook_id}: #{e.message}"
    raise
  end
end
