require 'net/http'
require 'json'
require 'uri'

class VerizonCoverageService
  attr_reader :contact

  def initialize(contact)
    @contact = contact
    @credentials = TwilioCredential.current
  end

  # ========================================
  # Main Entry Point
  # ========================================

  def check_coverage
    # Validate we have address data
    unless has_valid_address?
      Rails.logger.warn "[VerizonCoverageService] Contact #{@contact.id}: No valid address"
      return false
    end

    # Skip if already checked recently (within 30 days)
    if recently_checked?
      Rails.logger.info "[VerizonCoverageService] Contact #{@contact.id}: Already checked recently"
      return false
    end

    Rails.logger.info "[VerizonCoverageService] Checking Verizon coverage for contact #{@contact.id}"

    coverage_data = fetch_coverage_data

    if coverage_data
      update_contact_coverage(coverage_data)
      Rails.logger.info "[VerizonCoverageService] Successfully checked coverage for contact #{@contact.id}"
      true
    else
      mark_coverage_checked
      Rails.logger.warn "[VerizonCoverageService] Unable to determine coverage for contact #{@contact.id}"
      false
    end

  rescue StandardError => e
    Rails.logger.error "[VerizonCoverageService] Error checking coverage for contact #{@contact.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    mark_coverage_checked
    false
  end

  private

  # ========================================
  # Coverage Data Fetching
  # ========================================

  def fetch_coverage_data
    # Try different methods in order
    coverage_data = nil

    # Method 1: Verizon public API endpoint (if available)
    coverage_data = try_verizon_public_api
    return coverage_data if coverage_data

    # Method 2: FCC broadband availability data
    coverage_data = try_fcc_broadband_data
    return coverage_data if coverage_data

    # Method 3: Generic coverage estimation based on location
    coverage_data = estimate_coverage_by_location
    return coverage_data if coverage_data

    nil
  end

  # ========================================
  # Method 1: Verizon Public API
  # ========================================

  def try_verizon_public_api
    # Verizon has public endpoints for checking service availability
    # This endpoint checks for home internet products
    uri = URI('https://www.verizon.com/sales/nextgen/apigateway/v1/serviceability/home')

    payload = {
      address: {
        addressLine1: @contact.consumer_address,
        city: @contact.consumer_city,
        state: @contact.consumer_state,
        zipCode: @contact.consumer_postal_code
      }
    }

    response = HttpClient.post(uri, body: payload, circuit_name: 'verizon-api') do |request|
      request['Accept'] = 'application/json'
      request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    end

    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    parse_verizon_response(data)

  rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
    Rails.logger.warn "[VerizonCoverageService] Verizon API error: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "[VerizonCoverageService] Verizon API error: #{e.message}"
    nil
  end

  def parse_verizon_response(data)
    # Parse Verizon's response structure
    # Structure varies, but typically includes available products
    products = data.dig('serviceability', 'products') || data['products'] || []

    {
      fios_available: products.any? { |p| p['name']&.downcase&.include?('fios') },
      five_g_available: products.any? { |p| p['name']&.downcase&.include?('5g home') },
      lte_available: products.any? { |p| p['name']&.downcase&.include?('lte home') },
      download_speed: extract_speed(products, 'download'),
      upload_speed: extract_speed(products, 'upload'),
      raw_data: data,
      method: 'verizon_api'
    }
  end

  def extract_speed(products, direction)
    # Find the fastest speed advertised
    speeds = products.map do |product|
      speed_data = product.dig('speeds', direction) || product[direction]
      next unless speed_data

      # Extract numeric value (e.g., "940 Mbps" -> 940)
      speed_data.to_s.scan(/\d+/).first&.to_i
    end.compact

    return nil if speeds.empty?

    max_speed = speeds.max
    min_speed = speeds.min

    if max_speed == min_speed
      "#{max_speed} Mbps"
    else
      "#{min_speed}-#{max_speed} Mbps"
    end
  end

  # ========================================
  # Method 2: FCC Broadband Data
  # ========================================

  def try_fcc_broadband_data
    # Use FCC's Broadband Map API
    # This provides data on all ISPs including Verizon
    uri = URI('https://broadbandmap.fcc.gov/api/public/map/basic/results')

    params = {
      latitude: get_latitude,
      longitude: get_longitude,
      technology: 'fixed_wireless' # Covers 5G/LTE home
    }

    return nil unless params[:latitude] && params[:longitude]

    uri.query = URI.encode_www_form(params)

    response = HttpClient.get(uri, circuit_name: 'fcc-broadband-api')
    return nil unless response.code == '200'

    data = JSON.parse(response.body)
    parse_fcc_data(data)

  rescue HttpClient::TimeoutError, HttpClient::CircuitOpenError => e
    Rails.logger.warn "[VerizonCoverageService] FCC API error: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "[VerizonCoverageService] FCC API error: #{e.message}"
    nil
  end

  def parse_fcc_data(data)
    # Find Verizon in the providers list
    providers = data['results'] || []
    verizon_data = providers.find do |p|
      p['provider_name']&.downcase&.include?('verizon')
    end

    return nil unless verizon_data

    {
      fios_available: verizon_data['technology']&.include?('fiber'),
      five_g_available: verizon_data['technology']&.include?('5g'),
      lte_available: verizon_data['technology']&.include?('lte'),
      download_speed: verizon_data['max_download'],
      upload_speed: verizon_data['max_upload'],
      raw_data: verizon_data,
      method: 'fcc_data'
    }
  end

  # ========================================
  # Method 3: Coverage Estimation
  # ========================================

  def estimate_coverage_by_location
    # Last resort: estimate based on zipcode and known coverage areas
    zipcode = @contact.consumer_postal_code
    state = @contact.consumer_state

    return nil unless zipcode && state

    # Validate zipcode length before slicing
    return nil if zipcode.length < 3

    # Verizon 5G Home is available in limited markets
    # Major cities and suburbs typically have coverage
    five_g_markets = major_5g_markets
    lte_markets = major_lte_markets

    zip_prefix = zipcode[0..2]

    {
      fios_available: nil, # Can't estimate without specific data
      five_g_available: five_g_markets.include?(zip_prefix),
      lte_available: lte_markets.include?(zip_prefix),
      download_speed: nil,
      upload_speed: nil,
      raw_data: { note: 'Estimated based on known coverage areas' },
      method: 'estimation'
    }
  end

  def major_5g_markets
    # Major metropolitan areas with Verizon 5G Home
    # Based on public coverage maps (as of 2024)
    [
      # New York Metro
      '100', '101', '102', '103', '104', '105', '106', '107', '108', '109',
      '110', '111', '112', '113', '114', '115', '116', '117', '118', '119',
      # Los Angeles Metro
      '900', '901', '902', '903', '904', '905', '906', '907', '908',
      # Chicago Metro
      '600', '601', '602', '603', '604', '605', '606', '607', '608', '609',
      # Houston Metro
      '770', '771', '772', '773', '774', '775',
      # Philadelphia Metro
      '190', '191', '192', '193', '194',
      # Phoenix Metro
      '850', '851', '852', '853',
      # San Francisco Bay Area
      '940', '941', '942', '943', '944', '945', '946', '947', '948', '949',
      '950', '951', '952', '953', '954', '955', '956', '957', '958', '959',
      # Washington DC Metro
      '200', '201', '202', '203', '204', '205',
      # Boston Metro
      '021', '022', '023', '024', '025',
      # Miami Metro
      '330', '331', '332', '333', '334', '335', '336', '337', '338', '339'
    ]
  end

  def major_lte_markets
    # Broader LTE Home coverage (includes 5G markets plus more)
    major_5g_markets + [
      # Additional LTE markets
      '750', '751', '752', # Dallas
      '300', '301', '302', # Atlanta
      '630', '631', '632', # St. Louis
      '550', '551', '552', # Minneapolis
      '980', '981', '982', # Seattle
      '970', '971', '972', # Portland
      '890', '891', '892', '893', '894', '895' # Las Vegas
    ]
  end

  # ========================================
  # Geocoding Helper
  # ========================================

  def get_latitude
    # Use contact's geocoded coordinates if available
    @contact.latitude
  end

  def get_longitude
    # Use contact's geocoded coordinates if available
    @contact.longitude
  end

  # ========================================
  # Update Contact
  # ========================================

  def update_contact_coverage(coverage_data)
    updates = {
      verizon_5g_home_available: coverage_data[:five_g_available],
      verizon_lte_home_available: coverage_data[:lte_available],
      verizon_fios_available: coverage_data[:fios_available],
      verizon_coverage_checked: true,
      verizon_coverage_checked_at: Time.current,
      verizon_coverage_data: coverage_data[:raw_data],
      estimated_download_speed: coverage_data[:download_speed],
      estimated_upload_speed: coverage_data[:upload_speed]
    }

    @contact.update!(updates)
  end

  def mark_coverage_checked
    @contact.update!(
      verizon_coverage_checked: true,
      verizon_coverage_checked_at: Time.current
    )
  end

  # ========================================
  # Validation
  # ========================================

  def has_valid_address?
    @contact.consumer_address.present? &&
      @contact.consumer_city.present? &&
      @contact.consumer_state.present? &&
      @contact.consumer_postal_code.present?
  end

  def recently_checked?
    @contact.verizon_coverage_checked? &&
      @contact.verizon_coverage_checked_at.present? &&
      @contact.verizon_coverage_checked_at > 30.days.ago
  end
end
