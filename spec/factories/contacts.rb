# frozen_string_literal: true

FactoryBot.define do
  factory :contact do
    sequence(:raw_phone_number) { |n| "+1415555#{n.to_s.rjust(4, '0')}" }
    status { 'pending' }

    trait :completed do
      status { 'completed' }
      formatted_phone_number { raw_phone_number }
      valid { true }
      lookup_performed_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      error_code { 'Invalid number format' }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :with_business_data do
      is_business { true }
      business_name { 'Acme Corporation' }
      business_industry { 'Technology' }
      business_employee_range { '51-200' }
      business_enriched { true }
    end

    trait :with_email do
      email { 'contact@example.com' }
      email_verified { true }
      email_enriched { true }
    end

    trait :high_risk do
      sms_pumping_risk_level { 'high' }
      sms_pumping_risk_score { 85 }
    end

    trait :low_risk do
      sms_pumping_risk_level { 'low' }
      sms_pumping_risk_score { 10 }
    end

    trait :mobile do
      line_type { 'mobile' }
      carrier_name { 'Verizon Wireless' }
    end

    trait :landline do
      line_type { 'landline' }
      carrier_name { 'AT&T' }
    end
  end
end
