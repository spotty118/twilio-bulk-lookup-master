# Application Configuration
# Centralized configuration for the Twilio Bulk Lookup application

module AppConfig
  # Twilio API Configuration
  TWILIO_LOOKUP_COST_PER_REQUEST = 0.005  # $0.005 per lookup (update as needed)
  TWILIO_RATE_LIMIT_PER_SECOND = 25       # Conservative rate limit
  
  # Processing Configuration
  MAX_RETRY_ATTEMPTS = 3
  RETRY_BASE_DELAY = 15.seconds
  JOB_TIMEOUT = 30.seconds
  
  # Batch Processing
  BATCH_SIZE = 100                         # Process contacts in batches
  MAX_CONCURRENT_JOBS = ENV.fetch('SIDEKIQ_CONCURRENCY', 5).to_i
  
  # Cache Configuration
  CREDENTIALS_CACHE_TTL = 1.hour
  STATS_CACHE_TTL = 5.minutes
  
  # Cleanup Configuration
  OLD_CONTACTS_THRESHOLD = 90.days         # Age threshold for cleanup
  STUCK_PROCESSING_THRESHOLD = 1.hour      # Time before considering a job stuck
  
  # Export Configuration
  EXPORT_FORMATS = %w[csv tsv xlsx].freeze
  MAX_EXPORT_ROWS = 100_000                # Safety limit for exports
  
  # Monitoring & Alerts
  ENABLE_ERROR_NOTIFICATIONS = ENV.fetch('ENABLE_ERROR_NOTIFICATIONS', false)
  ALERT_THRESHOLD_FAILED_PERCENTAGE = 10   # Alert if >10% of jobs fail
  
  # Security
  PASSWORD_MIN_LENGTH = 8
  SESSION_TIMEOUT = 24.hours
  MAX_LOGIN_ATTEMPTS = 5
  
  # Feature Flags
  ENABLE_PHONE_VALIDATION = ENV.fetch('ENABLE_PHONE_VALIDATION', true)
  ENABLE_AUTO_RETRY = ENV.fetch('ENABLE_AUTO_RETRY', true)
  ENABLE_COST_TRACKING = ENV.fetch('ENABLE_COST_TRACKING', false)
  
  # Environment Checks
  def self.production?
    Rails.env.production?
  end
  
  def self.development?
    Rails.env.development?
  end
  
  def self.test?
    Rails.env.test?
  end
  
  # Sidekiq Configuration
  def self.sidekiq_concurrency
    if production?
      ENV.fetch('SIDEKIQ_CONCURRENCY', 10).to_i
    else
      ENV.fetch('SIDEKIQ_CONCURRENCY', 2).to_i
    end
  end
  
  # Redis URL
  def self.redis_url
    ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  end
  
  # Database Pool Size
  def self.db_pool_size
    # Should be >= sidekiq_concurrency + web workers
    sidekiq_concurrency + 5
  end
  
  # Twilio Credentials Source Priority:
  # 1. Environment Variables (Production)
  # 2. Rails Encrypted Credentials
  # 3. Database (Development Only)
  def self.twilio_credentials
    if ENV['TWILIO_ACCOUNT_SID'].present? && ENV['TWILIO_AUTH_TOKEN'].present?
      {
        account_sid: ENV['TWILIO_ACCOUNT_SID'],
        auth_token: ENV['TWILIO_AUTH_TOKEN'],
        source: :environment
      }
    elsif Rails.application.credentials.dig(:twilio, :account_sid).present?
      {
        account_sid: Rails.application.credentials.dig(:twilio, :account_sid),
        auth_token: Rails.application.credentials.dig(:twilio, :auth_token),
        source: :encrypted_credentials
      }
    elsif defined?(TwilioCredential)
      cred = TwilioCredential.current
      if cred
        {
          account_sid: cred.account_sid,
          auth_token: cred.auth_token,
          source: :database
        }
      end
    end
  end
  
  # Cost Calculation
  def self.estimated_cost(contact_count)
    (contact_count * TWILIO_LOOKUP_COST_PER_REQUEST).round(2)
  end
  
  # Estimated Processing Time
  def self.estimated_processing_time(contact_count)
    # Accounts for concurrency and rate limits
    jobs_per_second = [MAX_CONCURRENT_JOBS, TWILIO_RATE_LIMIT_PER_SECOND].min
    seconds = (contact_count.to_f / jobs_per_second).ceil
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    
    if hours > 0
      "~#{hours}h #{minutes}m"
    elsif minutes > 0
      "~#{minutes}m #{secs}s"
    else
      "~#{secs}s"
    end
  end
end

# Log configuration on startup
Rails.application.configure do
  config.after_initialize do
    Rails.logger.info "="*60
    Rails.logger.info "Twilio Bulk Lookup Configuration"
    Rails.logger.info "="*60
    Rails.logger.info "Environment: #{Rails.env}"
    Rails.logger.info "Sidekiq Concurrency: #{AppConfig.sidekiq_concurrency}"
    Rails.logger.info "Database Pool: #{AppConfig.db_pool_size}"
    Rails.logger.info "Redis URL: #{AppConfig.redis_url}"
    
    creds = AppConfig.twilio_credentials
    if creds
      Rails.logger.info "Twilio Credentials: #{creds[:source]}"
      Rails.logger.info "Account SID: #{creds[:account_sid][0..5]}***#{creds[:account_sid][-4..]}"
    else
      Rails.logger.warn "⚠️  Twilio Credentials: NOT CONFIGURED"
    end
    
    Rails.logger.info "="*60
  end
end

