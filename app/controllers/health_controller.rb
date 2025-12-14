# Health Check Controller
# Provides detailed health status for monitoring and alerting systems

class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  # Basic health check - fast response
  def show
    render json: { status: 'ok', timestamp: Time.current.iso8601 }
  end
  
  # Detailed health check - includes dependencies
  def detailed
    health_status = {
      status: 'ok',
      timestamp: Time.current.iso8601,
      environment: Rails.env,
      version: app_version,
      checks: {}
    }
    
    # Database check
    health_status[:checks][:database] = check_database
    
    # Redis check
    health_status[:checks][:redis] = check_redis
    
    # Sidekiq check
    health_status[:checks][:sidekiq] = check_sidekiq
    
    # Twilio credentials check
    health_status[:checks][:twilio_credentials] = check_twilio_credentials
    
    # Disk space check (if needed)
    # health_status[:checks][:disk_space] = check_disk_space
    
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
    start_time = Time.current
    ActiveRecord::Base.connection.execute('SELECT 1')
    response_time = ((Time.current - start_time) * 1000).round(2)  # in ms
    
    {
      status: 'ok',
      response_time_ms: response_time,
      pool_size: ActiveRecord::Base.connection_pool.size,
      active_connections: ActiveRecord::Base.connection_pool.connections.size
    }
  rescue StandardError => e
    {
      status: 'error',
      error: e.message
    }
  end
  
  def check_redis
    start_time = Time.current
    redis = Redis.new(url: AppConfig.redis_url)
    begin
      redis.ping
      response_time = ((Time.current - start_time) * 1000).round(2)  # in ms
      
      {
        status: 'ok',
        response_time_ms: response_time,
        connected_clients: redis.info['connected_clients'],
        used_memory_human: redis.info['used_memory_human']
      }
    ensure
      redis.close
    end
  rescue StandardError => e
    {
      status: 'error',
      error: e.message
    }
  end
  
  def check_sidekiq
    require 'sidekiq/api'
    
    stats = Sidekiq::Stats.new
    queue = Sidekiq::Queue.new
    
    status = 'ok'
    status = 'warning' if stats.failed > 100
    status = 'error' if stats.processes_size == 0
    
    {
      status: status,
      processes: stats.processes_size,
      busy: stats.workers_size,
      enqueued: queue.size,
      scheduled: stats.scheduled_size,
      retries: stats.retry_size,
      dead: stats.dead_size,
      failed: stats.failed
    }
  rescue StandardError => e
    {
      status: 'error',
      error: e.message
    }
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
    {
      status: 'error',
      error: e.message
    }
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
  
  def app_version
    # Try to get version from git
    begin
      `git rev-parse --short HEAD 2>/dev/null`.strip.presence || 'unknown'
    rescue StandardError => e
      'unknown'
    end
  end
end

