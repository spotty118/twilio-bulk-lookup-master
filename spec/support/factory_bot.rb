# frozen_string_literal: true

# FactoryBot configuration for RSpec
# This file is automatically loaded by rails_helper.rb

RSpec.configure do |config|
  # Include FactoryBot methods (create, build, build_stubbed, attributes_for)
  config.include FactoryBot::Syntax::Methods

  # Lint factories before running the test suite (in CI only)
  # This ensures all factories are valid and can be created
  config.before(:suite) do
    if ENV['CI'] || ENV['FACTORY_LINT']
      # Disable callbacks during lint to speed up the process
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)

      begin
        DatabaseCleaner.start
        FactoryBot.lint(traits: true)
      ensure
        DatabaseCleaner.clean
      end
    end
  end
end

# Configure FactoryBot
FactoryBot.define do
  # Use sequences for unique values
  to_create(&:save!)

  # Skip callbacks during factory creation for performance (optional)
  # trait :skip_callbacks do
  #   after(:build) { |record| record.class.skip_callback(:create, :after, :some_callback) }
  # end
end
