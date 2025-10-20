class Contact < ApplicationRecord
  # Include concerns for better organization
  include ErrorTrackable
  include StatusManageable

  # Broadcast changes for real-time dashboard updates
  after_update_commit :broadcast_status_update, if: :saved_change_to_status?
  after_create_commit :broadcast_refresh
  after_destroy_commit :broadcast_refresh
  
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
     "business_enriched", "business_enrichment_provider"]
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
  
  # Mark as failed with error
  def mark_failed!(error_message)
    update(
      status: 'failed',
      error_code: error_message,
      lookup_performed_at: Time.current
    )
  end
  
  private
  
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
