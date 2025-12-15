# frozen_string_literal: true

FactoryBot.define do
  factory :contact do
    sequence(:raw_phone_number) { |n| "+1415555#{n.to_s.rjust(4, '0')}" }
    status { 'pending' }

    # Base trait for all enriched contacts
    trait :enriched do
      status { 'completed' }
      lookup_performed_at { Time.current }
      formatted_phone_number { raw_phone_number }
      phone_valid { true }
      country_code { 'US' }
      calling_country_code { '1' }
    end

    # Status traits
    trait :pending do
      status { 'pending' }
      lookup_performed_at { nil }
    end

    trait :processing do
      status { 'processing' }
      lookup_performed_at { nil }
    end

    trait :completed do
      enriched
    end

    trait :failed do
      status { 'failed' }
      error_code { 'Invalid phone number format' }
      lookup_performed_at { nil }
    end

    # Business vs Consumer traits
    trait :business do
      enriched
      is_business { true }
      business_enriched { true }
      business_name { 'Acme Corporation' }
      business_type { 'Private Company' }
      business_category { 'Technology' }
      business_industry { 'Software Development' }
      business_employee_range { '51-200' }
      business_employee_count { 100 }
      business_revenue_range { '$10M-$50M' }
      business_city { 'San Francisco' }
      business_state { 'CA' }
      business_country { 'US' }
      business_website { 'https://example.com' }
      business_enrichment_provider { 'clearbit' }
      business_enriched_at { Time.current }
    end

    trait :consumer do
      enriched
      is_business { false }
      business_enriched { false }
      full_name { 'John Doe' }
      first_name { 'John' }
      last_name { 'Doe' }
    end

    # Alias for backwards compatibility
    trait :with_business_data do
      business
    end

    # Business enrichment trait
    trait :with_business_enrichment do
      business
      caller_name { 'ACME CORP' }
      caller_type { 'BUSINESS' }
    end

    # Email enrichment trait
    trait :with_email_enrichment do
      enriched
      email_enriched { true }
      email { 'john.doe@example.com' }
      email_verified { true }
      email_score { 95 }
      email_status { 'valid' }
      position { 'Software Engineer' }
      department { 'Engineering' }
      seniority { 'Mid-Level' }
      linkedin_url { 'https://linkedin.com/in/johndoe' }
      email_enriched_at { Time.current }
    end

    # Alias for backwards compatibility
    trait :with_email do
      with_email_enrichment
    end

    # Address enrichment trait
    trait :with_address_enrichment do
      consumer
      address_enriched { true }
      consumer_address { '123 Main St' }
      consumer_city { 'San Francisco' }
      consumer_state { 'CA' }
      consumer_postal_code { '94102' }
      consumer_country { 'US' }
      address_type { 'residential' }
      address_verified { true }
      address_confidence_score { 98 }
      address_enriched_at { Time.current }
    end

    # Fraud risk traits
    trait :high_fraud_risk do
      enriched
      sms_pumping_risk_score { 85 }
      sms_pumping_risk_level { 'high' }
      sms_pumping_carrier_risk_category { 'high' }
      sms_pumping_number_blocked { false }
    end

    # Alias for backwards compatibility
    trait :high_risk do
      high_fraud_risk
    end

    trait :low_fraud_risk do
      enriched
      sms_pumping_risk_score { 15 }
      sms_pumping_risk_level { 'low' }
      sms_pumping_carrier_risk_category { 'low' }
      sms_pumping_number_blocked { false }
    end

    # Alias for backwards compatibility
    trait :low_risk do
      low_fraud_risk
    end

    trait :blocked_number do
      enriched
      sms_pumping_risk_score { 100 }
      sms_pumping_risk_level { 'high' }
      sms_pumping_number_blocked { true }
    end

    # Line type traits
    trait :mobile do
      enriched
      line_type { 'mobile' }
      device_type { 'mobile' }
      carrier_name { 'AT&T' }
      mobile_country_code { '310' }
      mobile_network_code { '410' }
      line_type_confidence { 95 }
    end

    trait :landline do
      enriched
      line_type { 'landline' }
      device_type { 'landline' }
      carrier_name { 'Verizon' }
      line_type_confidence { 90 }
    end

    trait :voip do
      enriched
      line_type { 'voip' }
      device_type { 'voip' }
      carrier_name { 'Twilio' }
      line_type_confidence { 85 }
    end

    # Quality score traits
    trait :high_quality do
      enriched
      data_quality_score { 85 }
      completeness_percentage { 90 }
      phone_valid { true }
      email_verified { true }
      business_enriched { true }
      sms_pumping_risk_level { 'low' }
    end

    trait :low_quality do
      enriched
      data_quality_score { 25 }
      completeness_percentage { 30 }
      phone_valid { false }
      email_verified { false }
      business_enriched { false }
    end

    # Duplicate detection traits
    trait :with_fingerprints do
      enriched
      phone_fingerprint { raw_phone_number.gsub(/\D/, '')[-10..-1] }
      name_fingerprint { (business_name || full_name)&.downcase&.gsub(/[^a-z0-9\s]/, '')&.split&.sort&.join(' ') }
      email_fingerprint { email&.downcase&.strip }
    end

    trait :duplicate do
      with_fingerprints
      is_duplicate { true }
      association :duplicate_of, factory: :contact, strategy: :create
      duplicate_checked_at { Time.current }
    end

    # Verizon coverage traits
    trait :with_verizon_coverage do
      with_address_enrichment
      verizon_coverage_checked { true }
      verizon_5g_home_available { true }
      verizon_lte_home_available { false }
      verizon_fios_available { false }
      estimated_download_speed { '300-1000 Mbps' }
      estimated_upload_speed { '50-100 Mbps' }
      verizon_coverage_checked_at { Time.current }
    end

    # Trust Hub verification traits
    trait :trust_hub_verified do
      business
      trust_hub_enriched { true }
      trust_hub_verified { true }
      trust_hub_status { 'twilio-approved' }
      trust_hub_business_sid { "BU#{SecureRandom.hex(16)}" }
      trust_hub_verification_score { 95 }
      trust_hub_regulatory_status { 'compliant' }
      trust_hub_business_name { business_name }
      trust_hub_enriched_at { Time.current }
    end

    trait :trust_hub_pending do
      business
      trust_hub_enriched { true }
      trust_hub_verified { false }
      trust_hub_status { 'pending-review' }
      trust_hub_enriched_at { Time.current }
    end

    # Business size category traits
    trait :micro_business do
      business
      business_employee_range { '1-10' }
      business_employee_count { 5 }
    end

    trait :small_business do
      business
      business_employee_range { '11-50' }
      business_employee_count { 25 }
    end

    trait :medium_business do
      business
      business_employee_range { '51-200' }
      business_employee_count { 100 }
    end

    trait :large_business do
      business
      business_employee_range { '201-500' }
      business_employee_count { 350 }
    end

    trait :enterprise_business do
      business
      business_employee_range { '1001-5000' }
      business_employee_count { 2500 }
    end

    # Error scenarios
    trait :with_twilio_error do
      failed
      error_code { 'Twilio API error 20404: Invalid phone number' }
    end

    trait :with_network_error do
      failed
      error_code { 'Network error: Connection timeout' }
    end

    trait :with_permanent_failure do
      failed
      error_code { 'Invalid number format: does not exist' }
    end

    # Country code variations
    trait :us_number do
      raw_phone_number { "+1415555#{rand(1000..9999)}" }
      country_code { 'US' }
      calling_country_code { '1' }
    end

    trait :uk_number do
      raw_phone_number { "+44#{rand(1000000000..9999999999)}" }
      country_code { 'GB' }
      calling_country_code { '44' }
    end

    trait :invalid_number do
      raw_phone_number { 'not-a-phone-number' }
      phone_valid { false }
      validation_errors { ['Invalid format'] }
    end
  end
end
