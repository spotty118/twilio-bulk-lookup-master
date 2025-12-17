# frozen_string_literal: true

if Rails.env.development?
  require 'rack-mini-profiler'

  # Initialize Rack Mini Profiler
  Rack::MiniProfilerRails.initialize!(Rails.application)

  # Configuration
  Rack::MiniProfiler.config.position = 'bottom-right'
  Rack::MiniProfiler.config.start_hidden = false

  # Do not profile assets or health checks
  Rack::MiniProfiler.config.skip_paths ||= []
  Rack::MiniProfiler.config.skip_paths << '/health'
  Rack::MiniProfiler.config.skip_paths << '/up'
  Rack::MiniProfiler.config.skip_paths << '/assets'
end
