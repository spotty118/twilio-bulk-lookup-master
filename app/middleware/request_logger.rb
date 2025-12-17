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

      @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      @parameter_filter.filter(params)
    end
  end
end
