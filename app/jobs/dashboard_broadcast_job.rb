# Debounced dashboard broadcast job
# This job is enqueued by Contact model callbacks but only actually broadcasts
# if sufficient time has passed since the last broadcast, coalescing rapid changes.
class DashboardBroadcastJob < ApplicationJob
  queue_as :default

  # Use a unique job ID to prevent duplicate jobs from being enqueued
  # This is a Sidekiq feature that deduplicates jobs with the same arguments
  def perform
    # Double-check throttle to handle race conditions between job enqueue and execution
    throttle_key = 'dashboard_broadcast_executing'
    
    # Use atomic operation to prevent multiple jobs from broadcasting simultaneously
    return unless Rails.cache.write(throttle_key, true, expires_in: 1.second, unless_exist: true)
    
    begin
      # Refresh materialized stats outside of write transactions
      begin
        DashboardStats.refresh!
      rescue StandardError => e
        Rails.logger.warn("Dashboard stats refresh failed: #{e.message}")
      end

      # Broadcast the actual update
      Turbo::StreamsChannel.broadcast_replace_to(
        "dashboard_stats",
        target: "dashboard_stats",
        partial: "admin/dashboard/stats",
        locals: { refresh: true }
      )
      
      Rails.logger.debug("Dashboard stats broadcast completed")
    rescue StandardError => e
      Rails.logger.warn("Dashboard broadcast job failed: #{e.message}")
    end
  end
end
