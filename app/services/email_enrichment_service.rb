require 'net/http'
require 'json'

class EmailEnrichmentService
  # Main entry point for email enrichment
  def self.enrich(contact)
    new(contact).enrich
  end

  def initialize(contact)
    @contact = contact
    @phone_number = contact.formatted_phone_number || contact.raw_phone_number
  end

  def enrich
    # Skip if already enriched
    return false if @contact.email_enriched?

    # Skip if no business data to work with
    unless @contact.business_enriched? || @contact.business_email_domain.present?
      Rails.logger.info("No business context for email finding: contact #{@contact.id}")
      return false
    end

    # Try to find email
    result = try_hunter_find || try_domain_pattern || try_clearbit_email

    if result && result[:email]
      # Verify email if found
      verified_result = verify_email(result[:email])
      result.merge!(verified_result) if verified_result

      update_contact_with_email_data(result)
      true
    else
      Rails.logger.info("No email found for contact #{@contact.id}")
      false
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    Rails.logger.error("Database error enriching email for #{@contact.id}: #{e.message}")
    false
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("Contact not found for #{@contact.id}: #{e.message}")
    false
  end

  private

  # Hunter.io - Find email by phone or domain
  def try_hunter_find
    api_key = ENV['HUNTER_API_KEY'] || TwilioCredential.current&.hunter_api_key
    return nil unless api_key.present?

    # First try: Find by phone number
    result = hunter_phone_search(api_key)
    return result if result

    # Second try: Find by domain + name
    if @contact.business_email_domain.present? && @contact.full_name.present?
      result = hunter_email_finder(api_key)
      return result if result
    end

    nil
  rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
    Rails.logger.warn("Hunter.io network error: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn("Hunter.io invalid JSON response: #{e.message}")
    nil
  end

  def hunter_phone_search(api_key)
    uri = URI("https://api.hunter.io/v2/phone-search")
    uri.query = URI.encode_www_form(
      phone: @phone_number,
      api_key: api_key
    )

    response = HttpClient.get(uri, circuit_name: 'hunter-api')
    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    return nil unless data['data'] && data['data']['email']

    parse_hunter_response(data['data'])
  rescue HttpClient::TimeoutError => e
    Rails.logger.warn("Hunter phone search timeout: #{e.message}")
    nil
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.warn("Hunter circuit open: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn("Hunter phone search invalid JSON: #{e.message}")
    nil
  end

  def hunter_email_finder(api_key)
    uri = URI("https://api.hunter.io/v2/email-finder")

    # Parse first and last name
    name_parts = @contact.full_name.to_s.split(' ')
    first_name = name_parts.first || ''
    last_name = name_parts.length > 1 ? name_parts.last : ''

    uri.query = URI.encode_www_form(
      domain: @contact.business_email_domain,
      first_name: first_name,
      last_name: last_name,
      api_key: api_key
    )

    response = HttpClient.get(uri, circuit_name: 'hunter-api')
    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    return nil unless data['data'] && data['data']['email']

    parse_hunter_response(data['data'])
  rescue HttpClient::TimeoutError => e
    Rails.logger.warn("Hunter email finder timeout: #{e.message}")
    nil
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.warn("Hunter circuit open: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn("Hunter email finder invalid JSON: #{e.message}")
    nil
  end

  def parse_hunter_response(data)
    {
      provider: 'hunter',
      email: data['email'],
      email_score: data['score'],
      email_verified: data['verification'] && data['verification']['status'] == 'valid',
      email_status: data['verification'] ? data['verification']['status'] : 'unknown',
      first_name: data['first_name'],
      last_name: data['last_name'],
      full_name: [data['first_name'], data['last_name']].compact.join(' '),
      position: data['position'],
      department: data['department'],
      seniority: data['seniority'],
      linkedin_url: data['linkedin'],
      twitter_url: data['twitter']
    }
  end

  # Domain pattern matching (educated guess)
  def try_domain_pattern
    return nil unless @contact.business_email_domain.present?
    return nil unless @contact.full_name.present? || @contact.caller_name.present?

    name = @contact.full_name || @contact.caller_name
    name_parts = name.to_s.downcase.split(' ').reject(&:empty?)

    return nil if name_parts.length < 2

    first = name_parts.first
    last = name_parts.last

    # Common patterns
    patterns = [
      "#{first}.#{last}@#{@contact.business_email_domain}",
      "#{first}#{last}@#{@contact.business_email_domain}",
      "#{first[0..0]}#{last}@#{@contact.business_email_domain}",
      "#{first}@#{@contact.business_email_domain}"
    ]

    # Return first pattern as guess
    {
      provider: 'pattern_guess',
      email: patterns.first,
      email_score: 30, # Low confidence
      email_verified: false,
      email_status: 'unverified',
      first_name: name_parts.first.capitalize,
      last_name: name_parts.last.capitalize,
      full_name: name
    }
  end

  # Clearbit Email Finder (premium)
  def try_clearbit_email
    api_key = ENV['CLEARBIT_API_KEY'] || TwilioCredential.current&.clearbit_api_key
    return nil unless api_key.present?
    return nil unless @contact.business_email_domain.present? && @contact.full_name.present?

    name_parts = @contact.full_name.to_s.split(' ').reject(&:empty?)
    uri = URI("https://person.clearbit.com/v1/people/email/#{@contact.business_email_domain}")
    uri.query = URI.encode_www_form(
      given_name: name_parts.first || '',
      family_name: name_parts.length > 1 ? name_parts.last : ''
    )

    response = HttpClient.get(uri, circuit_name: 'clearbit-email') do |request|
      request['Authorization'] = "Bearer #{api_key}"
    end

    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    parse_clearbit_email_response(data) if data['email']
  rescue HttpClient::TimeoutError => e
    Rails.logger.warn("Clearbit email finder timeout: #{e.message}")
    nil
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.warn("Clearbit email circuit open: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn("Clearbit email finder invalid JSON: #{e.message}")
    nil
  end

  def parse_clearbit_email_response(data)
    {
      provider: 'clearbit',
      email: data['email'],
      email_score: 85,
      email_verified: true,
      email_status: 'valid',
      first_name: data['givenName'],
      last_name: data['familyName'],
      full_name: data['name'],
      position: data['employment']&.dig('title'),
      linkedin_url: data['linkedin']&.dig('handle') ? "https://linkedin.com/in/#{data['linkedin']['handle']}" : nil,
      twitter_url: data['twitter']&.dig('handle') ? "https://twitter.com/#{data['twitter']['handle']}" : nil,
      facebook_url: data['facebook']&.dig('handle') ? "https://facebook.com/#{data['facebook']['handle']}" : nil
    }
  end

  # Email verification with ZeroBounce or Hunter
  def verify_email(email)
    # Try ZeroBounce first (best verification)
    result = verify_with_zerobounce(email)
    return result if result

    # Try Hunter verification
    result = verify_with_hunter(email)
    return result if result

    nil
  end

  def verify_with_zerobounce(email)
    api_key = ENV['ZEROBOUNCE_API_KEY'] || TwilioCredential.current&.zerobounce_api_key
    return nil unless api_key.present?

    uri = URI("https://api.zerobounce.net/v2/validate")
    uri.query = URI.encode_www_form(
      api_key: api_key,
      email: email,
      ip_address: ''
    )

    response = HttpClient.get(uri, circuit_name: 'zerobounce-api')
    return nil unless response.code == '200'

    data = JSON.parse(response.body)

    {
      email_verified: data['status'] == 'valid',
      email_status: data['status'],
      email_score: score_from_status(data['status']),
      email_type: data['sub_status']
    }
  rescue HttpClient::TimeoutError => e
    Rails.logger.warn("ZeroBounce verification timeout: #{e.message}")
    nil
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.warn("ZeroBounce circuit open: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn("ZeroBounce verification invalid JSON: #{e.message}")
    nil
  end

  def verify_with_hunter(email)
    api_key = ENV['HUNTER_API_KEY'] || TwilioCredential.current&.hunter_api_key
    return nil unless api_key.present?

    uri = URI("https://api.hunter.io/v2/email-verifier")
    uri.query = URI.encode_www_form(
      email: email,
      api_key: api_key
    )

    response = HttpClient.get(uri, circuit_name: 'hunter-api')
    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    verification = data['data']

    {
      email_verified: verification['status'] == 'valid',
      email_status: verification['status'],
      email_score: verification['score'],
      email_type: verification['result']
    }
  rescue HttpClient::TimeoutError => e
    Rails.logger.warn("Hunter verification timeout: #{e.message}")
    nil
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.warn("Hunter circuit open: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn("Hunter verification invalid JSON: #{e.message}")
    nil
  end

  def score_from_status(status)
    case status
    when 'valid' then 100
    when 'catch-all' then 70
    when 'unknown' then 50
    when 'spamtrap' then 10
    when 'abuse' then 5
    when 'do_not_mail' then 0
    else 50
    end
  end

  def update_contact_with_email_data(data)
    @contact.update!(
      email: data[:email],
      email_verified: data[:email_verified],
      email_score: data[:email_score],
      email_status: data[:email_status],
      email_type: data[:email_type],
      email_enriched: true,
      email_enrichment_provider: data[:provider],
      email_enriched_at: Time.current,
      first_name: data[:first_name] || @contact.first_name,
      last_name: data[:last_name] || @contact.last_name,
      full_name: data[:full_name] || @contact.full_name,
      position: data[:position] || @contact.position,
      department: data[:department] || @contact.department,
      seniority: data[:seniority] || @contact.seniority,
      linkedin_url: data[:linkedin_url] || @contact.linkedin_url,
      twitter_url: data[:twitter_url] || @contact.twitter_url,
      facebook_url: data[:facebook_url] || @contact.facebook_url
    )
  end
end
