require 'net/http'
require 'json'

class OpenCellIdService
  API_BASE_URL = 'https://opencellid.org'
  VERIZON_MNC = 13 # Mobile Network Code for Verizon

  attr_reader :latitude, :longitude

  def initialize(latitude, longitude)
    raise ArgumentError, 'Latitude and longitude are required' if latitude.blank? || longitude.blank?
    raise ArgumentError, 'Invalid coordinates' unless valid_coordinates?(latitude, longitude)

    @latitude = latitude.to_f
    @longitude = longitude.to_f
  end

  # Fetch cell towers within radius
  # radio_type: 'LTE', 'NR' (5G), or 'all'
  # radius_km: Search radius in kilometers
  def fetch_nearby_towers(radio_type = 'all', radius_km = 10)
    api_key = ENV['OPENCELLID_API_KEY'] || OpenCellId[:api_key]

    if api_key.blank?
      Rails.logger.warn '[OpenCellID] API key not configured, returning no towers. Set OPENCELLID_API_KEY environment variable for tower-based probability calculation.'
      return []
    end

    begin
      uri = build_api_uri(radio_type, radius_km, api_key)
      response = fetch_with_retry(uri)

      if response.is_a?(Net::HTTPSuccess)
        parse_response(response.body)
      else
        Rails.logger.error "[OpenCellID] API error: #{response.code} - #{response.body}"
        []
      end
    rescue StandardError => e
      Rails.logger.error "[OpenCellID] Error fetching towers: #{e.message}"
      []
    end
  end

  # Calculate distance between two coordinates using Haversine formula
  # Returns distance in kilometers
  def self.calculate_distance(lat1, lon1, lat2, lon2)
    lat1_rad = lat1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    delta_lat = (lat2 - lat1) * Math::PI / 180
    delta_lon = (lon2 - lon1) * Math::PI / 180

    a = Math.sin(delta_lat / 2) ** 2 +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) *
        Math.sin(delta_lon / 2) ** 2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    earth_radius_km = 6371.0
    earth_radius_km * c
  end

  private

  def valid_coordinates?(lat, lon)
    lat = lat.to_f
    lon = lon.to_f
    lat.between?(-90, 90) && lon.between?(-180, 180)
  end

  def build_api_uri(radio_type, radius_km, api_key)
    params = {
      key: api_key,
      lat: @latitude,
      lon: @longitude,
      radius: (radius_km * 1000).to_i, # Convert km to meters
      format: 'json'
    }

    # Add radio type filter if not 'all'
    params[:radio] = radio_type unless radio_type == 'all'

    query_string = URI.encode_www_form(params)
    URI("#{API_BASE_URL}/cell/getInArea?#{query_string}")
  end

  def fetch_with_retry(uri, retries = 2)
    timeout_config = OpenCellId[:timeout] || 10

    begin
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                      open_timeout: timeout_config, read_timeout: timeout_config) do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      if retries > 0
        Rails.logger.warn "[OpenCellID] Timeout, retrying... (#{retries} retries left)"
        sleep(1)
        fetch_with_retry(uri, retries - 1)
      else
        Rails.logger.error "[OpenCellID] Timeout after all retries: #{e.message}"
        raise
      end
    end
  end

  def parse_response(body)
    data = JSON.parse(body)

    # OpenCellID returns an array of towers or an object with cells
    towers = data.is_a?(Array) ? data : (data['cells'] || [])

    # Filter for Verizon towers only (mnc = 13)
    verizon_towers = towers.select { |tower| tower['mnc']&.to_i == VERIZON_MNC }

    # Calculate distance for each tower and sort by distance
    verizon_towers.map do |tower|
      tower_lat = tower['lat'].to_f
      tower_lon = tower['lon'].to_f
      distance = self.class.calculate_distance(@latitude, @longitude, tower_lat, tower_lon)

      {
        radio: tower['radio'],
        mcc: tower['mcc']&.to_i,
        mnc: tower['mnc']&.to_i,
        lat: tower_lat,
        lon: tower_lon,
        range: tower['range']&.to_i, # Coverage radius in meters (may be nil)
        distance: distance.round(2)
      }
    end.sort_by { |tower| tower[:distance] }
  rescue JSON::ParserError => e
    Rails.logger.error "[OpenCellID] Invalid JSON response: #{e.message}"
    []
  end
end
