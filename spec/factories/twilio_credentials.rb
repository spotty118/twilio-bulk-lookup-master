# frozen_string_literal: true

FactoryBot.define do
  factory :twilio_credential do
    account_sid { "AC#{SecureRandom.hex(16)}" }
    auth_token { SecureRandom.hex(16) }
    is_singleton { true }

    # Data package configuration traits
    trait :with_all_packages do
      enable_line_type_intelligence { true }
      enable_caller_name { true }
      enable_sms_pumping_risk { true }
      enable_sim_swap { true }
      enable_reassigned_number { true }
    end

    trait :with_minimal_packages do
      enable_line_type_intelligence { true }
      enable_caller_name { false }
      enable_sms_pumping_risk { false }
      enable_sim_swap { false }
      enable_reassigned_number { false }
    end

    trait :with_no_packages do
      enable_line_type_intelligence { false }
      enable_caller_name { false }
      enable_sms_pumping_risk { false }
      enable_sim_swap { false }
      enable_reassigned_number { false }
    end

    # Enrichment configuration traits
    trait :with_enrichment_enabled do
      enable_business_enrichment { true }
      enable_address_enrichment { true }
      enable_email_enrichment { true }
      enable_verizon_coverage_check { true }
      enable_trust_hub_verification { true }
    end

    trait :with_enrichment_disabled do
      enable_business_enrichment { false }
      enable_address_enrichment { false }
      enable_email_enrichment { false }
      enable_verizon_coverage_check { false }
      enable_trust_hub_verification { false }
    end

    # Trust Hub configuration
    trait :with_trust_hub do
      enable_trust_hub_verification { true }
      trust_hub_reverification_days { 90 }
    end

    # Common configurations
    trait :basic_lookup_only do
      with_minimal_packages
      with_enrichment_disabled
    end

    trait :full_featured do
      with_all_packages
      with_enrichment_enabled
      with_trust_hub
    end

    # Invalid credentials for testing error scenarios
    trait :invalid_sid do
      account_sid { 'INVALID_SID' }
    end

    trait :invalid_token do
      auth_token { 'short' }
    end

    trait :blank_credentials do
      account_sid { '' }
      auth_token { '' }
    end
  end
end
