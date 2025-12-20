# frozen_string_literal: true

module Contact::DuplicateDetection
  extend ActiveSupport::Concern

  included do
    # Duplicate detection scopes
    scope :potential_duplicates, lambda {
      where(is_duplicate: false).where('duplicate_checked_at IS NULL OR duplicate_checked_at < ?', 7.days.ago)
    }

    # Associations
    belongs_to :duplicate_of, class_name: 'Contact', optional: true
    scope :confirmed_duplicates, -> { where(is_duplicate: true) }
    scope :primary_contacts, -> { where(is_duplicate: false) }
    scope :high_quality, -> { where('data_quality_score >= ?', 70) }
    scope :low_quality, -> { where('data_quality_score < ?', 40) }

    # Update fingerprints for duplicate detection
    # Skip during bulk imports to prevent N+1 queries
    after_save :update_fingerprints_if_needed,
               if: -> { should_update_fingerprints? && !Contact.skip_callbacks_for_bulk_import }
    after_save :calculate_quality_score_if_needed,
               if: -> { should_calculate_quality? && !Contact.skip_callbacks_for_bulk_import }
  end

  # Duplicate relationship helpers
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

  # Fingerprint management
  def update_fingerprints!
    # Use update_columns to skip callbacks and avoid recursion
    update_columns(
      phone_fingerprint: calculate_phone_fingerprint,
      name_fingerprint: calculate_name_fingerprint,
      email_fingerprint: calculate_email_fingerprint,
      updated_at: Time.current
    )
  end

  # Quality score calculation
  def calculate_quality_score!
    score = 0

    # Phone validation (20 points)
    score += 20 if phone_valid == true

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

    # Use update_columns to skip callbacks and avoid recursion
    update_columns(
      data_quality_score: [[score, 0].max, 100].min,
      completeness_percentage: calculate_completeness,
      updated_at: Time.current
    )
  end

  # Fingerprint calculations
  def calculate_phone_fingerprint
    return nil unless formatted_phone_number.present? || raw_phone_number.present?

    phone = (formatted_phone_number || raw_phone_number).gsub(/\D/, '')
    # Use last 10 digits for matching (handles country codes), or entire number if shorter
    phone.length > 10 ? phone[-10..-1] : phone
  end

  def calculate_name_fingerprint
    name = business? ? business_name : full_name
    return nil unless name.present?

    # Normalize: downcase, remove special chars, sort words
    name.downcase
        .gsub(/[^a-z0-9\s]/, '')
        .split
        .sort
        .join(' ')
  end

  def calculate_email_fingerprint
    return nil unless email.present?

    email.downcase.strip
  end

  # Completeness percentage calculation
  def calculate_completeness
    total_fields = 20
    filled_fields = 0

    filled_fields += 1 if formatted_phone_number.present?
    filled_fields += 1 if phone_valid == true
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

  # Callback conditions
  def should_update_fingerprints?
    saved_change_to_raw_phone_number? ||
      saved_change_to_formatted_phone_number? ||
      saved_change_to_business_name? ||
      saved_change_to_full_name? ||
      saved_change_to_email?
  end

  def should_calculate_quality?
    saved_change_to_email? ||
      saved_change_to_business_enriched? ||
      saved_change_to_phone_valid? ||
      saved_change_to_full_name?
  end

  def update_fingerprints_if_needed
    update_fingerprints!
  end

  def calculate_quality_score_if_needed
    calculate_quality_score!
  end
end
