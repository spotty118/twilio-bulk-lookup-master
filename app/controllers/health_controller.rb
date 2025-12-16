# Health Check Controller
# Provides detailed health status for monitoring and alerting systems
#
# Endpoints:
#   GET /health           - Basic liveness probe (fast)
#   GET /health/ready     - Readiness probe (checks dependencies)
#   GET /health/detailed  - Full diagnostic info (for debugging)
#   GET /health/queue     - Background job status
#

class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  # Liveness probe - fast response (for load balancer health checks)
  # Returns 200 if process is running
  def show
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: HttpClient::APP_VERSION
    }
  end

  # Readiness probe - checks if app can serve traffic
  # Returns 503 if any critical dependency is down
  def ready
    checks = {
      database: check_database,
      redis: check_redis
    }

    all_ok = checks.values.all? { |c| c[:status] == 'ok' }

    render json: {
      status: all_ok ? 'ok' : 'error',
      timestamp: Time.current.iso8601,
      checks: checks
    }, status: all_ok ? :ok : :service_unavailable
  end

  # Detailed health check - includes all dependencies
  def detailed
    health_status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      version: HttpClient::APP_VERSION,
      ruby_version: RUBY_VERSION,
      rails_version: Rails::VERSION::STRING,
      uptime_seconds: uptime_seconds,
      memory: memory_usage,
      checks: {}
    }

    # Core infrastructure
    health_status[:checks][:database] = check_database
    health_status[:checks][:redis] = check_redis
    health_status[:checks][:sidekiq] = check_sidekiq

    # Application state
    health_status[:checks][:twilio_credentials] = check_twilio_credentials
    health_status[:checks][:circuit_breakers] = check_circuit_breakers

    # Overall status
    if health_status[:checks].values.any? { |check| check[:status] == 'error' }
      health_status[:status] = 'error'
      render json: health_status, status: :service_unavailable
    elsif health_status[:checks].values.any? { |check| check[:status] == 'warning' }
      health_status[:status] = 'warning'
      render json: health_status, status: :ok
    else
      render json: health_status, status: :ok
    end
  end

  # Queue status - for monitoring background jobs
  def queue
    stats = {
      contacts: {
        total: Contact.count,
        pending: Contact.pending.count,
        processing: Contact.processing.count,
        completed: Contact.completed.count,
        failed: Contact.failed.count
      },
      sidekiq: sidekiq_stats,
      timestamp: Time.current.iso8601
    }

    render json: stats
  end

  private

  def check_database
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveRecord::Base.connection.execute('SELECT 1')
    response_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

    pool = ActiveRecord::Base.connection_pool
    {
      status: 'ok',
      response_time_ms: response_time,
      pool_size: pool.size,
      active_connections: pool.connections.count(&:in_use?),
      waiting_requests: pool.num_waiting_in_queue
    }
  rescue StandardError => e
    { status: 'error', error: e.message }
  end

  def check_redis
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    redis = Redis.new(url: AppConfig.redis_url)
    begin
      redis.ping
      response_time = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
      info = redis.info

      {
        status: 'ok',
        response_time_ms: response_time,
        connected_clients: info['connected_clients'].to_i,
        used_memory_human: info['used_memory_human'],
        uptime_days: (info['uptime_in_seconds'].to_i / 86_400).round(1)
      }
    ensure
      redis.close
    end
  rescue StandardError => e
    { status: 'error', error: e.message }
  end

  def check_sidekiq
    require 'sidekiq/api'

    stats = Sidekiq::Stats.new
    queue = Sidekiq::Queue.new

    status = 'ok'
    status = 'warning' if stats.failed > 100 || queue.size > 1000
    status = 'error' if stats.processes_size.zero?

    {
      status: status,
      processes: stats.processes_size,
      busy: stats.workers_size,
      enqueued: queue.size,
      scheduled: stats.scheduled_size,
      retries: stats.retry_size,
      dead: stats.dead_size,
      failed_total: stats.failed,
      processed_total: stats.processed
    }
  rescue StandardError => e
    { status: 'error', error: e.message }
  end

  def check_twilio_credentials
    creds = AppConfig.twilio_credentials

    if creds.nil?
      return {
        status: 'warning',
        configured: false,
        message: 'No credentials configured'
      }
    end

    {
      status: 'ok',
      configured: true,
      source: creds[:source]
    }
  rescue StandardError => e
    { status: 'error', error: e.message }
  end

  def check_circuit_breakers
    return { status: 'ok', message: 'Not configured' } unless defined?(CircuitBreakerService)

    states = CircuitBreakerService.all_states
    open_circuits = states.select { |_, data| data[:state] == :open }

    if open_circuits.any?
      {
        status: 'warning',
        open_circuits: open_circuits.keys,
        total_services: states.count,
        healthy_services: states.count - open_circuits.count
      }
    else
      {
        status: 'ok',
        total_services: states.count,
        all_healthy: true
      }
    end
  rescue StandardError => e
    { status: 'error', error: e.message }
  end

  def sidekiq_stats
    require 'sidekiq/api'

    stats = Sidekiq::Stats.new

    {
      processed: stats.processed,
      failed: stats.failed,
      enqueued: stats.enqueued,
      scheduled: stats.scheduled_size,
      retry: stats.retry_size,
      dead: stats.dead_size,
      processes: stats.processes_size,
      workers: stats.workers_size
    }
  rescue StandardError => e
    { error: e.message }
  end

  def memory_usage
    # Get memory from /proc on Linux, or ps on macOS
    if File.exist?('/proc/self/status')
      # Linux
      status = File.read('/proc/self/status')
      vm_rss = status[/VmRSS:\s+(\d+)/, 1].to_i # in KB
      { rss_mb: (vm_rss / 1024.0).round(1) }
    else
      # macOS/other
      pid = Process.pid
      rss_kb = `ps -o rss= -p #{pid}`.strip.to_i
      { rss_mb: (rss_kb / 1024.0).round(1) }
    end
  rescue StandardError
    { rss_mb: 'unknown' }
  end

  def uptime_seconds
    # Calculate from Rails boot time if available
    if defined?(Rails.application.config.startup_time)
      (Time.current - Rails.application.config.startup_time).to_i
    else
      # Fallback: process uptime
      File.exist?('/proc/self/stat') ? parse_proc_uptime : 'unknown'
    end
  rescue StandardError
    'unknown'
  end

  def parse_proc_uptime
    stat = File.read('/proc/self/stat').split
    start_time_ticks = stat[21].to_i
    hertz = 100 # Usually 100 on Linux
    system_uptime = File.read('/proc/uptime').split.first.to_f
    process_start = start_time_ticks.to_f / hertz
    (system_uptime - process_start).to_i
  rescue StandardError
    'unknown'
  end
end
