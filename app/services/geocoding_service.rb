class GeocodingService
  GOOGLE_GEOCODING_API_URL = 'https://maps.googleapis.com/maps/api/geocode/json'

  def initialize(contact)
    @contact = contact
    @credentials = TwilioCredential.current
  end

  def geocode!
    return { success: false, error: 'Geocoding not enabled' } unless @credentials&.enable_geocoding
    return { success: false, error: 'No Google Geocoding API key configured' } unless @credentials.google_geocoding_api_key.present?
    return { success: false, error: 'No address to geocode' } unless geocodable_address?

    start_time = Time.current

    begin
      address_string = build_address_string
      response = call_google_geocoding_api(address_string)

      if response['status'] == 'OK' && response['results'].present?
        result = response['results'].first
        location = result['geometry']['location']
        accuracy = result['geometry']['location_type']

        # Update contact with geocoded data
        @contact.update!(
          latitude: location['lat'],
          longitude: location['lng'],
          geocoding_accuracy: map_accuracy(accuracy),
          geocoding_provider: 'google',
          geocoded_at: Time.current
        )

        # Log API usage
        log_api_usage(
          service: 'geocode',
          status: 'success',
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: 200
        )

        {
          success: true,
          latitude: location['lat'],
          longitude: location['lng'],
          accuracy: map_accuracy(accuracy),
          formatted_address: result['formatted_address']
        }
      else
        error_msg = response['error_message'] || response['status']
        
        # Map internal error statuses to appropriate log statuses
        log_status = case response['status']
                     when 'TIMEOUT' then 'timeout'
                     when 'CIRCUIT_OPEN' then 'error'
                     else 'failed'
                     end

        log_api_usage(
          service: 'geocode',
          status: log_status,
          error_message: error_msg,
          response_time_ms: ((Time.current - start_time) * 1000).to_i
        )

        { success: false, error: error_msg }
      end
    rescue StandardError => e
      Rails.logger.error "Geocoding error for contact #{@contact.id}: #{e.message}"

      log_api_usage(
        service: 'geocode',
        status: 'error',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: e.message }
    end
  end

  # Reverse geocode coordinates to address
  def reverse_geocode(lat, lng)
    return { success: false, error: 'Geocoding not enabled' } unless @credentials&.enable_geocoding
    return { success: false, error: 'No Google Geocoding API key configured' } unless @credentials.google_geocoding_api_key.present?

    start_time = Time.current

    begin
      uri = URI(GOOGLE_GEOCODING_API_URL)
      params = {
        latlng: "#{lat},#{lng}",
        key: @credentials.google_geocoding_api_key
      }
      uri.query = URI.encode_www_form(params)

      http_response = HttpClient.get(uri, circuit_name: 'google-geocoding-api')
      response = JSON.parse(http_response.body)

      if response['status'] == 'OK' && response['results'].present?
        result = response['results'].first
        address_components = parse_address_components(result['address_components'])

        log_api_usage(
          service: 'reverse_geocode',
          status: 'success',
          response_time_ms: ((Time.current - start_time) * 1000).to_i,
          http_status_code: 200
        )

        {
          success: true,
          formatted_address: result['formatted_address'],
          **address_components
        }
      else
        error_msg = response['error_message'] || response['status']

        log_api_usage(
          service: 'reverse_geocode',
          status: 'failed',
          error_message: error_msg,
          response_time_ms: ((Time.current - start_time) * 1000).to_i
        )

        { success: false, error: error_msg }
      end
    rescue HttpClient::TimeoutError => e
      Rails.logger.error "Reverse geocoding timeout: #{e.message}"

      log_api_usage(
        service: 'reverse_geocode',
        status: 'timeout',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: "Request timed out" }
    rescue HttpClient::CircuitOpenError => e
      Rails.logger.warn "Reverse geocoding circuit open: #{e.message}"
      { success: false, error: "Service temporarily unavailable" }
    rescue StandardError => e
      Rails.logger.error "Reverse geocoding error: #{e.message}"

      log_api_usage(
        service: 'reverse_geocode',
        status: 'error',
        error_message: e.message,
        response_time_ms: ((Time.current - start_time) * 1000).to_i
      )

      { success: false, error: e.message }
    end
  end

  # Batch geocode contacts that need geocoding
  def self.batch_geocode!(limit: 100)
    contacts = Contact.where(geocoded_at: nil)
                      .where.not(consumer_address: nil)
                      .limit(limit)

    results = {
      total: contacts.count,
      successful: 0,
      failed: 0,
      errors: []
    }

    contacts.each do |contact|
      service = new(contact)
      result = service.geocode!

      if result[:success]
        results[:successful] += 1
      else
        results[:failed] += 1
        results[:errors] << { contact_id: contact.id, error: result[:error] }
      end

      # Rate limiting: Google allows ~50 requests/second
      sleep(0.02)
    end

    results
  end

  private

  def geocodable_address?
    @contact.consumer_address.present? || @contact.business_address.present?
  end

  def build_address_string
    if @contact.consumer_address.present?
      parts = [
        @contact.consumer_address,
        @contact.consumer_city,
        @contact.consumer_state,
        @contact.consumer_postal_code,
        @contact.consumer_country || 'US'
      ]
    else
      parts = [
        @contact.business_address,
        @contact.business_city,
        @contact.business_state,
        @contact.business_postal_code,
        @contact.business_country || 'US'
      ]
    end

    parts.compact.join(', ')
  end

  def call_google_geocoding_api(address)
    uri = URI(GOOGLE_GEOCODING_API_URL)
    params = {
      address: address,
      key: @credentials.google_geocoding_api_key
    }
    uri.query = URI.encode_www_form(params)

    response = HttpClient.get(uri, circuit_name: 'google-geocoding-api')
    JSON.parse(response.body)
  rescue HttpClient::TimeoutError => e
    Rails.logger.warn("Google Geocoding API timeout: #{e.message}")
    { 'status' => 'TIMEOUT', 'error_message' => e.message }
  rescue HttpClient::CircuitOpenError => e
    Rails.logger.warn("Google Geocoding circuit open: #{e.message}")
    { 'status' => 'CIRCUIT_OPEN', 'error_message' => e.message }
  end

  def map_accuracy(google_accuracy)
    case google_accuracy
    when 'ROOFTOP' then 'rooftop'
    when 'RANGE_INTERPOLATED' then 'range_interpolated'
    when 'GEOMETRIC_CENTER' then 'geometric_center'
    when 'APPROXIMATE' then 'approximate'
    else 'unknown'
    end
  end

  def parse_address_components(components)
    address_data = {}

    components.each do |component|
      types = component['types']

      if types.include?('street_number')
        address_data[:street_number] = component['long_name']
      elsif types.include?('route')
        address_data[:street] = component['long_name']
      elsif types.include?('locality')
        address_data[:city] = component['long_name']
      elsif types.include?('administrative_area_level_1')
        address_data[:state] = component['short_name']
      elsif types.include?('postal_code')
        address_data[:postal_code] = component['long_name']
      elsif types.include?('country')
        address_data[:country] = component['short_name']
      end
    end

    address_data
  end

  def log_api_usage(params)
    ApiUsageLog.log_api_call(
      contact_id: @contact.id,
      provider: 'google_geocoding',
      service: params[:service],
      endpoint: GOOGLE_GEOCODING_API_URL,
      status: params[:status],
      response_time_ms: params[:response_time_ms],
      http_status_code: params[:http_status_code],
      error_message: params[:error_message],
      requested_at: Time.current
    )
  end
end
