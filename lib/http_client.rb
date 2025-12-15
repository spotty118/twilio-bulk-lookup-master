require 'net/http'
require 'json'

# Centralized HTTP client with consistent timeout configuration
# and optional circuit breaker for external API resilience
#
# Usage:
#   response = HttpClient.get(uri) do |request|
#     request['Authorization'] = "Bearer #{api_key}"
#   end
#
# With circuit breaker:
#   response = HttpClient.get(uri, circuit_name: 'clearbit-api') do |request|
#     request['Authorization'] = "Bearer #{api_key}"
#   end
#
class HttpClient
  class TimeoutError < StandardError; end
  class CircuitOpenError < StandardError; end

  # Conservative timeouts for external APIs
  # - read_timeout: Max time waiting for response data
  # - open_timeout: Max time establishing connection
  # - connect_timeout: Max time for socket connection
  DEFAULT_TIMEOUTS = {
    read_timeout: 10,
    open_timeout: 5,
    connect_timeout: 5
  }.freeze

  # Circuit breaker state (distributed via Rails.cache/Redis)
  # Shared across all Sidekiq workers/processes for consistent behavior
  # State expires automatically after 5 minutes of inactivity
  CIRCUIT_CACHE_PREFIX = 'circuit_breaker'
  CIRCUIT_STATE_TTL = 5.minutes

  # Perform GET request with automatic timeout configuration
  #
  # @param uri [URI] The URI to request
  # @param circuit_name [String, nil] Optional circuit breaker name
  # @param options [Hash] Override timeout values
  # @yield [Net::HTTP::Get] Configure request headers
  # @return [Net::HTTPResponse]
  # @raise [TimeoutError] If request times out
  # @raise [CircuitOpenError] If circuit breaker is open
  #
  def self.get(uri, circuit_name: nil, **options)
    check_circuit!(circuit_name) if circuit_name

    response = Net::HTTP.start(uri.hostname, uri.port,
                                use_ssl: uri.scheme == 'https',
                                **DEFAULT_TIMEOUTS.merge(options)) do |http|
      request = Net::HTTP::Get.new(uri)
      yield(request) if block_given?
      http.request(request)
    end

    record_success(circuit_name) if circuit_name
    response
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    record_failure(circuit_name) if circuit_name
    raise TimeoutError, "HTTP request timed out: #{e.message}"
  end

  # Perform POST request with automatic timeout configuration
  #
  # @param uri [URI] The URI to request
  # @param body [String, Hash] Request body (Hash auto-converted to JSON)
  # @param circuit_name [String, nil] Optional circuit breaker name
  # @param options [Hash] Override timeout values
  # @yield [Net::HTTP::Post] Configure request headers
  # @return [Net::HTTPResponse]
  #
  def self.post(uri, body:, circuit_name: nil, **options)
    check_circuit!(circuit_name) if circuit_name

    response = Net::HTTP.start(uri.hostname, uri.port,
                                use_ssl: uri.scheme == 'https',
                                **DEFAULT_TIMEOUTS.merge(options)) do |http|
      request = Net::HTTP::Post.new(uri)
      request.body = body.is_a?(Hash) ? body.to_json : body
      request['Content-Type'] = 'application/json' if body.is_a?(Hash)
      yield(request) if block_given?
      http.request(request)
    end

    record_success(circuit_name) if circuit_name
    response
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    record_failure(circuit_name) if circuit_name
    raise TimeoutError, "HTTP request timed out: #{e.message}"
  end

  # Perform PATCH request with automatic timeout configuration
  #
  # @param uri [URI] The URI to request
  # @param body [String, Hash] Request body (Hash auto-converted to JSON)
  # @param circuit_name [String, nil] Optional circuit breaker name
  # @param options [Hash] Override timeout values
  # @yield [Net::HTTP::Patch] Configure request headers
  # @return [Net::HTTPResponse]
  #
  def self.patch(uri, body:, circuit_name: nil, **options)
    check_circuit!(circuit_name) if circuit_name

    response = Net::HTTP.start(uri.hostname, uri.port,
                                use_ssl: uri.scheme == 'https',
                                **DEFAULT_TIMEOUTS.merge(options)) do |http|
      request = Net::HTTP::Patch.new(uri)
      request.body = body.is_a?(Hash) ? body.to_json : body
      request['Content-Type'] = 'application/json' if body.is_a?(Hash)
      yield(request) if block_given?
      http.request(request)
    end

    record_success(circuit_name) if circuit_name
    response
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    record_failure(circuit_name) if circuit_name
    raise TimeoutError, "HTTP request timed out: #{e.message}"
  end

  # Perform PUT request with automatic timeout configuration
  #
  # @param uri [URI] The URI to request
  # @param body [String, Hash] Request body (Hash auto-converted to JSON)
  # @param circuit_name [String, nil] Optional circuit breaker name
  # @param options [Hash] Override timeout values
  # @yield [Net::HTTP::Put] Configure request headers
  # @return [Net::HTTPResponse]
  #
  def self.put(uri, body:, circuit_name: nil, **options)
    check_circuit!(circuit_name) if circuit_name

    response = Net::HTTP.start(uri.hostname, uri.port,
                                use_ssl: uri.scheme == 'https',
                                **DEFAULT_TIMEOUTS.merge(options)) do |http|
      request = Net::HTTP::Put.new(uri)
      request.body = body.is_a?(Hash) ? body.to_json : body
      request['Content-Type'] = 'application/json' if body.is_a?(Hash)
      yield(request) if block_given?
      http.request(request)
    end

    record_success(circuit_name) if circuit_name
    response
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    record_failure(circuit_name) if circuit_name
    raise TimeoutError, "HTTP request timed out: #{e.message}"
  end

  private

  # Check if circuit breaker is open (too many recent failures)
  def self.check_circuit!(name)
    open_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:open"
    state = Rails.cache.read(open_key)

    return unless state&.[](:open)

    # Auto-close circuit after cool-off period
    if Time.current > state[:open_until]
      Rails.cache.delete(open_key)
      Rails.logger.info(
        event: 'circuit_breaker_auto_closed',
        circuit_name: name,
        reason: 'cooldown_period_expired',
        timestamp: Time.current.iso8601
      )
    else
      seconds_until_retry = (state[:open_until] - Time.current).to_i
      raise CircuitOpenError, "Circuit #{name} is open (retry in #{seconds_until_retry}s)"
    end
  end

  # Record successful request (resets failure count)
  # Deletes circuit state from Redis to free memory and allow immediate retries
  def self.record_success(name)
    failures_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:failures"
    open_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:open"

    # Check if circuit was open before we reset it
    was_open = Rails.cache.read(open_key).present?
    previous_failures = Rails.cache.read(failures_key) || 0

    Rails.cache.delete(failures_key)
    Rails.cache.delete(open_key)

    # Log when circuit transitions from open to closed (recovery event)
    if was_open
      Rails.logger.info(
        event: 'circuit_breaker_closed',
        circuit_name: name,
        reason: 'successful_request_after_open',
        previous_failures: previous_failures,
        timestamp: Time.current.iso8601
      )

      # Optional: Instrument for metrics aggregation
      ActiveSupport::Notifications.instrument(
        'circuit_breaker.closed',
        circuit_name: name,
        recovery_time: Time.current
      )
    end
  end

  # Record failed request (opens circuit after threshold)
  # Uses Rails.cache.increment with atomic increments
  def self.record_failure(name)
    cache_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:failures"
    open_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:open"

    # Atomic increment supported by Redis/Memcached
    failures = Rails.cache.increment(cache_key, 1, expires_in: CIRCUIT_STATE_TTL)

    # Handle case where key didn't exist (returns nil or 1 depending on store, but usually 1 if initialized)
    # If using Redis store, increment initializes to 0 if missing then adds 1.
    # We ensure it's at least 1.
    failures ||= 1

    # Open circuit after 5 consecutive failures
    if failures >= 5
      # Set open state
      open_until = Time.current + 60.seconds
      Rails.cache.write(open_key, { open: true, open_until: open_until }, expires_in: 60.seconds)

      # Structured logging for circuit breaker activation
      Rails.logger.warn(
        event: 'circuit_breaker_opened',
        circuit_name: name,
        consecutive_failures: failures,
        cooldown_seconds: 60,
        open_until: open_until.iso8601,
        timestamp: Time.current.iso8601
      )

      # Optional: Instrument for metrics/alerting
      ActiveSupport::Notifications.instrument(
        'circuit_breaker.opened',
        circuit_name: name,
        failures: failures,
        cooldown_seconds: 60
      )
    elsif failures > 1
      # Log accumulating failures (helps detect patterns before circuit opens)
      Rails.logger.debug(
        event: 'circuit_breaker_failure_accumulating',
        circuit_name: name,
        consecutive_failures: failures,
        threshold: 5,
        timestamp: Time.current.iso8601
      )
    end
  end

  # Get circuit state for monitoring/debugging
  # Returns state from Redis cache for specific circuit or all circuits
  def self.circuit_state(name = nil)
    if name
      cache_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:failures"
      open_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:open"
      {
        failures: Rails.cache.read(cache_key),
        open: Rails.cache.read(open_key)
      }
    else
      # Return all circuit states (expensive - for debugging only)
      # Note: This requires iterating Redis keys, not efficient at scale
      all_states = {}
      Rails.cache.instance_variable_get(:@data)&.keys&.each do |key|
        if key.to_s.start_with?(CIRCUIT_CACHE_PREFIX)
          circuit_name = key.to_s.sub("#{CIRCUIT_CACHE_PREFIX}:", '')
          all_states[circuit_name] = {
            failures: Rails.cache.read("#{CIRCUIT_CACHE_PREFIX}:#{circuit_name}:failures"),
            open: Rails.cache.read("#{CIRCUIT_CACHE_PREFIX}:#{circuit_name}:open")
          }
        end
      end
      all_states
    end
  end

  # Manually reset circuit (for admin intervention)
  # Removes circuit state from Redis, allowing immediate retry
  def self.reset_circuit!(name)
    Rails.cache.delete("#{CIRCUIT_CACHE_PREFIX}:#{name}:failures")
    Rails.cache.delete("#{CIRCUIT_CACHE_PREFIX}:#{name}:open")
    Rails.logger.info("Circuit #{name} manually reset")
  end
end
