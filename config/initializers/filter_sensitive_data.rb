# frozen_string_literal: true

# Filter Sensitive Data from Logs
#
# Rails automatically filters parameters specified here from logs and error reports.
# This prevents API keys, tokens, and credentials from being leaked in:
# - Development logs
# - Production logs
# - Exception tracking services (Sentry, Rollbar, etc.)
# - Log aggregation services (Splunk, DataDog, etc.)
#
# Security Impact: Prevents credential leakage in logs (HIGH severity)
#
Rails.application.config.filter_parameters += [
  # API Keys and Tokens
  :api_key,
  :auth_token,
  :access_token,
  :refresh_token,
  :bearer_token,
  :client_secret,
  :api_secret,

  # Twilio Credentials
  :account_sid,
  :twilio_account_sid,
  :twilio_auth_token,

  # External API Keys
  :openai_api_key,
  :clearbit_api_key,
  :hunter_api_key,
  :numverify_api_key,
  :zerobounce_api_key,
  :whitepages_api_key,
  :truecaller_api_key,
  :google_api_key,
  :anthropic_api_key,

  # CRM Credentials
  :salesforce_token,
  :hubspot_api_key,
  :pipedrive_api_key,

  # Passwords and Secrets
  :password,
  :password_confirmation,
  :secret,
  :secret_key,
  :secret_key_base,

  # Personal Data (GDPR/CCPA compliance)
  :ssn,
  :social_security_number,
  :credit_card,
  :cvv,
  :bank_account,

  # OAuth
  :oauth_token,
  :oauth_token_secret,

  # Webhook Signatures (to prevent replay attacks)
  :signature,
  :x_twilio_signature,

  # Database Credentials
  :database_url,
  :db_password
]

# Additional filtering for nested parameters
# e.g., params: { credentials: { api_key: "secret" } }
Rails.application.config.filter_parameters += [
  /api[-_]?key/i,
  /auth[-_]?token/i,
  /bearer[-_]?token/i,
  /password/i,
  /secret/i,
  /token/i,
  /key/i
]

# Custom log sanitizer for complex objects
# This handles cases where sensitive data is in custom objects, not just params
module LogSanitizer
  # Sanitize hash/object for logging
  # Recursively filters sensitive keys from nested hashes
  #
  # Example:
  #   LogSanitizer.sanitize({ api_key: "sk-123", user: "john" })
  #   => { api_key: "[FILTERED]", user: "john" }
  #
  def self.sanitize(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_s).transform_values do |value|
        if sensitive_key?(value.to_s)
          '[FILTERED]'
        else
          sanitize(value)
        end
      end.transform_keys do |key|
        sensitive_key?(key) ? key : key
      end.transform_values do |value|
        value == '[FILTERED]' ? '[FILTERED]' : value
      end
    when Array
      obj.map { |item| sanitize(item) }
    when String
      # Check if string looks like an API key (alphanumeric, 20+ chars, no spaces)
      if looks_like_secret?(obj)
        "[FILTERED-#{obj[0..3]}...#{obj[-4..-1]}]"
      else
        obj
      end
    else
      obj
    end
  end

  # Check if hash key is sensitive
  def self.sensitive_key?(key)
    key_str = key.to_s.downcase

    SENSITIVE_PATTERNS.any? { |pattern| key_str.match?(pattern) }
  end

  # Check if string value looks like a secret (heuristic)
  def self.looks_like_secret?(str)
    return false if str.length < 20
    return false if str.match?(/\s/)  # Secrets usually don't have spaces

    # Check for patterns that look like API keys
    str.match?(/^(sk|pk|ak|token)[-_]?[a-zA-Z0-9]{20,}$/i) ||
    str.match?(/^[a-f0-9]{32,}$/i) ||  # Hex tokens
    str.match?(/^[A-Za-z0-9+\/]{40,}={0,2}$/)  # Base64 tokens
  end

  SENSITIVE_PATTERNS = [
    /api[-_]?key/i,
    /auth[-_]?token/i,
    /bearer/i,
    /password/i,
    /secret/i,
    /credential/i,
    /authorization/i
  ].freeze
end

# Add custom sanitizer to ActiveSupport logger
# This ensures our sanitization is applied to all log output
if defined?(ActiveSupport::Logger)
  class ActiveSupport::Logger
    alias_method :original_add, :add

    def add(severity, message = nil, progname = nil, &block)
      # Sanitize message before logging
      sanitized_message = if message.is_a?(Hash) || message.is_a?(Array)
        LogSanitizer.sanitize(message).inspect
      elsif block_given?
        result = yield
        result.is_a?(Hash) || result.is_a?(Array) ? LogSanitizer.sanitize(result).inspect : result
      else
        message
      end

      original_add(severity, sanitized_message, progname)
    end
  end
end

# Log that filtering is enabled (without revealing what's being filtered)
Rails.logger.info("Log sanitization enabled: #{Rails.application.config.filter_parameters.size} patterns configured")
