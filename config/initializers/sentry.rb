# frozen_string_literal: true

# Sentry Error Tracking Configuration
# Production error visibility - Critical for observability
#
# Setup:
#   1. Create a Sentry project at https://sentry.io
#   2. Set SENTRY_DSN environment variable with your project DSN
#   3. Optionally set SENTRY_ENVIRONMENT (defaults to Rails.env)
#
if ENV['SENTRY_DSN'].present?
  Sentry.init do |config|
    # DSN from environment variable - required for Sentry to work
    config.dsn = ENV['SENTRY_DSN']

    # Only enable in production/staging by default
    config.enabled_environments = %w[production staging]

    # Breadcrumbs for debugging context
    config.breadcrumbs_logger = %i[active_support_logger http_logger]

    # Performance monitoring (optional, set SENTRY_TRACES_SAMPLE_RATE)
    config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f

    # Release version for tracking deployments
    config.release = ENV.fetch('HEROKU_SLUG_COMMIT', nil) ||
                     ENV.fetch('RENDER_GIT_COMMIT', nil) ||
                     `git rev-parse HEAD 2>/dev/null`.strip.presence

    # Environment name
    config.environment = ENV.fetch('SENTRY_ENVIRONMENT', Rails.env)

    # Filter sensitive parameters
    config.before_send = lambda do |event, _hint|
      # Scrub sensitive data from events
      event.request.data = '[FILTERED]' if event.request&.data.present?
      event
    end

    # Ignore common non-actionable errors
    config.excluded_exceptions += [
      'ActionController::RoutingError',
      'ActiveRecord::RecordNotFound',
      'ActionController::InvalidAuthenticityToken'
    ]

    # Capture user context when available
    config.set_user do
      # Hook into current_admin_user if available (ActiveAdmin)
      if defined?(current_admin_user) && current_admin_user
        {
          id: current_admin_user.id,
          email: current_admin_user.email
        }
      end
    end
  end
end
