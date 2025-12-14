# frozen_string_literal: true

# PromptSanitizer
#
# Prevents AI prompt injection attacks by sanitizing user-controlled input
# before interpolating into LLM prompts.
#
# Attack Vectors Mitigated:
# - System prompt override attempts ("Ignore all previous instructions")
# - Role confusion attacks ("SYSTEM:", "ASSISTANT:", "USER:")
# - Newline-based prompt breaking (using \n to escape user context)
# - Token manipulation (long inputs to exhaust max_tokens)
# - Unicode tricks (invisible characters, right-to-left override)
#
# Usage:
#   PromptSanitizer.sanitize(user_input, max_length: 500)
#   PromptSanitizer.sanitize_hash(contact_attributes)
#
module PromptSanitizer
  # Patterns that indicate prompt injection attempts
  INJECTION_PATTERNS = [
    /ignore\s+(all\s+)?previous\s+instructions?/i,
    /disregard\s+(all\s+)?previous\s+instructions?/i,
    /forget\s+(all\s+)?previous\s+instructions?/i,
    /\b(system|assistant|user)\s*:/i,
    /\bprompt\s*:/i,
    /\brole\s*:/i,
    /\btemperature\s*[:=]/i,
    /\bmax_tokens\s*[:=]/i,
    /\bmodel\s*[:=]/i,
    /<\|.*?\|>/,  # Special tokens used by some models
    /\[INST\]/i,  # Instruction markers
    /\[\/INST\]/i,
    /<<SYS>>/i,
    /<\/SYS>/i
  ].freeze

  # Unicode control characters and homoglyphs to strip
  DANGEROUS_UNICODE = [
    "\u200B",  # Zero-width space
    "\u200C",  # Zero-width non-joiner
    "\u200D",  # Zero-width joiner
    "\u200E",  # Left-to-right mark
    "\u200F",  # Right-to-left mark
    "\u202A",  # Left-to-right embedding
    "\u202B",  # Right-to-left embedding
    "\u202C",  # Pop directional formatting
    "\u202D",  # Left-to-right override
    "\u202E",  # Right-to-left override
    "\uFEFF"   # Zero-width no-break space
  ].freeze

  class << self
    # Sanitize a single string input
    #
    # @param input [String, nil] User-controlled input
    # @param max_length [Integer] Maximum allowed length
    # @param field_name [String] Field name for logging
    # @return [String] Sanitized string safe for prompt interpolation
    def sanitize(input, max_length: 1000, field_name: 'input')
      return '' if input.nil? || input.empty?

      sanitized = input.to_s.dup

      # Step 1: Remove dangerous Unicode characters
      DANGEROUS_UNICODE.each { |char| sanitized.gsub!(char, '') }

      # Step 2: Normalize whitespace (prevent newline-based escapes)
      # Replace multiple spaces/newlines with single space
      sanitized.gsub!(/\s+/, ' ')

      # Step 3: Detect and log injection attempts
      INJECTION_PATTERNS.each do |pattern|
        if sanitized.match?(pattern)
          Rails.logger.warn(
            "Potential prompt injection detected in #{field_name}: " \
            "#{sanitized[0..100]} (pattern: #{pattern.inspect})"
          )

          # Strip the matching pattern
          sanitized.gsub!(pattern, '[REDACTED]')
        end
      end

      # Step 4: Truncate to max length
      if sanitized.length > max_length
        Rails.logger.info(
          "Truncating #{field_name} from #{sanitized.length} to #{max_length} characters"
        )
        sanitized = sanitized[0...max_length].strip + '...'
      end

      # Step 5: Strip leading/trailing whitespace
      sanitized.strip
    end

    # Sanitize all string values in a hash
    #
    # @param data [Hash] Hash with potentially unsafe values
    # @param config [Hash] Field-specific max_length overrides
    # @return [Hash] Hash with sanitized values
    def sanitize_hash(data, config: {})
      return {} if data.nil?

      data.each_with_object({}) do |(key, value), result|
        max_length = config.dig(key, :max_length) || 1000
        # Use key as string for field name logging
        field_name = key.to_s

        if value.is_a?(String)
          result[key] = sanitize(value, max_length: max_length, field_name: field_name)
        else
          result[key] = value
        end
      end
    end

    # Sanitize contact profile fields for AI prompts
    #
    # @param contact [Contact] Contact record
    # @return [Hash] Sanitized contact attributes
    def sanitize_contact(contact)
      {
        phone: sanitize(contact.formatted_phone_number || contact.raw_phone_number, max_length: 20),
        full_name: sanitize(contact.full_name, max_length: 100),
        email: sanitize(contact.email, max_length: 255),
        business_name: sanitize(contact.business_name, max_length: 200),
        business_industry: sanitize(contact.business_industry, max_length: 100),
        business_description: sanitize(contact.business_description, max_length: 500),
        business_city: sanitize(contact.business_city, max_length: 100),
        business_state: sanitize(contact.business_state, max_length: 50),
        business_website: sanitize(contact.business_website, max_length: 255),
        position: sanitize(contact.position, max_length: 100),
        department: sanitize(contact.department, max_length: 100)
      }
    end
  end
end
