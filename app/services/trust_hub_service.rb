require 'twilio-ruby'

class TrustHubService
  # Main entry point for enriching contact with Trust Hub verification data
  def self.enrich(contact)
    new(contact).enrich
  end

  def initialize(contact)
    @contact = contact
    @phone_number = contact.formatted_phone_number || contact.raw_phone_number
    @credential = TwilioCredential.current
  end

  def enrich
    # Only enrich if it's a business and Trust Hub is enabled
    return false unless should_enrich?
    return false unless trust_hub_enabled?

    # Try to find or create Trust Hub verification
    result = lookup_trust_hub_verification || create_trust_hub_verification

    if result
      update_contact_with_trust_hub_data(result)
      true
    else
      log_no_data_found
      false
    end
  rescue StandardError => e
    handle_error(e)
    false
  end

  private

  def should_enrich?
    # Only enrich businesses that haven't been enriched yet or need re-verification
    @contact.is_business && (!@contact.trust_hub_enriched || should_reverify?)
  end

  def should_reverify?
    # Re-verify if status is pending or failed, or if enriched more than 90 days ago
    return true if %w[pending-review twilio-rejected draft].include?(@contact.trust_hub_status)
    return false unless @contact.trust_hub_enriched_at

    @contact.trust_hub_enriched_at < 90.days.ago
  end

  def trust_hub_enabled?
    @credential&.enable_trust_hub == true
  end

  def twilio_client
    @twilio_client ||= Twilio::REST::Client.new(
      @credential.account_sid,
      @credential.auth_token
    )
  end

  # Lookup existing Trust Hub customer profile by phone number
  def lookup_trust_hub_verification
    return nil unless @contact.business_name.present?

    # Search for existing customer profiles that might match
    customer_profiles = twilio_client.trusthub.v1.customer_profiles.list(limit: 20)

    # Try to find a matching profile by business name or phone
    matching_profile = customer_profiles.find do |profile|
      matches_profile?(profile)
    end

    return nil unless matching_profile

    # Get detailed profile information
    fetch_profile_details(matching_profile)
  rescue Twilio::REST::RestError => e
    Rails.logger.warn("Trust Hub lookup error: #{e.message}")
    nil
  end

  def matches_profile?(profile)
    # Match by friendly name (business name) or policy sid
    return false unless profile.friendly_name.present?

    business_name_normalized = normalize_name(@contact.business_name)
    profile_name_normalized = normalize_name(profile.friendly_name)

    profile_name_normalized.include?(business_name_normalized) ||
      business_name_normalized.include?(profile_name_normalized)
  end

  def normalize_name(name)
    return '' unless name
    name.downcase.gsub(/[^a-z0-9]/, '')
  end

  # Create new Trust Hub customer profile for verification
  def create_trust_hub_verification
    return nil unless can_create_profile?

    # Build customer profile data
    profile_data = build_profile_data

    # Create customer profile (requires manual submission)
    # Note: This creates a draft profile that needs to be submitted with documents
    profile = twilio_client.trusthub.v1.customer_profiles.create(
      friendly_name: @contact.business_name,
      email: infer_business_email,
      policy_sid: get_policy_sid,
      status_callback: status_callback_url
    )

    # Add business information to the profile
    add_business_information(profile)

    {
      status: 'draft',
      customer_profile_sid: profile.sid,
      business_name: @contact.business_name,
      verification_score: 0,
      verification_data: {
        profile_sid: profile.sid,
        created: true,
        requires_documents: true
      }
    }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("Trust Hub creation error: #{e.message}")
    @contact.update(trust_hub_error: e.message)
    nil
  end

  def can_create_profile?
    # Need business name and some contact info to create profile
    @contact.business_name.present? && (
      @contact.business_email_domain.present? ||
      @contact.business_address.present?
    )
  end

  def build_profile_data
    {
      business_name: @contact.business_name,
      business_type: @contact.business_type || 'corporation',
      business_registration_number: @contact.trust_hub_registration_number,
      business_address: build_address_data,
      phone_number: @phone_number,
      website: @contact.business_website,
      email_domain: @contact.business_email_domain
    }
  end

  def build_address_data
    return nil unless @contact.business_address.present?

    {
      street: @contact.business_address,
      city: @contact.business_city,
      state: @contact.business_state,
      postal_code: @contact.business_postal_code,
      country: @contact.business_country || 'US'
    }
  end

  def infer_business_email
    return nil unless @contact.business_email_domain.present?
    "info@#{@contact.business_email_domain}"
  end

  def get_policy_sid
    # Use appropriate policy based on business type
    # Common Twilio policy SIDs for different business types
    # Note: These should be configured in TwilioCredential
    @credential.trust_hub_policy_sid || 'RNb0d4771c2c98518d0cbc1ae32c55c3e8' # Default business profile policy
  end

  def status_callback_url
    # Webhook URL for Trust Hub status updates
    return nil unless @credential.trust_hub_webhook_url.present?
    @credential.trust_hub_webhook_url
  end

  def add_business_information(profile)
    # Add end-user (business entity) to the customer profile
    end_user = twilio_client.trusthub.v1.end_users.create(
      friendly_name: @contact.business_name,
      type: 'business',
      attributes: {
        business_name: @contact.business_name,
        business_registration_number: @contact.trust_hub_registration_number,
        business_type: map_business_type(@contact.business_type),
        phone_number: @phone_number,
        email: infer_business_email
      }.compact
    )

    # Assign end user to customer profile
    twilio_client.trusthub.v1
                 .customer_profiles(profile.sid)
                 .customer_profiles_entity_assignments
                 .create(object_sid: end_user.sid)
  rescue Twilio::REST::RestError => e
    Rails.logger.warn("Could not add business info to Trust Hub profile: #{e.message}")
  end

  def map_business_type(type)
    # Map our business types to Twilio's expected types
    case type&.downcase
    when 'corporation', 'corp', 'inc'
      'corporation'
    when 'llc', 'limited liability company'
      'llc'
    when 'partnership'
      'partnership'
    when 'sole proprietorship', 'individual'
      'sole_proprietorship'
    when 'non-profit', 'nonprofit'
      'non_profit'
    else
      'other'
    end
  end

  # Fetch detailed information about a customer profile
  def fetch_profile_details(profile)
    # Get the full profile with all assignments
    full_profile = twilio_client.trusthub.v1.customer_profiles(profile.sid).fetch

    # Calculate verification score based on status and completeness
    verification_score = calculate_verification_score(full_profile)

    # Parse compliance checks
    checks_completed = []
    checks_failed = []

    # Get trust products associated with this profile (if any)
    trust_products = get_trust_products(profile.sid)

    {
      status: full_profile.status,
      customer_profile_sid: full_profile.sid,
      business_name: full_profile.friendly_name,
      business_type: extract_business_type(full_profile),
      registration_number: extract_registration_number(full_profile),
      regulatory_status: full_profile.status,
      compliance_type: full_profile.policy_sid,
      verification_score: verification_score,
      verification_data: {
        profile_sid: full_profile.sid,
        policy_sid: full_profile.policy_sid,
        status: full_profile.status,
        valid_until: full_profile.valid_until,
        trust_products: trust_products
      },
      checks_completed: checks_completed,
      checks_failed: checks_failed,
      verified_at: full_profile.date_updated
    }
  rescue Twilio::REST::RestError => e
    Rails.logger.error("Error fetching Trust Hub details: #{e.message}")
    nil
  end

  def get_trust_products(customer_profile_sid)
    # Trust Products link customer profiles to actual services
    products = twilio_client.trusthub.v1.trust_products.list(limit: 20)
    products.select { |p| p.customer_profile_sid == customer_profile_sid }
            .map { |p| { sid: p.sid, status: p.status, policy_sid: p.policy_sid } }
  rescue Twilio::REST::RestError => e
    Rails.logger.warn("Could not fetch trust products: #{e.message}")
    []
  end

  def calculate_verification_score(profile)
    # Calculate a 0-100 score based on verification status
    case profile.status
    when 'twilio-approved'
      100
    when 'compliant'
      95
    when 'pending-review'
      50
    when 'in-review'
      60
    when 'twilio-rejected', 'rejected'
      0
    when 'draft'
      10
    else
      25
    end
  end

  def extract_business_type(profile)
    # Try to extract business type from profile attributes
    # This would come from the end_user attributes
    nil # Placeholder - would need to query end_users
  end

  def extract_registration_number(profile)
    # Try to extract registration number from profile attributes
    nil # Placeholder - would need to query end_users
  end

  def update_contact_with_trust_hub_data(data)
    @contact.update!(
      trust_hub_verified: data[:status] == 'twilio-approved' || data[:status] == 'compliant',
      trust_hub_status: data[:status],
      trust_hub_customer_profile_sid: data[:customer_profile_sid],
      trust_hub_business_name: data[:business_name],
      trust_hub_business_type: data[:business_type],
      trust_hub_registration_number: data[:registration_number],
      trust_hub_regulatory_status: data[:regulatory_status],
      trust_hub_compliance_type: data[:compliance_type],
      trust_hub_verified_at: data[:verified_at] || Time.current,
      trust_hub_verification_score: data[:verification_score],
      trust_hub_verification_data: data[:verification_data],
      trust_hub_checks_completed: data[:checks_completed],
      trust_hub_checks_failed: data[:checks_failed],
      trust_hub_enriched: true,
      trust_hub_enriched_at: Time.current,
      trust_hub_error: nil
    )
  end

  def log_no_data_found
    Rails.logger.info("No Trust Hub data found for #{@phone_number}")
  end

  def handle_error(error)
    error_message = "Trust Hub enrichment error for #{@phone_number}: #{error.message}"
    Rails.logger.error(error_message)
    Rails.logger.error(error.backtrace.join("\n"))

    @contact.update(
      trust_hub_error: error.message,
      trust_hub_enriched_at: Time.current
    )
  end
end
