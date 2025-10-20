require 'net/http'
require 'json'

class BusinessEnrichmentService
  # Main entry point for enriching contact with business data
  def self.enrich(contact)
    new(contact).enrich
  end

  def initialize(contact)
    @contact = contact
    @phone_number = contact.formatted_phone_number || contact.raw_phone_number
  end

  def enrich
    # Only enrich if identified as business by Twilio
    return false unless should_enrich?

    # Try different providers in order of preference
    result = try_clearbit || try_numverify || try_opencnam

    if result
      update_contact_with_business_data(result)
      true
    else
      Rails.logger.info("No business data found for #{@phone_number}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Business enrichment error for #{@phone_number}: #{e.message}")
    false
  end

  private

  def should_enrich?
    # Enrich if Twilio identified as business or if we don't know yet
    @contact.caller_type == 'business' || @contact.caller_name.present?
  end

  # Clearbit integration (uses Clearbit Enrichment API)
  def try_clearbit
    api_key = ENV['CLEARBIT_API_KEY'] || TwilioCredential.current&.clearbit_api_key
    return nil unless api_key.present?

    # First, try phone lookup
    data = clearbit_phone_lookup(api_key)

    # If we have a domain from phone lookup or existing data, enrich company
    if data && data['company'] && data['company']['domain']
      company_data = clearbit_company_lookup(api_key, data['company']['domain'])
      data['company'].merge!(company_data) if company_data
    end

    parse_clearbit_response(data) if data
  rescue StandardError => e
    Rails.logger.warn("Clearbit API error: #{e.message}")
    nil
  end

  def clearbit_phone_lookup(api_key)
    # Clearbit Prospector API for phone lookup
    uri = URI("https://prospector.clearbit.com/v1/people/search")
    uri.query = URI.encode_www_form(phone: @phone_number)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 10) do |http|
      http.request(request)
    end

    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    data['results']&.first
  rescue StandardError => e
    Rails.logger.warn("Clearbit phone lookup error: #{e.message}")
    nil
  end

  def clearbit_company_lookup(api_key, domain)
    uri = URI("https://company.clearbit.com/v2/companies/find")
    uri.query = URI.encode_www_form(domain: domain)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 10) do |http|
      http.request(request)
    end

    return nil unless response.code == '200'
    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.warn("Clearbit company lookup error: #{e.message}")
    nil
  end

  def parse_clearbit_response(data)
    return nil unless data && data['company']

    company = data['company']
    {
      provider: 'clearbit',
      is_business: true,
      business_name: company['name'],
      business_legal_name: company['legalName'],
      business_type: company['type'],
      business_category: company['category']&.dig('industry'),
      business_industry: company['category']&.dig('sector'),
      business_employee_count: company['metrics']&.dig('employees'),
      business_employee_range: employee_range_from_count(company['metrics']&.dig('employees')),
      business_annual_revenue: company['metrics']&.dig('annualRevenue'),
      business_revenue_range: revenue_range_from_amount(company['metrics']&.dig('annualRevenue')),
      business_founded_year: company['foundedYear'],
      business_address: [company['location']&.dig('streetNumber'), company['location']&.dig('street')].compact.join(' '),
      business_city: company['location']&.dig('city'),
      business_state: company['location']&.dig('state'),
      business_country: company['location']&.dig('country'),
      business_postal_code: company['location']&.dig('postalCode'),
      business_website: company['domain'],
      business_email_domain: company['domain'],
      business_linkedin_url: company['linkedin']&.dig('handle') ? "https://linkedin.com/company/#{company['linkedin']['handle']}" : nil,
      business_twitter_handle: company['twitter']&.dig('handle'),
      business_description: company['description'],
      business_tags: [company['tags']].flatten.compact,
      business_tech_stack: company['tech'] || [],
      business_confidence_score: 85
    }
  end

  # NumVerify integration (phone number intelligence with business data)
  def try_numverify
    api_key = ENV['NUMVERIFY_API_KEY'] || TwilioCredential.current&.numverify_api_key
    return nil unless api_key.present?

    phone = @phone_number.gsub(/[^0-9]/, '')
    uri = URI("http://apilayer.net/api/validate")
    uri.query = URI.encode_www_form(
      access_key: api_key,
      number: phone,
      format: 1
    )

    response = Net::HTTP.get_response(uri)
    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    parse_numverify_response(data) if data && data['valid']
  rescue StandardError => e
    Rails.logger.warn("NumVerify API error: #{e.message}")
    nil
  end

  def parse_numverify_response(data)
    return nil unless data['line_type'] == 'landline' # Usually indicates business

    {
      provider: 'numverify',
      is_business: true,
      business_name: data['carrier'] || @contact.carrier_name,
      business_type: 'unknown',
      business_country: data['country_name'],
      business_confidence_score: 50
    }
  end

  # OpenCNAM integration (US only - caller ID with business names)
  def try_opencnam
    # Only works for US numbers
    return nil unless @contact.country_code == 'US'
    return nil unless @contact.caller_name.present?

    # Use existing caller name from Twilio as business name
    {
      provider: 'twilio_cnam',
      is_business: true,
      business_name: @contact.caller_name,
      business_type: @contact.caller_type || 'unknown',
      business_confidence_score: 70
    }
  end

  def update_contact_with_business_data(data)
    @contact.update!(
      is_business: data[:is_business],
      business_name: data[:business_name],
      business_legal_name: data[:business_legal_name],
      business_type: data[:business_type],
      business_category: data[:business_category],
      business_industry: data[:business_industry],
      business_employee_count: data[:business_employee_count],
      business_employee_range: data[:business_employee_range],
      business_annual_revenue: data[:business_annual_revenue],
      business_revenue_range: data[:business_revenue_range],
      business_founded_year: data[:business_founded_year],
      business_address: data[:business_address],
      business_city: data[:business_city],
      business_state: data[:business_state],
      business_country: data[:business_country],
      business_postal_code: data[:business_postal_code],
      business_website: data[:business_website],
      business_email_domain: data[:business_email_domain],
      business_linkedin_url: data[:business_linkedin_url],
      business_twitter_handle: data[:business_twitter_handle],
      business_description: data[:business_description],
      business_tags: data[:business_tags],
      business_tech_stack: data[:business_tech_stack],
      business_enriched: true,
      business_enrichment_provider: data[:provider],
      business_enriched_at: Time.current,
      business_confidence_score: data[:business_confidence_score]
    )
  end

  # Helper methods for ranges
  def employee_range_from_count(count)
    return nil unless count

    case count
    when 0..10 then '1-10'
    when 11..50 then '11-50'
    when 51..200 then '51-200'
    when 201..500 then '201-500'
    when 501..1000 then '501-1000'
    when 1001..5000 then '1001-5000'
    when 5001..10000 then '5001-10000'
    else '10000+'
    end
  end

  def revenue_range_from_amount(amount)
    return nil unless amount

    case amount
    when 0..1_000_000 then '$0-$1M'
    when 1_000_001..10_000_000 then '$1M-$10M'
    when 10_000_001..50_000_000 then '$10M-$50M'
    when 50_000_001..100_000_000 then '$50M-$100M'
    when 100_000_001..500_000_000 then '$100M-$500M'
    when 500_000_001..1_000_000_000 then '$500M-$1B'
    else '$1B+'
    end
  end
end
