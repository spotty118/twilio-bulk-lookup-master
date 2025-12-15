# frozen_string_literal: true

module Contact::TrustHubVerification
  extend ActiveSupport::Concern

  included do
    # Trust Hub verification scopes
    scope :trust_hub_verified, -> { where(trust_hub_verified: true) }
    scope :trust_hub_enriched, -> { where(trust_hub_enriched: true) }
    scope :trust_hub_pending, -> { where(trust_hub_status: ['pending-review', 'in-review']) }
    scope :trust_hub_rejected, -> { where(trust_hub_status: ['twilio-rejected', 'rejected']) }
    scope :trust_hub_approved, -> { where(trust_hub_status: ['twilio-approved', 'compliant']) }
    scope :needs_trust_hub_verification, -> { where(is_business: true, trust_hub_enriched: false, business_enriched: true) }
  end

  # Trust Hub status checks
  def trust_hub_enriched?
    trust_hub_enriched == true
  end

  def trust_hub_verified?
    trust_hub_verified == true
  end

  def trust_hub_pending?
    ['pending-review', 'in-review'].include?(trust_hub_status)
  end

  def trust_hub_rejected?
    ['twilio-rejected', 'rejected'].include?(trust_hub_status)
  end

  def trust_hub_approved?
    ['twilio-approved', 'compliant'].include?(trust_hub_status)
  end

  # Trust Hub display helpers
  def trust_hub_status_display
    return 'Not Checked' unless trust_hub_enriched?
    return 'Verified' if trust_hub_verified?
    trust_hub_status&.titleize || 'Unknown'
  end

  def trust_hub_verification_level
    return 'None' unless trust_hub_verification_score.present?

    score = trust_hub_verification_score
    case score
    when 90..100 then 'Excellent'
    when 70..89 then 'Good'
    when 50..69 then 'Fair'
    when 1..49 then 'Poor'
    else 'None'
    end
  end

  # Reverification check
  def trust_hub_needs_reverification?
    return false unless trust_hub_enriched?
    return true if trust_hub_pending? || trust_hub_rejected?
    return false unless trust_hub_enriched_at.present?

    days_since_check = (Time.current - trust_hub_enriched_at) / 1.day
    reverification_days = TwilioCredential.current&.trust_hub_reverification_days || 90
    days_since_check >= reverification_days
  end
end
