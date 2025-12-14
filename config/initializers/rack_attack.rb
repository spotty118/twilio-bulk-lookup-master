# frozen_string_literal: true

# Rack::Attack Configuration - Rate Limiting for Public Endpoints
#
# Protects against DoS attacks, credential stuffing, and webhook replay floods
# Uses Redis (via Rails.cache) for distributed rate limiting across servers

class Rack::Attack
  # Use Rails cache (Redis) for counter storage
  Rack::Attack.cache.store = Rails.cache

  # Webhook endpoints: 100 req/min per IP
  throttle('webhooks/ip', limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/webhooks/')
  end

  # Health checks: 60 req/min per IP
  throttle('health/ip', limit: 60, period: 1.minute) do |req|
    req.ip if req.path.match?(/\/(health|up)/)
  end

  # Admin login: 5 failed attempts per 20 min per email
  throttle('admin_login/email', limit: 5, period: 20.minutes) do |req|
    if req.path == '/admin_users/sign_in' && req.post?
      req.params['admin_user']&.[]('email')&.to_s&.downcase&.presence
    end
  end

  # General API: 300 req/5min per IP
  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets', '/packs', '/favicon')
  end

  # Block suspicious user agents on webhooks
  blocklist('block scanners') do |req|
    suspicious = %w[masscan nmap nikto sqlmap metasploit burp acunetix]
    user_agent = req.user_agent.to_s.downcase
    req.path.start_with?('/webhooks/') && suspicious.any? { |s| user_agent.include?(s) }
  end

  # Custom 429 response with Retry-After header
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])

    [429, { 'Content-Type' => 'application/json', 'Retry-After' => retry_after.to_s },
     [{ error: 'Rate limit exceeded', retry_after_seconds: retry_after }.to_json]]
  end

  # Logging for security monitoring
  ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn("[Rack::Attack] Throttled: #{req.ip} #{req.request_method} #{req.fullpath}")
  end

  ActiveSupport::Notifications.subscribe('blocklist.rack_attack') do |_name, _start, _finish, _id, payload|
    req = payload[:request]
    Rails.logger.warn("[Rack::Attack] Blocked: #{req.ip} #{req.request_method} #{req.fullpath}")
  end
end

# Enable in production/staging only
if Rails.env.production? || Rails.env.staging?
  Rails.application.config.middleware.use Rack::Attack
  Rails.logger.info('Rack::Attack enabled')
end
