# frozen_string_literal: true

module Contact::BusinessIntelligence
  extend ActiveSupport::Concern

  included do
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
  end

  # Business type checks
  def business?
    is_business == true
  end
  alias_method :is_business?, :business?

  def consumer?
    !business?
  end

  def business_enriched?
    business_enriched == true
  end

  # Business size categorization
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

  # Business revenue categorization
  def business_revenue_category
    return 'Unknown' unless business_revenue_range.present?
    business_revenue_range
  end

  # Business display name with fallbacks
  def business_display_name
    business_name || caller_name || formatted_phone_number || raw_phone_number
  end

  # Calculate business age in years
  def business_age
    return nil unless business_founded_year.present?
    Date.current.year - business_founded_year
  end
end
