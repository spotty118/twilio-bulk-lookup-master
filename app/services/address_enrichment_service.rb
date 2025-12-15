# frozen_string_literal: true

# AddressEnrichmentService - Enriches consumer contacts with address data
#
# This service attempts to find physical addresses for consumer contacts using:
# 1. Whitepages Pro (best for US addresses)
# 2. TrueCaller (good for mobile numbers)
# 3. Existing data fallback (country/state level)
#
# All external API calls are protected by circuit breakers to prevent cascade failures.
#
# Usage:
#   AddressEnrichmentService.new(contact).enrich
#
class AddressEnrichmentService
  include HTTParty

  # Configure HTTParty defaults
  default_timeout 10
  headers 'User-Agent' => 'TwilioBulkLookup/1.0'

  attr_reader :contact

  def initialize(contact)
    @contact = contact
    @credentials = TwilioCredential.current
  end

  # ========================================
  # Main Entry Point
  # ========================================

  def enrich
    # Only enrich consumers (not businesses)
    unless @contact.consumer?
      Rails.logger.info "[AddressEnrichmentService] Skipping #{@contact.id}: Not a consumer contact"
      return false
    end

    # Skip if already enriched
    if @contact.address_enriched?
      Rails.logger.info "[AddressEnrichmentService] Skipping #{@contact.id}: Already enriched"
      return false
    end

    # Must have a phone number
    unless @contact.raw_phone_number.present?
      Rails.logger.warn "[AddressEnrichmentService] Skipping #{@contact.id}: No phone number"
      return false
    end

    Rails.logger.info "[AddressEnrichmentService] Starting address enrichment for contact #{@contact.id}"

    address_data = find_address

    if address_data
      update_contact_address(address_data)
      Rails.logger.info "[AddressEnrichmentService] Successfully enriched address for contact #{@contact.id}"
      true
    else
      Rails.logger.warn "[AddressEnrichmentService] No address found for contact #{@contact.id}"
      false
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    Rails.logger.error "[AddressEnrichmentService] Database error enriching #{@contact.id}: #{e.message}"
    false
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[AddressEnrichmentService] Contact not found #{@contact.id}: #{e.message}"
    false
  end

  private

  # ========================================
  # Address Discovery
  # ========================================

  def find_address
    # Try providers in order of data quality
    address_data = nil

    # 1. Try Whitepages Pro (best for US addresses)
    if @credentials&.whitepages_api_key.present?
      address_data = try_whitepages
      return address_data if address_data
    end

    # 2. Try TrueCaller (good for mobile)
    if @credentials&.truecaller_api_key.present?
      address_data = try_truecaller
      return address_data if address_data
    end

    # 3. Fallback: Extract from existing data
    address_data = extract_from_existing_data
    return address_data if address_data

    nil
  end

  # ========================================
  # Whitepages Pro API
  # ========================================

  def try_whitepages
    api_key = @credentials.whitepages_api_key
    phone = normalize_phone(@contact.raw_phone_number)

    # Use circuit breaker for Whitepages API
    result = CircuitBreakerService.call(:whitepages) do
      self.class.get(
        'https://proapi.whitepages.com/3.0/phone',
        query: {
          phone: phone,
          api_key: api_key
        }
      )
    end

    # Handle circuit breaker fallback
    return nil if result.is_a?(Hash) && result[:circuit_open]

    return nil unless result.success?

    data = result.parsed_response

    # Extract address from belongs_to -> current_addresses
    belongs_to = data.dig('belongs_to', 0)
    return nil unless belongs_to

    current_address = belongs_to.dig('current_addresses', 0)
    return nil unless current_address

    parse_whitepages_address(current_address, belongs_to)
  rescue HTTParty::Error => e
    Rails.logger.error "[AddressEnrichmentService] Whitepages error: #{e.message}"
    nil
  rescue JSON::ParserError => e
    Rails.logger.error "[AddressEnrichmentService] Whitepages invalid JSON: #{e.message}"
    nil
  end

  def parse_whitepages_address(address_data, person_data)
    {
      address: address_data['street_line_1'],
      city: address_data['city'],
      state: address_data['state_code'],
      postal_code: address_data['postal_code'],
      country: address_data['country_code'] || 'US',
      address_type: address_data['location_type'], # residential, business, etc.
      verified: address_data['is_valid'] == true,
      confidence_score: calculate_confidence(address_data),
      provider: 'whitepages',
      # Additional person info
      first_name: person_data&.dig('names', 0, 'first_name'),
      last_name: person_data&.dig('names', 0, 'last_name')
    }
  end

  # ========================================
  # TrueCaller API
  # ========================================

  def try_truecaller
    api_key = @credentials.truecaller_api_key
    phone = normalize_phone(@contact.raw_phone_number)

    # Use circuit breaker for TrueCaller API
    result = CircuitBreakerService.call(:truecaller) do
      self.class.get(
        'https://api4.truecaller.com/v1/search',
        query: {
          q: phone,
          countryCode: 'US',
          type: 'phone'
        },
        headers: { 'Authorization' => "Bearer #{api_key}" }
      )
    end

    # Handle circuit breaker fallback
    return nil if result.is_a?(Hash) && result[:circuit_open]

    return nil unless result.success?

    data = result.parsed_response
    address_data = data.dig('data', 0, 'addresses', 0)
    return nil unless address_data

    {
      address: address_data['street'],
      city: address_data['city'],
      state: address_data['state'],
      postal_code: address_data['zipCode'],
      country: address_data['countryCode'] || 'US',
      address_type: address_data['type'],
      verified: true,
      confidence_score: 80,
      provider: 'truecaller',
      first_name: data.dig('data', 0, 'name', 'first'),
      last_name: data.dig('data', 0, 'name', 'last')
    }
  rescue HTTParty::Error => e
    Rails.logger.error "[AddressEnrichmentService] TrueCaller error: #{e.message}"
    nil
  rescue JSON::ParserError => e
    Rails.logger.error "[AddressEnrichmentService] TrueCaller invalid JSON: #{e.message}"
    nil
  end

  # ========================================
  # Fallback: Extract from Existing Data
  # ========================================

  def extract_from_existing_data
    # If we have caller name data with location info from Twilio
    # Or if NumVerify gave us location data
    return nil unless @contact.country_code.present?

    # Very basic fallback - just country/state level
    {
      city: nil,
      state: nil,
      postal_code: nil,
      country: @contact.country_code,
      address_type: 'unknown',
      verified: false,
      confidence_score: 20,
      provider: 'twilio_basic'
    }
  end

  # ========================================
  # Update Contact
  # ========================================

  def update_contact_address(address_data)
    updates = {
      consumer_address: address_data[:address],
      consumer_city: address_data[:city],
      consumer_state: address_data[:state],
      consumer_postal_code: address_data[:postal_code],
      consumer_country: address_data[:country] || 'USA',
      address_type: address_data[:address_type],
      address_verified: address_data[:verified],
      address_enriched: true,
      address_enrichment_provider: address_data[:provider],
      address_enriched_at: Time.current,
      address_confidence_score: address_data[:confidence_score]
    }

    # Also update name fields if we got them and they're empty
    updates[:first_name] = address_data[:first_name] if address_data[:first_name].present? && @contact.first_name.blank?

    updates[:last_name] = address_data[:last_name] if address_data[:last_name].present? && @contact.last_name.blank?

    @contact.update!(updates)
    @contact.calculate_quality_score!

    # Trigger Verizon coverage check if address is good enough
    return unless should_check_verizon_coverage?

    VerizonCoverageCheckJob.perform_later(@contact.id)
  end

  def should_check_verizon_coverage?
    # Only check if we have a full address with confidence >= 60
    @contact.consumer_address.present? &&
      @contact.consumer_city.present? &&
      @contact.consumer_state.present? &&
      @contact.consumer_postal_code.present? &&
      (@contact.address_confidence_score || 0) >= 60 &&
      @credentials&.enable_verizon_coverage_check
  end

  # ========================================
  # Helper Methods
  # ========================================

  def normalize_phone(phone)
    return nil if phone.blank?

    digits = phone.gsub(/\D/, '') # Remove non-digits
    # Only remove leading 1 if it's an 11-digit number (US country code)
    # Don't remove leading 1 from toll-free numbers like 800, 888, etc.
    digits.length == 11 && digits[0] == '1' ? digits[1..-1] : digits
  end

  def calculate_confidence(address_data)
    score = 0
    score += 20 if address_data['street_line_1'].present?
    score += 20 if address_data['city'].present?
    score += 20 if address_data['state_code'].present?
    score += 20 if address_data['postal_code'].present?
    score += 20 if address_data['is_valid'] == true
    score
  end
end
