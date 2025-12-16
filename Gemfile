source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.6' # Latest stable Ruby version

# Core Rails gems - using Rails 7.2 for better gem compatibility
gem 'bootsnap', '>= 1.18.0', require: false
gem 'pg', '~> 1.5'
gem 'puma', '~> 6.4'
gem 'rails', '~> 7.2.0'
gem 'sprockets-rails' # For asset pipeline

# Authentication and Admin interface
gem 'activeadmin', '~> 3.2'
gem 'active_admin_import', '~> 5.0'
gem 'devise', '~> 4.9'
gem 'inherited_resources', '~> 1.14'
gem 'kaminari', '~> 1.2' # Required by ActiveAdmin
gem 'ransack', '~> 4.2' # Required by ActiveAdmin

# Asset pipeline
gem 'image_processing', '~> 1.13' # For Active Storage variants
gem 'sassc-rails', '~> 2.1' # Modern Sass processor

# API and background jobs
gem 'sidekiq', '~> 7.3'
gem 'twilio-ruby', '~> 7.2' # Updated Twilio SDK

# JSON builder and other utilities
gem 'coffee-rails', '~> 5.0' # For CoffeeScript assets
gem 'jbuilder', '~> 2.13'
gem 'stimulus-rails', '~> 1.3' # For JavaScript interactions
gem 'turbo-rails', '~> 2.0' # Modern replacement for Turbolinks

# Redis for background jobs and caching
gem 'redis', '~> 5.3'

# HTTP clients for API integrations
gem 'faraday', '~> 2.7'
gem 'faraday-retry', '~> 2.2'
gem 'httparty', '~> 0.21'

# Parallel processing for API enrichment
gem 'concurrent-ruby', '~> 1.2'

# Circuit breaker for API resilience
gem 'stoplight', '~> 3.0'

# Error tracking and monitoring
gem 'sentry-rails', '~> 5.17'
gem 'sentry-ruby', '~> 5.17'

# Rate limiting and abuse prevention
gem 'rack-attack', '~> 6.7'

group :development, :test do
  # Modern debugging tools
  gem 'debug', platforms: %i[mri mingw x64_mingw] # Replaces byebug
  gem 'factory_bot_rails', '~> 6.4' # Test data factories
  gem 'faker', '~> 3.2' # Generate fake data for tests
  gem 'rspec-rails', '~> 7.0' # Modern testing framework
  gem 'shoulda-matchers', '~> 6.0' # RSpec matchers for common validations
end

group :development do
  # Development tools
  gem 'listen', '~> 3.9'
  gem 'pry-rails' # Enhanced console
  gem 'web-console', '~> 4.2'

  # Code quality and linting
  gem 'brakeman', '~> 6.2', require: false # Security analysis
  gem 'rubocop', '~> 1.67', require: false
  gem 'rubocop-rails', '~> 2.27', require: false
  gem 'rubocop-rspec', '~> 3.2', require: false
end

group :test do
  # Code coverage
  gem 'simplecov', '~> 0.22', require: false
  gem 'simplecov-console', '~> 0.9', require: false # Terminal output

  # System testing
  gem 'capybara', '~> 3.40'
  gem 'selenium-webdriver', '~> 4.10' # Compatible with webdrivers 5.3
  gem 'webdrivers', '~> 5.3' # Auto-manages driver binaries

  # Test helpers
  gem 'mock_redis', '~> 0.46' # Mock Redis for circuit breaker tests
  gem 'webmock', '~> 3.19' # HTTP request stubbing
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
