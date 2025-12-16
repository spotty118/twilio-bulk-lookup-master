# frozen_string_literal: true

# ErrorTrackingService - Unified error tracking with Sentry integration
#
# Provides structured error logging with consistent categorization,
# stack traces, and optional Sentry reporting.
#
# Usage:
#   ErrorTrackingService.capture(exception, context: { contact_id: 123 })
#   ErrorTrackingService.warn("Rate limit exceeded", tags: { api: :twilio })
#
class ErrorTrackingService
  # Error categories for consistent classification
  CATEGORIES = {
    transient: %w[timeout network rate_limit 503 502 429],
    permanent: %w[invalid_number not_found authentication validation],
    configuration: %w[missing_key no_credentials disabled],
    internal: %w[nil_class undefined_method]
  }.freeze

  class << self
    # Capture an exception with full context
    #
    # @param exception [Exception] The exception to capture
    # @param context [Hash] Additional context (contact_id, job_id, etc.)
    # @param tags [Hash] Tags for categorization
    # @param level [Symbol] :error, :warning, :info
    def capture(exception, context: {}, tags: {}, level: :error)
      category = categorize_exception(exception)

      log_structured(
        level: level,
        category: category,
        exception_class: exception.class.name,
        message: exception.message,
        context: context,
        tags: tags,
        backtrace: exception.backtrace&.first(10)&.join("\n")
      )

      # Report to Sentry if available and not transient
      return unless defined?(Sentry) && category != :transient

      Sentry.capture_exception(exception, extra: context, tags: tags.merge(category: category))
    end

    # Log a warning with structured format
    def warn(message, context: {}, tags: {})
      log_structured(
        level: :warn,
        category: :warning,
        message: message,
        context: context,
        tags: tags
      )
    end

    # Log info with structured format
    def info(message, context: {}, tags: {})
      log_structured(
        level: :info,
        category: :info,
        message: message,
        context: context,
        tags: tags
      )
    end

    # Track a rate limit event
    def track_rate_limit(provider:, retry_after: nil, context: {})
      log_structured(
        level: :warn,
        category: :rate_limit,
        message: "Rate limit exceeded for #{provider}",
        context: context.merge(retry_after: retry_after),
        tags: { provider: provider, rate_limited: true }
      )

      # Optionally report to Sentry as warning
      return unless defined?(Sentry)

      Sentry.capture_message(
        "Rate limit: #{provider}",
        level: :warning,
        extra: context.merge(retry_after: retry_after)
      )
    end

    # Track a circuit breaker event
    def track_circuit_breaker(service:, state:, context: {})
      level = state == :open ? :error : :info

      log_structured(
        level: level,
        category: :circuit_breaker,
        message: "Circuit breaker #{state} for #{service}",
        context: context,
        tags: { service: service, circuit_state: state }
      )

      return unless state == :open && defined?(Sentry)

      Sentry.capture_message(
        "Circuit breaker OPEN: #{service}",
        level: :error,
        extra: context
      )
    end

    private

    def categorize_exception(exception)
      message = exception.message.to_s.downcase

      CATEGORIES.each do |category, keywords|
        return category if keywords.any? { |kw| message.include?(kw) }
      end

      # Default categorization by exception type
      case exception
      when Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
        :transient
      when ArgumentError, TypeError
        :permanent
      when ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
        :permanent
      else
        :unknown
      end
    end

    def log_structured(level:, category:, message:, context: {}, tags: {}, backtrace: nil)
      log_entry = {
        timestamp: Time.current.iso8601,
        level: level.to_s.upcase,
        category: category,
        message: message,
        context: context,
        tags: tags
      }

      log_entry[:backtrace] = backtrace if backtrace.present?

      # Format for structured logging (JSON in production, readable in dev)
      if Rails.env.production?
        Rails.logger.send(level, log_entry.to_json)
      else
        formatted = "[#{level.to_s.upcase}] [#{category}] #{message}"
        formatted += " | context: #{context.inspect}" if context.present?
        formatted += " | tags: #{tags.inspect}" if tags.present?
        formatted += "\n  #{backtrace}" if backtrace.present?
        Rails.logger.send(level, formatted)
      end
    end
  end
end
