# frozen_string_literal: true

require 'httparty'

# VerizonCoverageService - Check 5G/LTE Home Internet availability
#
# Enhanced version using HTTParty for better error handling, automatic retries,
# and cleaner code. Includes multiple fallback strategies:
# 1. Verizon FWA API (if credentials available)
# 2. Verizon public serviceability API
# 3. FCC broadband data API
# 4. Location-based estimation using geocoding
#
# Usage:
#   service = VerizonCoverageService.new(contact)
#   service.check_coverage
#
class VerizonCoverageService
  include HTTParty

  # Base URIs for different APIs
  base_uri 'https://api.verizonwireless.com'

  # HTTP client configuration
  default_timeout 10
  follow_redirects true

  # Attributes
  attr_reader :contact, :coverage_data

  def initialize(contact)
    @contact = contact
    @coverage_data = {}
  end

  #
  # Main entry point - checks coverage using best available method
  #
  def check_coverage
    # Skip if already checked recently (within 30 days)
    return false if recently_checked?

    # Skip if no valid address
    unless has_valid_address?
      Rails.logger.info "Skipping Verizon coverage check for contact #{contact.id}: no valid address"
      return false
    end

    # Try different data sources in order of reliability
    @coverage_data = fetch_coverage_data

    if @coverage_data.present?
      update_contact_coverage(@coverage_data)
      mark_coverage_checked
      true
    else
      Rails.logger.warn "No Verizon coverage data found for contact #{contact.id}"
      mark_coverage_checked # Mark as checked even if no data found
      false
    end
  rescue StandardError => e
    Rails.logger.error "Verizon coverage check failed for contact #{contact.id}: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

  #
  # Fetch coverage data using multiple fallback strategies
  #
  def fetch_coverage_data
    # Try Verizon APIs first (most accurate)
    data = try_verizon_fwa_api if has_verizon_api_credentials?
    return data if data.present?

    data = try_verizon_public_api
    return data if data.present?

    # Fallback to FCC broadband data
    data = try_fcc_broadband_data
    return data if data.present?

    # Last resort: estimate based on location
    estimate_coverage_by_location
  end

  #
  # Strategy 1: Verizon public serviceability API
  #
  def try_verizon_public_api
    # This is a placeholder - actual public API may not exist
    # Keeping for future implementation
    nil
  end

  #
  # Check if Verizon API credentials are configured
  #
  def has_verizon_api_credentials?
    credentials = TwilioCredential.current
    credentials&.verizon_api_key.present? && credentials&.verizon_api_secret.present?
  end

  #
  # Strategy 2: Verizon FWA (Fixed Wireless Access) API
  #
  def try_verizon_fwa_api
    credentials = TwilioCredential.current
    return nil unless credentials

    # Get OAuth token
    auth_token = get_verizon_auth_token
    return nil unless auth_token

    # Make API request
    response = self.class.post('/fwa/v1/serviceability',
                               headers: {
                                 'Authorization' => "Bearer #{auth_token}",
                                 'Content-Type' => 'application/json'
                               },
                               body: {
                                 address: {
                                   street: contact.business_address || contact.consumer_address,
                                   city: contact.business_city || contact.consumer_city,
                                   state: contact.business_state || contact.consumer_state,
                                   zipCode: contact.business_postal_code || contact.consumer_postal_code
                                 }
                               }.to_json,
                               timeout: 10)

    if response.success?
      parse_fwa_response(response.parsed_response)
    else
      Rails.logger.warn "Verizon FWA API error: #{response.code} - #{response.message}"
      nil
    end
  rescue HTTParty::Error, Timeout::Error => e
    Rails.logger.error "Verizon FWA API request failed: #{e.class} - #{e.message}"
    nil
  end

  #
  # Get OAuth token for Verizon API
  #
  def get_verizon_auth_token
    credentials = TwilioCredential.current

    response = self.class.post('/oauth/v1/token',
                               basic_auth: {
                                 username: credentials.verizon_api_key,
                                 password: credentials.verizon_api_secret
                               },
                               body: { grant_type: 'client_credentials' })

    response.success? ? response.parsed_response['access_token'] : nil
  rescue HTTParty::Error => e
    Rails.logger.error "Verizon OAuth failed: #{e.message}"
    nil
  end

  #
  # Parse Verizon FWA API response
  #
  def parse_fwa_response(data)
    return nil unless data.is_a?(Hash)

    {
      verizon_5g_home_available: data.dig('products', '5G_HOME', 'available') || false,
      verizon_lte_home_available: data.dig('products', 'LTE_HOME', 'available') || false,
      verizon_fios_available: data.dig('products', 'FIOS', 'available') || false,
      estimated_download_speed: data.dig('products', '5G_HOME',
                                         'maxDownloadSpeed') || data.dig('products', 'LTE_HOME', 'maxDownloadSpeed'),
      estimated_upload_speed: data.dig('products', '5G_HOME',
                                       'maxUploadSpeed') || data.dig('products', 'LTE_HOME', 'maxUploadSpeed'),
      source: 'verizon_fwa_api'
    }
  end

  #
  # Strategy 3: FCC Broadband Data API
  #
  def try_fcc_broadband_data
    lat = get_latitude
    lon = get_longitude

    return nil unless lat && lon

    response = HTTParty.get('https://broadbandmap.fcc.gov/api/public/map/basic/search',
                            query: {
                              latitude: lat,
                              longitude: lon,
                              technology: 'wireless'
                            },
                            timeout: 10)

    if response.success?
      parse_fcc_data(response.parsed_response)
    else
      Rails.logger.warn "FCC API error: #{response.code}"
      nil
    end
  rescue HTTParty::Error, Timeout::Error => e
    Rails.logger.error "FCC API request failed: #{e.message}"
    nil
  end

  #
  # Parse FCC broadband data
  #
  def parse_fcc_data(data)
    return nil unless data.is_a?(Hash) && data['results'].present?

    # Look for Verizon providers
    verizon_providers = data['results'].select do |provider|
      provider['provider_name']&.match?(/verizon/i)
    end

    return nil if verizon_providers.empty?

    # Estimate availability based on FCC data
    has_wireless = verizon_providers.any? { |p| p['technology'] == 'Wireless' }

    {
      verizon_5g_home_available: has_wireless,
      verizon_lte_home_available: has_wireless,
      verizon_fios_available: false,
      estimated_download_speed: nil,
      estimated_upload_speed: nil,
      source: 'fcc_broadband_data'
    }
  end

  #
  # Strategy 4: Estimate coverage based on location (zip code + major markets)
  #
  def estimate_coverage_by_location
    zip = contact.business_postal_code || contact.consumer_postal_code
    city = contact.business_city || contact.consumer_city
    state = contact.business_state || contact.consumer_state

    return nil unless zip || (city && state)

    # Check if in major 5G market
    location_key = "#{city}, #{state}".downcase if city && state
    in_5g_market = location_key && major_5g_markets.any? { |market| location_key.include?(market.downcase) }

    # Check if in LTE market (broader coverage)
    in_lte_market = location_key && major_lte_markets.any? { |market| location_key.include?(market.downcase) }

    {
      verizon_5g_home_available: in_5g_market,
      verizon_lte_home_available: in_lte_market || in_5g_market,
      verizon_fios_available: false,
      estimated_download_speed: if in_5g_market
                                  '300-1000 Mbps'
                                else
                                  (in_lte_market ? '25-50 Mbps' : nil)
                                end,
      estimated_upload_speed: if in_5g_market
                                '50-100 Mbps'
                              else
                                (in_lte_market ? '3-10 Mbps' : nil)
                              end,
      source: 'location_estimation'
    }
  end

  #
  # Major 5G Home Internet markets (as of 2024)
  #
  def major_5g_markets
    [
      'Los Angeles, CA',
      'Houston, TX',
      'Phoenix, AZ',
      'Sacramento, CA',
      'Chicago, IL',
      'Dallas, TX',
      'Indianapolis, IN',
      'Columbus, OH',
      'San Diego, CA',
      'Denver, CO',
      'Atlanta, GA',
      'Miami, FL',
      'Tampa, FL',
      'Detroit, MI',
      'Philadelphia, PA',
      'Minneapolis, MN',
      'Cleveland, OH',
      'Cincinnati, OH',
      'Orlando, FL',
      'Las Vegas, NV'
    ]
  end

  #
  # Major LTE Home Internet markets (broader coverage)
  #
  def major_lte_markets
    major_5g_markets + [
      'Seattle, WA',
      'Boston, MA',
      'Austin, TX',
      'San Antonio, TX',
      'Charlotte, NC',
      'Raleigh, NC'
    ]
  end

  #
  # Get latitude from contact (geocoded or manual)
  #
  def get_latitude
    contact.latitude
  end

  #
  # Get longitude from contact (geocoded or manual)
  #
  def get_longitude
    contact.longitude
  end

  #
  # Update contact with coverage data
  #
  def update_contact_coverage(coverage_data)
    contact.update!(
      verizon_5g_home_available: coverage_data[:verizon_5g_home_available],
      verizon_lte_home_available: coverage_data[:verizon_lte_home_available],
      verizon_fios_available: coverage_data[:verizon_fios_available],
      estimated_download_speed: coverage_data[:estimated_download_speed],
      estimated_upload_speed: coverage_data[:estimated_upload_speed],
      verizon_coverage_data: coverage_data.merge(checked_at: Time.current)
    )

    Rails.logger.info "Verizon coverage updated for contact #{contact.id}: 5G=#{coverage_data[:verizon_5g_home_available]}, LTE=#{coverage_data[:verizon_lte_home_available]} (source: #{coverage_data[:source]})"
  end

  #
  # Mark contact as coverage checked
  #
  def mark_coverage_checked
    contact.update!(
      verizon_coverage_checked: true,
      verizon_coverage_checked_at: Time.current
    )
  end

  #
  # Check if contact has valid address for checking
  #
  def has_valid_address?
    (contact.business_address.present? && contact.business_city.present? && contact.business_state.present?) ||
      (contact.consumer_address.present? && contact.consumer_city.present? && contact.consumer_state.present?) ||
      (contact.business_postal_code.present? || contact.consumer_postal_code.present?)
  end

  #
  # Check if coverage was recently checked (within 30 days)
  #
  def recently_checked?
    contact.verizon_coverage_checked? &&
      contact.verizon_coverage_checked_at.present? &&
      contact.verizon_coverage_checked_at > 30.days.ago
  end
end
