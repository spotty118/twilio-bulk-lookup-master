# frozen_string_literal: true

# API testing helpers for RSpec
# This file provides utilities for testing API endpoints with authentication
#
# Usage:
#   include ApiHelpers
#
#   # Get headers with valid authentication
#   headers = api_headers(admin_user)
#
#   # Make authenticated request
#   get '/api/v1/contacts', headers: api_headers

module ApiHelpers
  # Generate API request headers with Bearer token authentication
  #
  # @param admin_user [AdminUser] The admin user for authentication (creates one if nil)
  # @return [Hash] Headers hash with Authorization and Content-Type
  def api_headers(admin_user = nil)
    admin_user ||= create(:admin_user)
    {
      'Authorization' => "Bearer #{admin_user.api_token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  # Generate headers without authentication (for testing 401 responses)
  #
  # @return [Hash] Headers hash without Authorization
  def unauthenticated_headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  # Generate headers with invalid token (for testing 401 responses)
  #
  # @return [Hash] Headers hash with invalid Authorization
  def invalid_token_headers
    {
      'Authorization' => 'Bearer invalid_token_12345',
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  # Parse JSON response body
  #
  # @return [Hash] Parsed JSON response
  def json_response
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
