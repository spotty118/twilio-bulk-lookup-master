class Rack::Attack
  ### Configure Cache ###
  # Use Redis for rate limit tracking (already available in app)
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV['REDIS_URL'] || 'redis://localhost:6379/1'
  )

  ### Throttle Configuration ###

  # General throttle: Limit all requests by IP to prevent abuse
  # Allow 300 requests per 5 minutes per IP
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/assets')
  end

  # Admin login throttle: Prevent brute force login attempts
  # Allow 5 login attempts per 20 seconds per IP
  throttle('admin/logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/admin_users/sign_in' && req.post?
      req.ip
    end
  end

  # Admin login email throttle: Prevent credential stuffing
  # Allow 5 attempts per email per 20 seconds
  throttle('admin/logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/admin_users/sign_in' && req.post?
      # Extract and normalize email from request
      email = req.params.dig('admin_user', 'email')
      email&.downcase&.strip&.presence
    end
  end

  # Lookup endpoint throttle: Prevent API abuse
  # Allow 10 lookup triggers per minute per IP
  throttle('lookup/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path == '/lookup'
  end

  # Sidekiq dashboard access throttle
  # Allow 60 requests per minute per IP (generous for dashboard interaction)
  throttle('sidekiq/ip', limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/sidekiq')
  end

  ### Blocklist Configuration ###

  # Block requests from known bad IPs (can be populated from external source)
  # Example: Rack::Attack::Allow2Ban will automatically blocklist repeat offenders
  blocklist('block/bad-actors') do |req|
    # Add IPs to blocklist
    # Example: Rack::Attack::Fail2Ban.filter("pentesters-#{req.ip}", maxretry: 5, findtime: 10.minutes, bantime: 1.hour) { true }
    false # Disabled by default
  end

  ### Safelist Configuration ###

  # Never throttle localhost (development/health checks)
  safelist('allow/localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  # Allow health check endpoints without throttling
  safelist('allow/health-checks') do |req|
    req.path.start_with?('/health') || req.path == '/up'
  end

  ### Custom Response ###

  # Customize response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env['rack.attack.match_data']
    now = Time.now

    # Calculate when the throttle will reset
    period = match_data[:period]
    limit = match_data[:limit]
    retry_after = (period - (now.to_i % period)).to_i

    headers = {
      'Content-Type' => 'text/plain',
      'Retry-After' => retry_after.to_s,
      'X-RateLimit-Limit' => limit.to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + retry_after).to_i.to_s
    }

    body = "Rate limit exceeded. Try again in #{retry_after} seconds.\n"

    [429, headers, [body]]
  end

  ### Logging ###

  # Log blocked and throttled requests
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]

    if [:throttle, :blocklist].include?(payload[:match_type])
      Rails.logger.warn("[Rack::Attack] #{payload[:match_type].to_s.upcase}: #{req.ip} #{req.request_method} #{req.fullpath} - Matched: #{payload[:matched]}")
    end
  end
end
