class Contact < ApplicationRecord
  # Include concerns for better organization
  include ErrorTrackable
  include StatusManageable

  # Broadcast changes for real-time dashboard updates
  after_update_commit :broadcast_status_update, if: :saved_change_to_status?
  after_create_commit :broadcast_refresh
  after_destroy_commit :broadcast_refresh

  # Update fingerprints for duplicate detection
  after_save :update_fingerprints_if_needed, if: :should_update_fingerprints?
  after_save :calculate_quality_score_if_needed, if: :should_calculate_quality?
  
  # Status workflow: pending -> processing -> completed/failed
  STATUSES = %w[pending processing completed failed].freeze
  
  # Validations
  validates :raw_phone_number, presence: true
  validates :raw_phone_number, 
            format: {
              with: /\A\+?[1-9]\d{1,14}\z/,
              message: "must be a valid phone number (E.164 format recommended, e.g., +14155551234)"
            },
            on: :create
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  
  # Scopes for filtering
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :not_processed, -> { where(status: ['pending', 'failed']) }

  # Fraud risk scopes
  scope :high_risk, -> { where(sms_pumping_risk_level: 'high') }
  scope :medium_risk, -> { where(sms_pumping_risk_level: 'medium') }
  scope :low_risk, -> { where(sms_pumping_risk_level: 'low') }
  scope :blocked_numbers, -> { where(sms_pumping_number_blocked: true) }

  # Line type scopes
  scope :mobile, -> { where(line_type: 'mobile') }
  scope :landline, -> { where(line_type: 'landline') }
  scope :voip, -> { where(line_type: ['voip', 'fixedVoip', 'nonFixedVoip']) }
  scope :toll_free, -> { where(line_type: 'tollFree') }

  # Validation scopes
  scope :valid_numbers, -> { where(valid: true) }
  scope :invalid_numbers, -> { where(valid: false) }

  # Business intelligence scopes
  scope :businesses, -> { where(is_business: true) }
  scope :consumers, -> { where(is_business: false) }
  scope :business_enriched, -> { where(business_enriched: true) }
  scope :needs_enrichment, -> { where(business_enriched: false, status: 'completed') }
  
  # Business size scopes
  scope :micro_businesses, -> { where(business_employee_range: '1-10') }
  scope :small_businesses, -> { where(business_employee_range: '11-50') }
  scope :medium_businesses, -> { where(business_employee_range: '51-200') }
  scope :large_businesses, -> { where(business_employee_range: ['201-500', '501-1000']) }
  scope :enterprise_businesses, -> { where(business_employee_range: ['1001-5000', '5001-10000', '10000+']) }
  
  # Business industry scopes
  scope :by_industry, ->(industry) { where(business_industry: industry) }
  scope :by_business_type, ->(type) { where(business_type: type) }

  # Email enrichment scopes
  scope :email_enriched, -> { where(email_enriched: true) }
  scope :with_verified_email, -> { where(email_verified: true) }
  scope :needs_email_enrichment, -> { where(email_enriched: false, business_enriched: true) }

  # Duplicate detection scopes
  scope :potential_duplicates, -> { where(is_duplicate: false).where('duplicate_checked_at IS NULL OR duplicate_checked_at < ?', 7.days.ago) }
  scope :confirmed_duplicates, -> { where(is_duplicate: true) }
  scope :primary_contacts, -> { where(is_duplicate: false) }
  scope :high_quality, -> { where('data_quality_score >= ?', 70) }
  scope :low_quality, -> { where('data_quality_score < ?', 40) }

  # Address enrichment scopes
  scope :address_enriched, -> { where(address_enriched: true) }
  scope :needs_address_enrichment, -> { where(is_business: false, address_enriched: false).where.not(status: 'pending') }
  scope :with_verified_address, -> { where(address_verified: true) }

  # Verizon coverage scopes
  scope :verizon_5g_available, -> { where(verizon_5g_home_available: true) }
  scope :verizon_lte_available, -> { where(verizon_lte_home_available: true) }
  scope :verizon_fios_available, -> { where(verizon_fios_available: true) }
  scope :verizon_home_internet_available, -> { where('verizon_5g_home_available = ? OR verizon_lte_home_available = ? OR verizon_fios_available = ?', true, true, true) }
  scope :verizon_coverage_checked, -> { where(verizon_coverage_checked: true) }
  scope :needs_verizon_check, -> { where(address_enriched: true, verizon_coverage_checked: false).where.not(consumer_address: nil) }
  
  # Define searchable attributes for ActiveAdmin/Ransack
  def self.ransackable_attributes(auth_object = nil)
    ["carrier_name", "created_at", "device_type", "error_code",
     "formatted_phone_number", "id", "mobile_country_code",
     "mobile_network_code", "raw_phone_number", "updated_at",
     "status", "lookup_performed_at", "valid", "country_code",
     "calling_country_code", "line_type", "line_type_confidence",
     "caller_name", "caller_type", "sms_pumping_risk_score",
     "sms_pumping_risk_level", "sms_pumping_carrier_risk_category",
     "sms_pumping_number_blocked", "validation_errors",
     "is_business", "business_name", "business_type", "business_category",
     "business_industry", "business_employee_count", "business_employee_range",
     "business_annual_revenue", "business_revenue_range", "business_city",
     "business_state", "business_country", "business_website",
     "business_enriched", "business_enrichment_provider",
     "email", "email_verified", "email_score", "email_status",
     "first_name", "last_name", "full_name", "position", "department",
     "linkedin_url", "email_enriched", "is_duplicate", "duplicate_of_id",
     "data_quality_score", "completeness_percentage"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
  
  # Check if lookup has been performed successfully
  def lookup_completed?
    status == 'completed' && formatted_phone_number.present?
  end
  
  # Check if lookup should be retried
  def retriable?
    status == 'failed' && error_code.present? && !permanent_failure?
  end

  # Fraud risk assessment helpers
  def high_fraud_risk?
    sms_pumping_risk_level == 'high' || sms_pumping_number_blocked == true
  end

  def safe_number?
    sms_pumping_risk_level == 'low' && !sms_pumping_number_blocked
  end

  def fraud_risk_display
    return 'Unknown' if sms_pumping_risk_score.nil?
    return 'Blocked' if sms_pumping_number_blocked
    "#{sms_pumping_risk_level&.titleize} (#{sms_pumping_risk_score}/100)"
  end

  # Line type helpers
  def is_mobile?
    line_type == 'mobile'
  end

  def is_landline?
    line_type == 'landline'
  end

  def is_voip?
    ['voip', 'fixedVoip', 'nonFixedVoip'].include?(line_type)
  end

  def line_type_display
    return device_type if line_type.blank? # Fallback to old field
    line_type&.titleize || 'Unknown'
  end

  # Business intelligence helpers
  def business?
    is_business == true
  end

  def consumer?
    !business?
  end

  def business_enriched?
    business_enriched == true
  end

  def business_size_category
    return 'Unknown' unless business_employee_range.present?
    case business_employee_range
    when '1-10' then 'Micro (1-10)'
    when '11-50' then 'Small (11-50)'
    when '51-200' then 'Medium (51-200)'
    when '201-500', '501-1000' then 'Large (201-1000)'
    when '1001-5000', '5001-10000', '10000+' then 'Enterprise (1000+)'
    else 'Unknown'
    end
  end

  def business_revenue_category
    return 'Unknown' unless business_revenue_range.present?
    business_revenue_range
  end

  def business_display_name
    business_name || caller_name || formatted_phone_number || raw_phone_number
  end

  def business_age
    return nil unless business_founded_year.present?
    Date.current.year - business_founded_year
  end

  # Email enrichment helpers
  def email_enriched?
    email_enriched == true
  end

  def has_verified_email?
    email.present? && email_verified == true
  end

  def email_quality
    return 'No Email' unless email.present?
    return 'Verified' if email_verified
    return 'Unverified' if email_score && email_score > 70
    'Low Quality'
  end

  # Address enrichment helpers
  def address_enriched?
    address_enriched == true
  end

  def has_full_address?
    consumer_address.present? && consumer_city.present? && consumer_state.present? && consumer_postal_code.present?
  end

  def full_address
    return nil unless has_full_address?
    [consumer_address, consumer_city, "#{consumer_state} #{consumer_postal_code}", consumer_country].compact.join(', ')
  end

  def address_display
    has_full_address? ? full_address : 'No Address'
  end

  # Verizon coverage helpers
  def verizon_coverage_checked?
    verizon_coverage_checked == true
  end

  def verizon_home_internet_available?
    verizon_5g_home_available == true || verizon_lte_home_available == true || verizon_fios_available == true
  end

  def verizon_products_available
    products = []
    products << 'Fios' if verizon_fios_available
    products << '5G Home' if verizon_5g_home_available
    products << 'LTE Home' if verizon_lte_home_available
    products.empty? ? 'None' : products.join(', ')
  end

  def verizon_best_product
    return 'Fios' if verizon_fios_available
    return '5G Home' if verizon_5g_home_available
    return 'LTE Home' if verizon_lte_home_available
    'Not Available'
  end

  def estimated_speed_display
    return nil unless estimated_download_speed.present?
    down = estimated_download_speed
    up = estimated_upload_speed.present? ? " / #{estimated_upload_speed}" : ''
    "#{down}#{up}"
  end

  # Duplicate detection helpers
  def has_duplicates?
    Contact.where(duplicate_of_id: id).exists?
  end

  def duplicate_contacts
    Contact.where(duplicate_of_id: id)
  end

  def find_potential_duplicates
    DuplicateDetectionService.find_duplicates(self)
  end

  def merge_with!(other_contact)
    DuplicateDetectionService.merge(self, other_contact)
  end

  # Calculate fingerprints for duplicate detection
  def update_fingerprints!
    self.phone_fingerprint = calculate_phone_fingerprint
    self.name_fingerprint = calculate_name_fingerprint
    self.email_fingerprint = calculate_email_fingerprint
    save!
  end

  def calculate_quality_score!
    score = 0
    
    # Phone validation (20 points)
    score += 20 if valid == true
    
    # Email quality (20 points)
    score += 20 if email_verified
    score += 10 if email.present? && !email_verified
    
    # Business enrichment (20 points)
    score += 20 if business_enriched?
    
    # Name data (15 points)
    score += 15 if full_name.present?
    score += 5 if first_name.present? && last_name.present?
    
    # Contact info (15 points)
    score += 10 if business_website.present? || linkedin_url.present?
    score += 5 if position.present?
    
    # Fraud check (10 points)
    score += 10 if sms_pumping_risk_level == 'low'
    score -= 20 if sms_pumping_risk_level == 'high'
    
    self.data_quality_score = [score, 0].max
    self.completeness_percentage = calculate_completeness
    save!
  end
  
  # Mark as processing
  def mark_processing!
    update(status: 'processing')
  end
  
  # Mark as completed with timestamp
  def mark_completed!
    update(status: 'completed', lookup_performed_at: Time.current)
  end
  
  # Callback conditions
  def should_update_fingerprints?
    saved_change_to_formatted_phone_number? || 
    saved_change_to_business_name? || 
    saved_change_to_full_name? || 
    saved_change_to_email?
  end

  def should_calculate_quality?
    saved_change_to_email? || 
    saved_change_to_business_enriched? || 
    saved_change_to_valid? ||
    saved_change_to_full_name?
  end

  def update_fingerprints_if_needed
    update_fingerprints!
  end

  def calculate_quality_score_if_needed
    calculate_quality_score!
  end

  # Fingerprint calculations for duplicate detection
  def calculate_phone_fingerprint
    return nil unless formatted_phone_number.present? || raw_phone_number.present?
    phone = (formatted_phone_number || raw_phone_number).gsub(/\D/, '')
    phone.last(10) # Last 10 digits for matching
  end

  def calculate_name_fingerprint
    name = business? ? business_name : full_name
    return nil unless name.present?
    
    # Normalize: downcase, remove special chars, sort words
    normalized = name.downcase
                     .gsub(/[^a-z0-9\s]/, '')
                     .split
                     .sort
                     .join(' ')
    normalized
  end

  def calculate_email_fingerprint
    return nil unless email.present?
    email.downcase.strip
  end

  def calculate_completeness
    total_fields = 20
    filled_fields = 0

    filled_fields += 1 if formatted_phone_number.present?
    filled_fields += 1 if valid == true
    filled_fields += 1 if email.present?
    filled_fields += 1 if email_verified == true
    filled_fields += 1 if full_name.present?
    filled_fields += 1 if first_name.present?
    filled_fields += 1 if last_name.present?
    filled_fields += 1 if business_name.present?
    filled_fields += 1 if business_industry.present?
    filled_fields += 1 if business_employee_range.present?
    filled_fields += 1 if business_revenue_range.present?
    filled_fields += 1 if business_city.present?
    filled_fields += 1 if business_website.present?
    filled_fields += 1 if position.present?
    filled_fields += 1 if linkedin_url.present?
    filled_fields += 1 if carrier_name.present?
    filled_fields += 1 if line_type.present?
    filled_fields += 1 if sms_pumping_risk_level.present?
    filled_fields += 1 if caller_name.present?
    filled_fields += 1 if business_enriched == true

    ((filled_fields.to_f / total_fields) * 100).round
  end
  
  # Determine if failure is permanent (don't retry)
  def permanent_failure?
    return false if error_code.blank?
    
    # Permanent failures: invalid number format, not found, etc.
    error_code.match?(/invalid|not found|does not exist/i)
  end

  # Broadcast turbo stream updates for real-time dashboard
  def broadcast_status_update
    broadcast_refresh
  end

  def broadcast_refresh
    # Broadcast to dashboard channel to refresh stats
    broadcast_replace_to(
      "dashboard_stats",
      target: "dashboard_stats",
      partial: "admin/dashboard/stats",
      locals: { refresh: true }
    )
  end
end
