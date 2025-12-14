# frozen_string_literal: true

# Sidekiq Queue Depth Monitoring
# Monitors queue sizes and latencies to prevent Redis OOM from job explosions

Sidekiq.configure_server do |config|
  config.on(:startup) do
    Thread.new do
      loop do
        begin
          monitor_queue_health
        rescue StandardError => e
          Rails.logger.error("Sidekiq queue monitoring error: #{e.class}: #{e.message}")
        end

        sleep ENV.fetch('SIDEKIQ_MONITOR_INTERVAL_SECONDS', 60).to_i
      end
    end
  end
end

def monitor_queue_health
  queues = Sidekiq::Queue.all
  total_size = 0
  warnings = []
  criticals = []

  queues.each do |queue|
    size = queue.size
    latency = queue.latency.to_i
    total_size += size

    # Collect queue statistics
    stats = {
      queue: queue.name,
      size: size,
      latency: latency
    }

    # Check warning thresholds
    if size > 500
      warnings << "#{queue.name} has #{size} jobs (threshold: 500)"
    end

    if latency > 300
      warnings << "#{queue.name} latency is #{latency}s (threshold: 300s)"
    end

    # Check critical thresholds
    if size > 2000
      criticals << "#{queue.name} has #{size} jobs (critical threshold: 2000)"
    end

    # Log individual queue stats if over warning threshold
    if size > 500 || latency > 300
      Rails.logger.warn("Sidekiq queue metrics: #{stats.inspect}")
    end
  end

  # Check total queue size critical threshold
  if total_size > 5000
    criticals << "Total queue size is #{total_size} jobs (critical threshold: 5000)"
  end

  # Log warnings
  warnings.each do |warning|
    Rails.logger.warn("Sidekiq queue warning: #{warning}")
  end

  # Log criticals
  criticals.each do |critical|
    Rails.logger.error("Sidekiq queue CRITICAL: #{critical}")
  end

  # Log summary if any issues detected
  if warnings.any? || criticals.any?
    summary = {
      total_queues: queues.size,
      total_jobs: total_size,
      warnings: warnings.size,
      criticals: criticals.size
    }
    Rails.logger.warn("Sidekiq monitoring summary: #{summary.inspect}")
  end
end
