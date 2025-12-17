# frozen_string_literal: true

# WebMock configuration for RSpec
# This file is automatically loaded by rails_helper.rb
#
# WebMock disables all external HTTP requests by default,
# ensuring tests are isolated and don't depend on external services.

require 'webmock/rspec'

# Disable all external HTTP requests by default
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    # Allow connections to Selenium/Chromedriver for system tests
    'chromedriver.storage.googleapis.com',
    '127.0.0.1',
    'localhost'
  ]
)

RSpec.configure do |config|
  # Reset WebMock after each test to clear stubs
  config.after(:each) do
    WebMock.reset!
  end

  # Allow real HTTP connections for system/feature tests if needed
  config.before(:each, type: :system) do
    WebMock.allow_net_connect!(
      allow_localhost: true,
      allow: [
        'chromedriver.storage.googleapis.com',
        '127.0.0.1',
        'localhost'
      ]
    )
  end

  config.after(:each, type: :system) do
    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        'chromedriver.storage.googleapis.com',
        '127.0.0.1',
        'localhost'
      ]
    )
  end

  # Tag for tests that need real HTTP connections
  config.before(:each, :allow_net_connect) do
    WebMock.allow_net_connect!
  end

  config.after(:each, :allow_net_connect) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end

# Helper module for common HTTP stubs
module WebMockHelpers
  # Stub Twilio Lookup API responses
  def stub_twilio_lookup(phone_number, response_body, status: 200)
    stub_request(:get, %r{api\.twilio\.com/v2/PhoneNumbers/#{Regexp.escape(phone_number)}})
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub Twilio Lookup API error
  def stub_twilio_lookup_error(phone_number, error_code: 20404, message: 'Invalid phone number')
    stub_request(:get, %r{api\.twilio\.com/v2/PhoneNumbers/#{Regexp.escape(phone_number)}})
      .to_return(
        status: 404,
        body: { code: error_code, message: message, status: 404 }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub Twilio Lookup API timeout
  def stub_twilio_lookup_timeout(phone_number)
    stub_request(:get, %r{api\.twilio\.com/v2/PhoneNumbers/#{Regexp.escape(phone_number)}})
      .to_timeout
  end

  # Stub any external API with a generic response
  def stub_external_api(url_pattern, response_body: {}, status: 200)
    stub_request(:any, url_pattern)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # Stub external API to return an error
  def stub_external_api_error(url_pattern, status: 500, message: 'Internal Server Error')
    stub_request(:any, url_pattern)
      .to_return(
        status: status,
        body: { error: message }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end

RSpec.configure do |config|
  config.include WebMockHelpers
end
