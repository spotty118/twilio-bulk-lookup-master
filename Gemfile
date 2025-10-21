source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.3.6'  # Latest stable Ruby version

# Core Rails gems - using Rails 7.2 for better gem compatibility
gem 'rails', '~> 7.2.0'
gem 'pg', '~> 1.5'
gem 'puma', '~> 6.4'
gem 'bootsnap', '>= 1.18.0', require: false
gem 'sprockets-rails'  # For asset pipeline

# Authentication and Admin interface
gem 'devise', '~> 4.9'
gem 'activeadmin', '~> 3.2'
gem 'active_admin_import', '~> 5.0'
gem 'inherited_resources', '~> 1.14'
gem 'ransack', '~> 4.2'  # Required by ActiveAdmin
gem 'kaminari', '~> 1.2'  # Required by ActiveAdmin

# Asset pipeline
gem 'sassc-rails', '~> 2.1'  # Modern Sass processor
gem 'image_processing', '~> 1.13'  # For Active Storage variants

# API and background jobs
gem 'twilio-ruby', '~> 7.2'  # Updated Twilio SDK
gem 'sidekiq', '~> 7.3'

# JSON builder and other utilities
gem 'jbuilder', '~> 2.13'
gem 'turbo-rails', '~> 2.0'  # Modern replacement for Turbolinks
gem 'stimulus-rails', '~> 1.3'  # For JavaScript interactions
gem 'coffee-rails', '~> 5.0'  # For CoffeeScript assets

# Redis for background jobs and caching
gem 'redis', '~> 5.3'

# Rate limiting and abuse prevention
gem 'rack-attack', '~> 6.7'

group :development, :test do
  # Modern debugging tools
  gem 'debug', platforms: [:mri, :mingw, :x64_mingw]  # Replaces byebug
  gem 'rspec-rails', '~> 7.0'  # Modern testing framework
  gem 'factory_bot_rails', '~> 6.4'  # Test data factories
end

group :development do
  # Development tools
  gem 'web-console', '~> 4.2'
  gem 'listen', '~> 3.9'
  gem 'pry-rails'  # Enhanced console
  
  # Code quality and linting
  gem 'rubocop', '~> 1.67', require: false
  gem 'rubocop-rails', '~> 2.27', require: false
  gem 'rubocop-rspec', '~> 3.2', require: false
  gem 'brakeman', '~> 6.2', require: false  # Security analysis
end


group :test do
  # System testing
  gem 'capybara', '~> 3.40'
  gem 'selenium-webdriver', '~> 4.10'  # Compatible with webdrivers 5.3
  gem 'webdrivers', '~> 5.3'  # Auto-manages driver binaries
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:windows, :jruby]
