# frozen_string_literal: true

module Contact::EnrichmentTracking
  extend ActiveSupport::Concern

  included do
    # Email enrichment scopes
    scope :email_enriched, -> { where(email_enriched: true) }
    scope :with_verified_email, -> { where(email_verified: true) }
    scope :needs_email_enrichment, -> { where(email_enriched: false, business_enriched: true) }

    before_validation :normalize_email, if: -> { email.present? }

    # Address enrichment scopes
    scope :address_enriched, -> { where(address_enriched: true) }
    scope :needs_address_enrichment, lambda {
      where(is_business: false, address_enriched: false).where.not(status: 'pending')
    }
    scope :with_verified_address, -> { where(address_verified: true) }
  end

  def normalize_email
    self.email = email.strip.downcase
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
end
