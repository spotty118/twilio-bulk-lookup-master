# frozen_string_literal: true

module Contact::PhoneIntelligence
  extend ActiveSupport::Concern

  included do
    # Line type scopes
    scope :mobile, -> { where(line_type: 'mobile') }
    scope :landline, -> { where(line_type: 'landline') }
    scope :voip, -> { where(line_type: %w[voip fixedVoip nonFixedVoip]) }
    scope :toll_free, -> { where(line_type: 'tollFree') }

    # Validation scopes
    scope :valid_numbers, -> { where(phone_valid: true) }
    scope :invalid_numbers, -> { where(phone_valid: false) }

    # Fraud risk scopes
    scope :high_risk, -> { where(sms_pumping_risk_level: 'high') }
    scope :medium_risk, -> { where(sms_pumping_risk_level: 'medium') }
    scope :low_risk, -> { where(sms_pumping_risk_level: 'low') }
    scope :blocked_numbers, -> { where(sms_pumping_number_blocked: true) }
  end

  # Line type checks
  def is_mobile?
    line_type == 'mobile'
  end

  def is_landline?
    line_type == 'landline'
  end

  def is_voip?
    %w[voip fixedVoip nonFixedVoip].include?(line_type)
  end

  # Line type display with fallback
  def line_type_display
    return 'Unknown' if line_type.blank? && device_type.blank?
    return device_type if line_type.blank?

    line_type.titleize
  end

  # Fraud risk assessment
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
end
