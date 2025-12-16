require 'net/http'
require 'json'
require 'securerandom'

# Centralized HTTP client with:
# - Connection pooling (keep-alive for better performance)
# - Consistent timeout configuration
# - Circuit breaker integration
# - Request ID tracking for debugging
# - API version headers
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

  # Application identity for API requests
  APP_NAME = 'TwilioBulkLookup'.freeze
  APP_VERSION = '2.1.1'.freeze
  USER_AGENT = "#{APP_NAME}/#{APP_VERSION} (Ruby/#{RUBY_VERSION})".freeze

  # Conservative timeouts for external APIs
  # - read_timeout: Max time waiting for response data
  # - open_timeout: Max time establishing connection
  # - connect_timeout: Max time for socket connection
  # - keep_alive_timeout: Max time to wait for reuse
  DEFAULT_TIMEOUTS = {
    read_timeout: 10,
    open_timeout: 5,
    connect_timeout: 5,
    keep_alive_timeout: 30
  }.freeze

  # Connection pool settings
  # Keep connections alive for reuse across requests
  CONNECTION_POOL = Concurrent::Map.new

  # Circuit breaker state (distributed via Rails.cache/Redis)
  CIRCUIT_CACHE_PREFIX = 'circuit_breaker'.freeze
  CIRCUIT_STATE_TTL = 5.minutes
  CIRCUIT_FAILURE_THRESHOLD = 5
  CIRCUIT_COOLOFF_SECONDS = 60

  class << self
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
    def get(uri, circuit_name: nil, **options)
      execute_request(:get, uri, circuit_name: circuit_name, **options) do |request|
        yield(request) if block_given?
      end
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
    def post(uri, body:, circuit_name: nil, **options)
      execute_request(:post, uri, body: body, circuit_name: circuit_name, **options) do |request|
        yield(request) if block_given?
      end
    end

    # Perform PATCH request with automatic timeout configuration
    def patch(uri, body:, circuit_name: nil, **options)
      execute_request(:patch, uri, body: body, circuit_name: circuit_name, **options) do |request|
        yield(request) if block_given?
      end
    end

    # Perform PUT request with automatic timeout configuration
    def put(uri, body:, circuit_name: nil, **options)
      execute_request(:put, uri, body: body, circuit_name: circuit_name, **options) do |request|
        yield(request) if block_given?
      end
    end

    # Perform DELETE request
    def delete(uri, circuit_name: nil, **options)
      execute_request(:delete, uri, circuit_name: circuit_name, **options) do |request|
        yield(request) if block_given?
      end
    end

    # Get circuit state for monitoring/debugging
    def circuit_state(name = nil)
      if name
        {
          failures: Rails.cache.read("#{CIRCUIT_CACHE_PREFIX}:#{name}:failures"),
          open: Rails.cache.read("#{CIRCUIT_CACHE_PREFIX}:#{name}:open")
        }
      else
        {}
      end
    end

    # Manually reset circuit (for admin intervention)
    def reset_circuit!(name)
      Rails.cache.delete("#{CIRCUIT_CACHE_PREFIX}:#{name}:failures")
      Rails.cache.delete("#{CIRCUIT_CACHE_PREFIX}:#{name}:open")
      Rails.logger.info("[HttpClient] Circuit #{name} manually reset")
    end

    # Clear connection pool (for graceful shutdown)
    def clear_connections!
      CONNECTION_POOL.each_value(&:finish)
      CONNECTION_POOL.clear
      Rails.logger.info('[HttpClient] Connection pool cleared')
    end

    private

    # Unified request execution with connection reuse
    def execute_request(method, uri, body: nil, circuit_name: nil, **options)
      request_id = generate_request_id
      check_circuit!(circuit_name) if circuit_name

      http = get_connection(uri, options)
      request = build_request(method, uri, body, request_id)
      yield(request) if block_given?

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = http.request(request)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

      log_request(method, uri, response.code, duration_ms, request_id)
      record_success(circuit_name) if circuit_name

      response
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      record_failure(circuit_name) if circuit_name
      Rails.logger.error("[HttpClient] Timeout: #{method.upcase} #{uri} (#{request_id}): #{e.message}")
      raise TimeoutError, "HTTP request timed out: #{e.message}"
    rescue IOError, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED => e
      record_failure(circuit_name) if circuit_name
      # Remove stale connection from pool
      pool_key = connection_pool_key(uri)
      CONNECTION_POOL.delete(pool_key)
      Rails.logger.error("[HttpClient] Connection error: #{method.upcase} #{uri} (#{request_id}): #{e.message}")
      raise TimeoutError, "HTTP connection error: #{e.message}"
    end

    # Get or create connection from pool
    def get_connection(uri, options)
      pool_key = connection_pool_key(uri)
      timeouts = DEFAULT_TIMEOUTS.merge(options.slice(:read_timeout, :open_timeout, :connect_timeout,
                                                      :keep_alive_timeout))

      # Check for existing connection
      existing = CONNECTION_POOL[pool_key]
      return existing if existing&.active?

      # Create new connection with keep-alive
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = timeouts[:read_timeout]
      http.open_timeout = timeouts[:open_timeout]
      http.keep_alive_timeout = timeouts[:keep_alive_timeout]

      # Enable keep-alive
      http.start

      CONNECTION_POOL[pool_key] = http
      http
    rescue StandardError => e
      Rails.logger.warn("[HttpClient] Failed to create connection to #{uri.host}: #{e.message}")
      raise TimeoutError, "Failed to connect: #{e.message}"
    end

    def connection_pool_key(uri)
      "#{uri.scheme}://#{uri.hostname}:#{uri.port}"
    end

    # Build request with standard headers
    def build_request(method, uri, body, request_id)
      request_class = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        patch: Net::HTTP::Patch,
        put: Net::HTTP::Put,
        delete: Net::HTTP::Delete
      }[method]

      request = request_class.new(uri)

      # Standard headers
      request['User-Agent'] = USER_AGENT
      request['Accept'] = 'application/json'
      request['X-Request-ID'] = request_id
      request['Connection'] = 'keep-alive'

      # Body handling
      if body
        request.body = body.is_a?(Hash) ? body.to_json : body
        request['Content-Type'] = 'application/json' if body.is_a?(Hash)
      end

      request
    end

    def generate_request_id
      "req_#{SecureRandom.hex(8)}"
    end

    def log_request(method, uri, status_code, duration_ms, request_id)
      level = status_code.to_i >= 400 ? :warn : :debug
      Rails.logger.send(level,
                        "[HttpClient] #{method.upcase} #{uri.host}#{uri.path} -> #{status_code} (#{duration_ms}ms) [#{request_id}]")
    end

    # Check if circuit breaker is open
    def check_circuit!(name)
      open_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:open"
      state = Rails.cache.read(open_key)

      return unless state&.[](:open)

      if Time.current > state[:open_until]
        Rails.cache.delete(open_key)
        Rails.logger.info("[HttpClient] Circuit #{name} closed after cool-off period")
      else
        seconds_until_retry = (state[:open_until] - Time.current).to_i
        raise CircuitOpenError, "Circuit #{name} is open (retry in #{seconds_until_retry}s)"
      end
    end

    # Record successful request
    def record_success(name)
      Rails.cache.delete("#{CIRCUIT_CACHE_PREFIX}:#{name}:failures")
      Rails.cache.delete("#{CIRCUIT_CACHE_PREFIX}:#{name}:open")
    end

    # Record failed request
    def record_failure(name)
      cache_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:failures"
      open_key = "#{CIRCUIT_CACHE_PREFIX}:#{name}:open"

      failures = Rails.cache.increment(cache_key, 1, expires_in: CIRCUIT_STATE_TTL) || 1

      return unless failures >= CIRCUIT_FAILURE_THRESHOLD

      open_until = Time.current + CIRCUIT_COOLOFF_SECONDS.seconds
      Rails.cache.write(open_key, { open: true, open_until: open_until }, expires_in: CIRCUIT_COOLOFF_SECONDS.seconds)
      Rails.logger.warn("[HttpClient] Circuit #{name} opened after #{failures} failures (cool-off: #{CIRCUIT_COOLOFF_SECONDS}s)")
    end
  end
end
