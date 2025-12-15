# frozen_string_literal: true

# CircuitBreakerService - Provides circuit breaker protection for external API calls
#
# This service uses the Stoplight gem to implement the circuit breaker pattern,
# preventing cascade failures when external APIs are down or slow.
#
# Circuit Breaker States:
# - CLOSED: Normal operation, requests pass through
# - OPEN: Too many failures, requests fail fast without hitting API
# - HALF_OPEN: Testing if API recovered, limited requests allowed
#
# Usage:
#   CircuitBreakerService.call(:clearbit) do
#     HTTParty.get('https://company.clearbit.com/v1/domains/find', ...)
#   end
#
# Configuration:
#   SERVICES hash defines per-service thresholds and timeouts
#   - threshold: Number of failures before opening circuit
#   - timeout: Seconds to wait before trying again (half-open state)
#
class CircuitBreakerService
  # Circuit breaker configuration for critical external APIs
  # Add new services here as needed
  SERVICES = {
    # Core APIs
    twilio: {
      threshold: 5,      # Allow 5 failures before opening
      timeout: 60,       # Wait 60s before retry
      description: 'Twilio Lookup API'
    },

    # Business Intelligence
    clearbit: {
      threshold: 3,      # More sensitive (paid API)
      timeout: 30,       # Faster recovery attempt
      description: 'Clearbit Company API'
    },
    numverify: {
      threshold: 3,
      timeout: 30,
      description: 'NumVerify Phone Intelligence'
    },

    # Email Discovery
    hunter: {
      threshold: 3,
      timeout: 30,
      description: 'Hunter.io Email Discovery'
    },
    zerobounce: {
      threshold: 3,
      timeout: 30,
      description: 'ZeroBounce Email Verification'
    },

    # Address/Location APIs
    whitepages: {
      threshold: 3,
      timeout: 30,
      description: 'Whitepages Pro Address Lookup'
    },
    truecaller: {
      threshold: 3,
      timeout: 30,
      description: 'TrueCaller Address Lookup'
    },

    # AI/LLM APIs
    openai: {
      threshold: 5,      # Higher threshold for AI (transient errors common)
      timeout: 90,       # Longer timeout for AI recovery
      description: 'OpenAI API'
    },
    anthropic: {
      threshold: 5,
      timeout: 90,
      description: 'Anthropic Claude API'
    },
    google_ai: {
      threshold: 5,
      timeout: 90,
      description: 'Google Gemini API'
    },

    # Other APIs
    verizon: {
      threshold: 3,
      timeout: 60,
      description: 'Verizon Coverage API'
    },
    google_places: {
      threshold: 3,
      timeout: 30,
      description: 'Google Places API'
    },
    yelp: {
      threshold: 3,
      timeout: 30,
      description: 'Yelp Fusion API'
    }
  }.freeze

  #
  # Execute block with circuit breaker protection
  #
  # @param service_name [Symbol] Name of service (must be in SERVICES hash)
  # @param block [Block] Code to execute (API call)
  # @return [Object] Result of block execution, or fallback on circuit open
  #
  def self.call(service_name, &block)
    config = SERVICES[service_name]

    unless config
      Rails.logger.warn "Unknown circuit breaker service: #{service_name}. Add to SERVICES hash."
      # If service not configured, execute without circuit breaker
      return yield
    end

    # Create Stoplight circuit breaker
    light = Stoplight("#{service_name}_api", &block)
            .with_threshold(config[:threshold])
            .with_timeout(config[:timeout])
            .with_error_handler { |error, handle| log_error(service_name, error, handle) }
            .with_fallback { |error| handle_circuit_open(service_name, error) }

    # Use Redis data store if available (for persistence across workers)
    light = light.with_data_store(Stoplight::DataStore::Redis.new(Redis.current)) if defined?(Redis) && Redis.current

    # Execute with circuit breaker protection
    light.run
  rescue Stoplight::Error::RedLight => e
    # Circuit is open, use fallback
    handle_circuit_open(service_name, e)
  end

  #
  # Get current state of a circuit
  #
  # @param service_name [Symbol] Service to check
  # @return [Symbol] :green (closed), :yellow (half_open), :red (open)
  #
  def self.state(service_name)
    return :unknown unless SERVICES[service_name]

    light = Stoplight("#{service_name}_api") { nil }

    light = light.with_data_store(Stoplight::DataStore::Redis.new(Redis.current)) if defined?(Redis) && Redis.current

    state = light.color

    case state
    when 'green' then :closed
    when 'yellow' then :half_open
    when 'red' then :open
    else :unknown
    end
  end

  #
  # Get all circuit states
  #
  # @return [Hash] Service name => state hash
  #
  def self.all_states
    SERVICES.keys.each_with_object({}) do |service_name, states|
      light = Stoplight("#{service_name}_api") { nil }

      light = light.with_data_store(Stoplight::DataStore::Redis.new(Redis.current)) if defined?(Redis) && Redis.current

      states[service_name] = {
        state: state(service_name),
        color: light.color,
        failures: light.data_store.get_failures(light),
        description: SERVICES[service_name][:description],
        threshold: SERVICES[service_name][:threshold],
        timeout: SERVICES[service_name][:timeout]
      }
    end
  end

  #
  # Manually close a circuit (reset failures)
  #
  # @param service_name [Symbol] Service to reset
  #
  def self.reset(service_name)
    return false unless SERVICES[service_name]

    light = Stoplight("#{service_name}_api") { nil }

    light = light.with_data_store(Stoplight::DataStore::Redis.new(Redis.current)) if defined?(Redis) && Redis.current

    light.data_store.clear_failures(light)
    Rails.logger.info "Circuit breaker RESET for #{service_name}"
    true
  end

  #
  # Manually open a circuit (force failures)
  #
  # @param service_name [Symbol] Service to open
  #
  def self.open_circuit(service_name)
    return false unless SERVICES[service_name]

    light = Stoplight("#{service_name}_api") { nil }

    light = light.with_data_store(Stoplight::DataStore::Redis.new(Redis.current)) if defined?(Redis) && Redis.current

    # Record enough failures to open circuit
    config = SERVICES[service_name]
    (config[:threshold] + 1).times do
      light.data_store.record_failure(light, StandardError.new('Manual circuit open'))
    end

    Rails.logger.warn "Circuit breaker MANUALLY OPENED for #{service_name}"
    true
  end

  private

  #
  # Log circuit breaker errors
  #
  def self.log_error(service_name, error, handle)
    config = SERVICES[service_name]

    case handle
    when :failure
      Rails.logger.warn "Circuit breaker failure for #{service_name}: #{error.class} - #{error.message}"
    when :open
      Rails.logger.error "Circuit breaker OPENED for #{service_name} (#{config[:description]}): #{error.class}"
    when :close
      Rails.logger.info "Circuit breaker CLOSED for #{service_name} (recovered)"
    end
  end

  #
  # Fallback handler when circuit is open
  # Returns error hash instead of raising exception
  #
  def self.handle_circuit_open(service_name, error)
    config = SERVICES[service_name]

    Rails.logger.warn "Circuit breaker OPEN: #{service_name} (#{config[:description]}) temporarily unavailable. " \
                     "Will retry in #{config[:timeout]}s. Error: #{error.message}"

    # Return error hash instead of raising exception
    # This allows graceful degradation in enrichment services
    {
      error: "#{config[:description]} temporarily unavailable",
      circuit_open: true,
      service: service_name,
      retry_after: config[:timeout],
      fallback: true
    }
  end
end
