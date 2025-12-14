require 'net/http'
require 'json'

class BusinessLookupService
  class ProviderError < StandardError; end

  attr_reader :zipcode, :zipcode_lookup, :stats

  def initialize(zipcode, zipcode_lookup: nil)
    @zipcode = zipcode.to_s.strip
    @zipcode_lookup = zipcode_lookup
    @credentials = TwilioCredential.current
    @stats = {
      found: 0,
      imported: 0,
      updated: 0,
      skipped: 0,
      duplicates_prevented: 0
    }
  end

  # ========================================
  # Main Entry Point
  # ========================================

  def lookup_businesses(limit: nil)
    limit ||= @credentials&.results_per_zipcode || 20

    businesses = fetch_businesses_from_providers(limit)
    @stats[:found] = businesses.count

    Rails.logger.info "[BusinessLookupService] Found #{businesses.count} businesses in zipcode #{@zipcode}"

    businesses.each do |business_data|
      process_business(business_data)
    end

    @stats
  end

  private

  # ========================================
  # Provider Management
  # ========================================

  def fetch_businesses_from_providers(limit)
    businesses = []
    provider_errors = []
    any_provider_succeeded = false

    # Try Google Places first
    if @credentials&.google_places_api_key.present?
      begin
        businesses = try_google_places(limit)
        any_provider_succeeded = true
        @zipcode_lookup&.update(provider: 'google_places')
        return businesses if businesses.any?
      rescue ProviderError => e
        provider_errors << "Google Places: #{e.message}"
        Rails.logger.warn "[BusinessLookupService] Google Places failed: #{e.message}"
      end
    end

    # Fallback to Yelp
    if @credentials&.yelp_api_key.present?
      begin
        businesses = try_yelp(limit)
        any_provider_succeeded = true
        @zipcode_lookup&.update(provider: 'yelp')
        return businesses if businesses.any?
      rescue ProviderError => e
        provider_errors << "Yelp: #{e.message}"
        Rails.logger.warn "[BusinessLookupService] Yelp failed: #{e.message}"
      end
    end

    return [] if any_provider_succeeded

    if provider_errors.any?
      raise ProviderError, provider_errors.join(' | ')
    end

    Rails.logger.warn "[BusinessLookupService] No business directory API configured"
    raise ProviderError, "No business directory API configured. Configure Google Places or Yelp in Twilio Settings."
  end

  # ========================================
  # Google Places API
  # ========================================

  def try_google_places(limit)
    try_google_places_legacy(limit)
  rescue ProviderError => legacy_error
    begin
      try_google_places_new(limit)
    rescue ProviderError => new_error
      raise ProviderError, "#{legacy_error.message} | Places API (New): #{new_error.message}"
    end
  end

  def try_google_places_legacy(limit)
    api_key = @credentials.google_places_api_key

    # Use Text Search to find businesses in zipcode
    # Note: Google Places doesn't search by zipcode directly, so we search by location
    uri = URI('https://maps.googleapis.com/maps/api/place/textsearch/json')
    params = {
      query: "businesses in #{@zipcode}",
      key: api_key
    }
    uri.query = URI.encode_www_form(params)

    response = HttpClient.get(uri, circuit_name: 'google-places-api')
    raise ProviderError, "HTTP #{response.code}" unless response.code == '200'

    data = JSON.parse(response.body)
    status = data['status']
    unless status == 'OK'
      return [] if status == 'ZERO_RESULTS'

      error_msg = data['error_message'].presence || status
      raise ProviderError, "#{status} - #{error_msg}. Check that Places API is enabled, billing is active, and API key restrictions allow server requests."
    end

    results = data['results'].take(limit)

    # Batch fetch place details to reduce N+1 API calls
    # Only fetch details for places that have a place_id
    place_ids = results.map { |p| p['place_id'] }.compact
    details_cache = batch_fetch_place_details(place_ids)

    results.map do |place|
      parse_google_place(place, details_cache)
    end.compact

  rescue HttpClient::TimeoutError => e
    raise ProviderError, "Timeout - #{e.message}"
  rescue HttpClient::CircuitOpenError => e
    raise ProviderError, "Temporarily unavailable - #{e.message}"
  rescue JSON::ParserError => e
    raise ProviderError, "Invalid JSON response - #{e.message}"
  rescue StandardError => e
    raise ProviderError, e.message
  end

  def try_google_places_new(limit)
    api_key = @credentials.google_places_api_key

    uri = URI('https://places.googleapis.com/v1/places:searchText')
    body = {
      textQuery: "businesses in #{@zipcode}",
      maxResultCount: limit,
      languageCode: 'en',
      regionCode: 'US'
    }
    field_mask = 'places.id,places.displayName,places.formattedAddress,places.location,places.types,places.rating,places.websiteUri,places.nationalPhoneNumber,places.internationalPhoneNumber'

    response = HttpClient.post(uri, body: body, circuit_name: 'google-places-api') do |request|
      request['X-Goog-Api-Key'] = api_key
      request['X-Goog-FieldMask'] = field_mask
    end

    unless response.code == '200'
      begin
        data = JSON.parse(response.body)
        error = data['error']
        error_status = error&.[]('status')
        error_message = error&.[]('message')
      rescue JSON::ParserError
        error_status = nil
        error_message = nil
      end

      message = "HTTP #{response.code}"
      if error_status.present? || error_message.present?
        message = "#{error_status || message} - #{error_message || message}"
      end
      raise ProviderError, message
    end

    data = JSON.parse(response.body)
    places = data['places'] || []

    places.take(limit).map do |place|
      name = place.dig('displayName', 'text') || place['displayName']
      phone = place['internationalPhoneNumber'] || place['nationalPhoneNumber']

      {
        name: name,
        address: place['formattedAddress'],
        phone: phone,
        website: place['websiteUri'],
        business_type: place['types']&.first,
        rating: place['rating'],
        latitude: place.dig('location', 'latitude'),
        longitude: place.dig('location', 'longitude'),
        place_id: place['id'],
        source: 'google_places'
      }
    end.compact
  rescue HttpClient::TimeoutError => e
    raise ProviderError, "Timeout - #{e.message}"
  rescue HttpClient::CircuitOpenError => e
    raise ProviderError, "Temporarily unavailable - #{e.message}"
  rescue JSON::ParserError => e
    raise ProviderError, "Invalid JSON response - #{e.message}"
  rescue StandardError => e
    raise ProviderError, e.message
  end

  def parse_google_place(place, details_cache = {})
    # Get place details from cache (batch fetched) or fetch individually as fallback
    details = if place['place_id'] && details_cache.key?(place['place_id'])
                details_cache[place['place_id']]
              elsif place['place_id']
                fetch_google_place_details(place['place_id'])
              end

    {
      name: place['name'],
      address: place['formatted_address'],
      phone: details&.dig('formatted_phone_number'),
      website: details&.dig('website'),
      business_type: place['types']&.first,
      rating: place['rating'],
      latitude: place.dig('geometry', 'location', 'lat'),
      longitude: place.dig('geometry', 'location', 'lng'),
      place_id: place['place_id'],
      source: 'google_places'
    }
  end

  def batch_fetch_place_details(place_ids)
    return {} if place_ids.empty?

    details_cache = {}
    
    # Google Places API doesn't support true batch requests, but we can
    # use threading to parallelize requests (limited to 5 concurrent)
    # This reduces total wait time significantly compared to sequential calls
    place_ids.each_slice(5) do |batch|
      threads = batch.map do |place_id|
        Thread.new do
          details = fetch_google_place_details(place_id)
          [place_id, details] if details
        end
      end

      threads.each do |thread|
        result = thread.value
        details_cache[result[0]] = result[1] if result
      end
    end

    details_cache
  rescue ProviderError
    raise
  rescue StandardError => e
    Rails.logger.warn "[BusinessLookupService] Batch fetch error: #{e.message}, falling back to individual fetches"
    {}
  end

  def fetch_google_place_details(place_id)
    api_key = @credentials.google_places_api_key

    uri = URI('https://maps.googleapis.com/maps/api/place/details/json')
    params = {
      place_id: place_id,
      fields: 'formatted_phone_number,website,name',
      key: api_key
    }
    uri.query = URI.encode_www_form(params)

    response = HttpClient.get(uri, circuit_name: 'google-places-api')
    raise ProviderError, "Place details HTTP #{response.code}" unless response.code == '200'

    data = JSON.parse(response.body)
    status = data['status']
    return data['result'] if status == 'OK'
    return nil if %w[NOT_FOUND ZERO_RESULTS].include?(status)

    error_msg = data['error_message'].presence || status
    raise ProviderError, "Place details #{status} - #{error_msg}"
  rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
    Rails.logger.warn "[BusinessLookupService] Google Place details error: #{e.message}"
    nil
  rescue JSON::ParserError => e
    raise ProviderError, "Place details invalid JSON - #{e.message}"
  rescue StandardError => e
    raise ProviderError, e.message
  end

  # ========================================
  # Yelp Fusion API
  # ========================================

  def try_yelp(limit)
    api_key = @credentials.yelp_api_key

    uri = URI('https://api.yelp.com/v3/businesses/search')
    params = {
      location: @zipcode,
      limit: [limit, 50].min # Yelp max is 50
    }
    uri.query = URI.encode_www_form(params)

    response = HttpClient.get(uri, circuit_name: 'yelp-api') do |request|
      request['Authorization'] = "Bearer #{api_key}"
    end

    unless response.code == '200'
      begin
        data = JSON.parse(response.body)
        error_desc = data.dig('error', 'description') || data.dig('error', 'code')
      rescue JSON::ParserError
        error_desc = nil
      end
      message = "HTTP #{response.code}"
      message = "#{message} - #{error_desc}" if error_desc.present?
      raise ProviderError, message
    end

    data = JSON.parse(response.body)
    businesses = data['businesses'] || []

    businesses.map do |biz|
      parse_yelp_business(biz)
    end.compact

  rescue HttpClient::TimeoutError => e
    raise ProviderError, "Timeout - #{e.message}"
  rescue HttpClient::CircuitOpenError => e
    raise ProviderError, "Temporarily unavailable - #{e.message}"
  rescue JSON::ParserError => e
    raise ProviderError, "Invalid JSON response - #{e.message}"
  rescue StandardError => e
    raise ProviderError, e.message
  end

  def parse_yelp_business(biz)
    address_parts = [
      biz.dig('location', 'address1'),
      biz.dig('location', 'city'),
      biz.dig('location', 'state'),
      biz.dig('location', 'zip_code')
    ].compact

    {
      name: biz['name'],
      address: address_parts.join(', '),
      phone: biz['phone'],
      website: biz['url'],
      business_type: biz.dig('categories', 0, 'title'),
      rating: biz['rating'],
      review_count: biz['review_count'],
      latitude: biz.dig('coordinates', 'latitude'),
      longitude: biz.dig('coordinates', 'longitude'),
      yelp_id: biz['id'],
      source: 'yelp'
    }
  end

  # ========================================
  # Business Processing & Duplicate Prevention
  # ========================================

  def process_business(business_data)
    # Check for existing contact by phone or business name + address
    existing_contact = find_existing_contact(business_data)

    if existing_contact
      # Update existing contact
      if update_contact(existing_contact, business_data)
        @stats[:updated] += 1
        Rails.logger.info "[BusinessLookupService] Updated contact ##{existing_contact.id}: #{business_data[:name]}"
      else
        @stats[:skipped] += 1
        Rails.logger.info "[BusinessLookupService] Skipped contact ##{existing_contact.id}: No changes needed"
      end
    else
      # Create new contact
      contact = create_contact(business_data)
      if contact&.persisted?
        @stats[:imported] += 1
        Rails.logger.info "[BusinessLookupService] Imported new contact ##{contact.id}: #{business_data[:name]}"

        # Trigger enrichment pipeline if enabled
        trigger_enrichment(contact) if @credentials&.auto_enrich_zipcode_results
      else
        @stats[:skipped] += 1
        Rails.logger.warn "[BusinessLookupService] Failed to import: #{business_data[:name]}"
      end
    end

  rescue StandardError => e
    Rails.logger.error "[BusinessLookupService] Error processing business #{business_data[:name]}: #{e.message}"
    @stats[:skipped] += 1
  end

  def find_existing_contact(business_data)
    # First try by phone (most reliable)
    if business_data[:phone].present?
      normalized_phone = normalize_phone(business_data[:phone])
      contact = Contact.where(raw_phone_number: normalized_phone).first
      return contact if contact
    end

    # Try by business name + zipcode (good match)
    if business_data[:name].present?
      # Use fingerprinting for better matching
      name_fingerprint = create_name_fingerprint(business_data[:name])

      Contact.where(
        "name_fingerprint = ? AND business_postal_code = ?",
        name_fingerprint,
        @zipcode
      ).first
    end
  end

  def create_contact(business_data)
    # Extract address components
    address_data = parse_address(business_data[:address])

    contact = Contact.new(
      raw_phone_number: normalize_phone(business_data[:phone]),
      status: 'pending',
      is_business: true,
      caller_type: 'business',

      # Business data
      business_name: business_data[:name],
      business_type: business_data[:business_type],
      business_address: business_data[:address],
      business_city: address_data[:city],
      business_state: address_data[:state],
      business_postal_code: address_data[:zipcode] || @zipcode,
      business_country: 'USA',
      business_website: extract_domain(business_data[:website]),

      # Source tracking
      business_enriched: true,
      business_enrichment_provider: business_data[:source],
      business_enriched_at: Time.current,
      business_confidence_score: 100 # Direct lookup = high confidence
    )

    # Update fingerprints before saving
    contact.save!
    contact.update_fingerprints! if contact.persisted?
    contact.calculate_quality_score! if contact.persisted?

    contact
  end

  def update_contact(contact, business_data)
    changes_made = false

    # Update business fields if they're empty or we have better data
    updates = {}

    updates[:business_name] = business_data[:name] if business_data[:name].present? && contact.business_name.blank?
    updates[:business_type] = business_data[:business_type] if business_data[:business_type].present? && contact.business_type.blank?
    updates[:business_address] = business_data[:address] if business_data[:address].present? && contact.business_address.blank?

    address_data = parse_address(business_data[:address])
    updates[:business_city] = address_data[:city] if address_data[:city].present? && contact.business_city.blank?
    updates[:business_state] = address_data[:state] if address_data[:state].present? && contact.business_state.blank?
    updates[:business_postal_code] = address_data[:zipcode] || @zipcode if contact.business_postal_code.blank?

    updates[:business_website] = extract_domain(business_data[:website]) if business_data[:website].present? && contact.business_website.blank?
    updates[:raw_phone_number] = normalize_phone(business_data[:phone]) if business_data[:phone].present? && contact.raw_phone_number.blank?

    # Mark as business if not already
    updates[:is_business] = true unless contact.is_business
    updates[:caller_type] = 'business' if contact.caller_type != 'business'

    # Update enrichment tracking
    updates[:business_enriched] = true
    updates[:business_enrichment_provider] = business_data[:source]
    updates[:business_enriched_at] = Time.current

    if updates.any?
      contact.update!(updates)
      contact.update_fingerprints!
      contact.calculate_quality_score!
      changes_made = true
    end

    changes_made
  end

  def trigger_enrichment(contact)
    # Queue enrichment jobs if needed
    if contact.raw_phone_number.present? && !contact.lookup_completed?
      LookupRequestJob.perform_later(contact.id)
    elsif contact.business? && !contact.email_enriched?
      EmailEnrichmentJob.perform_later(contact.id)
    end
  end

  # ========================================
  # Helper Methods
  # ========================================

  def normalize_phone(phone)
    return nil if phone.blank?

    # Remove all non-digit characters
    digits = phone.gsub(/\D/, '')

    # Add +1 if it's a 10-digit US number
    digits = "1#{digits}" if digits.length == 10

    # Return with + prefix for E.164 format
    "+#{digits}"
  end

  def create_name_fingerprint(name)
    return nil if name.blank?

    # Same logic as Contact model
    name.downcase
        .gsub(/[^a-z0-9\s]/, '')
        .split
        .sort
        .join(' ')
  end

  def parse_address(address)
    return {} if address.blank?

    # Simple regex-based parsing
    data = {}

    # Try to extract zipcode
    if match = address.match(/\b(\d{5})\b/)
      data[:zipcode] = match[1]
    end

    # Try to extract state (2-letter code)
    if match = address.match(/\b([A-Z]{2})\b/)
      data[:state] = match[1]
    end

    # Try to extract city (word before state)
    if match = address.match(/,\s*([^,]+),\s*[A-Z]{2}/)
      data[:city] = match[1].strip
    end

    data
  end

  def extract_domain(url)
    return nil if url.blank?

    uri = URI.parse(url)
    uri.host
  rescue URI::InvalidURIError
    nil
  end
end
