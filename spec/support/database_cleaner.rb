# frozen_string_literal: true

# DatabaseCleaner configuration for RSpec
# This file is automatically loaded by rails_helper.rb
#
# Note: Rails' use_transactional_fixtures handles most cases.
# DatabaseCleaner is configured here for scenarios that require
# truncation (e.g., tests with multiple database connections,
# JavaScript-driven system tests, or tests that spawn threads).

require 'database_cleaner/active_record'

RSpec.configure do |config|
  # Configure DatabaseCleaner to use transaction strategy by default
  # This is the fastest strategy and works for most tests
  config.before(:suite) do
    # Clean the database once before the entire test suite
    DatabaseCleaner.clean_with(:truncation, except: %w[ar_internal_metadata schema_migrations])
  end

  config.before(:each) do
    # Use transaction strategy by default (fastest)
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, type: :system) do
    # System tests may need truncation due to separate browser process
    DatabaseCleaner.strategy = :truncation, { except: %w[ar_internal_metadata schema_migrations] }
  end

  config.before(:each, js: true) do
    # JavaScript tests run in a separate thread, requiring truncation
    DatabaseCleaner.strategy = :truncation, { except: %w[ar_internal_metadata schema_migrations] }
  end

  config.before(:each, truncation: true) do
    # Allow explicit truncation for specific tests
    DatabaseCleaner.strategy = :truncation, { except: %w[ar_internal_metadata schema_migrations] }
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # Append after Rails' transactional fixtures cleanup
  config.append_after(:each) do
    # Ensure any remaining connections are returned to the pool
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool.active_connection?
  end
end
