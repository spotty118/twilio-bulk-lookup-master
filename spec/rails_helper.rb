# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'
require 'webmock/rspec'

# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files are loaded in alphabetical order.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [Rails.root.join('spec/fixtures')]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Additional Rails gems to filter from backtraces
  config.filter_gems_from_backtrace(
    'activerecord',
    'activesupport',
    'actionpack',
    'actionview',
    'railties'
  )

  # Sidekiq test helpers
  require 'sidekiq/testing'
  Sidekiq::Testing.fake!

  # Clean up Sidekiq jobs before each test
  config.before(:each) do
    Sidekiq::Worker.clear_all
  end

  # Helper to freeze time in tests
  config.include ActiveSupport::Testing::TimeHelpers

  # Explicitly configure ActiveRecord Encryption for tests
  config.before(:suite) do
    ActiveRecord::Encryption.configure(
      primary_key: 'test_primary_key_must_be_32_bytes_long!!!!!',
      deterministic_key: 'test_deterministic_key_must_be_32_bytes!!',
      key_derivation_salt: 'test_salt_must_be_long_enough_for_deriv'
    )
  end

  # Clean up any test artifacts after suite
  config.after(:suite) do
    FileUtils.rm_rf(Rails.root.join('tmp', 'test_uploads')) if Dir.exist?(Rails.root.join('tmp', 'test_uploads'))
  end

  # Tag slow tests for optional exclusion
  config.define_derived_metadata(file_path: %r{/spec/integration/}) do |metadata|
    metadata[:integration] = true
  end

  # Tag property-based tests
  config.define_derived_metadata(file_path: %r{/spec/properties/}) do |metadata|
    metadata[:property] = true
  end
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
