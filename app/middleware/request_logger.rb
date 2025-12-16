# frozen_string_literal: true

module Middleware
  class RequestLogger
    def initialize(app)
      @app = app
    end

    def call(env)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      request = Rack::Request.new(env)
      request_id = env['action_dispatch.request_id'] || SecureRandom.uuid

      # Log request start
      log_request_start(request, request_id)

      status, headers, body = @app.call(env)

      # Calculate duration
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      duration_ms = (duration * 1000).round(2)

      # Log request completion
      log_request_completion(request, request_id, status, duration_ms)

      [status, headers, body]
    rescue StandardError => e
      # Log exception usage if it bubbles up
      log_exception(request, request_id, e)
      raise e
    end

    private

    def log_request_start(request, request_id)
      # Skip health check logging to reduce noise if needed, or keep it for completeness
      # return if request.path.start_with?('/health')

      Rails.logger.info(
        method: request.request_method,
        path: request.path,
        params: redact_params(request.params),
        ip: request.ip,
        request_id: request_id,
        event: 'request_started'
      ).to_json
    end

    def log_request_completion(request, request_id, status, duration_ms)
      Rails.logger.info(
        method: request.request_method,
        path: request.path,
        status: status,
        duration_ms: duration_ms,
        request_id: request_id,
        event: 'request_completed'
      ).to_json
    end

    def log_exception(request, request_id, exception)
      Rails.logger.error(
        method: request.request_method,
        path: request.path,
        error: exception.message,
        error_class: exception.class.name,
        request_id: request_id,
        event: 'request_failed'
      ).to_json
    end

    def redact_params(params)
      return {} unless params.is_a?(Hash)

      params.deep_dup.tap do |p|
        filter_sensitive_data(p)
      end
    end

    def filter_sensitive_data(data)
      return unless data.is_a?(Hash)

      data.each do |key, value|
        if sensitive_key?(key)
          data[key] = '[REDACTED]'
        elsif value.is_a?(Hash)
          filter_sensitive_data(value)
        elsif value.is_a?(Array)
          value.each { |item| filter_sensitive_data(item) if item.is_a?(Hash) }
        end
      end
    end

    SENSITIVE_KEYS = %w[
      password token secret key api_key auth_token access_token refresh_token
      authorization bearer credentials account_sid auth_code
      ssn social_security_number tax_id ein passport drivers_license
      credit_card card_number cvv ccv security_code bank_account routing_number
      private_key certificate pem
    ].freeze

    def sensitive_key?(key)
      key_s = key.to_s.downcase
      SENSITIVE_KEYS.any? { |k| key_s.include?(k) }
    end
  end
end
