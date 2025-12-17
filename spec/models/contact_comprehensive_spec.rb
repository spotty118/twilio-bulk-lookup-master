# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contact, type: :model do
  describe 'validations' do
    describe 'raw_phone_number' do
      it 'requires presence' do
        contact = build(:contact, raw_phone_number: nil)
        expect(contact).not_to be_valid
        expect(contact.errors[:raw_phone_number]).to include("can't be blank")
      end

      it 'accepts valid E.164 format with plus sign' do
        contact = build(:contact, raw_phone_number: '+14155551234')
        expect(contact).to be_valid
      end

      it 'accepts valid international format without plus sign' do
        contact = build(:contact, raw_phone_number: '14155551234')
        expect(contact).to be_valid
      end

      it 'rejects invalid formats' do
        contact = build(:contact, raw_phone_number: 'not-a-phone')
        contact.valid?
        expect(contact.errors[:raw_phone_number]).to include('must be a valid phone number (E.164 format recommended, e.g., +14155551234)')
      end

      it 'accepts numbers with 10-15 digits' do
        expect(build(:contact, raw_phone_number: '+1234567890')).to be_valid
        expect(build(:contact, raw_phone_number: '+123456789012345')).to be_valid
      end
    end

    describe 'status' do
      it 'allows valid statuses' do
        Contact::STATUSES.each do |status|
          contact = build(:contact, status: status)
          expect(contact).to be_valid
        end
      end

      it 'rejects invalid statuses' do
        contact = build(:contact, status: 'invalid_status')
        expect(contact).not_to be_valid
        expect(contact.errors[:status]).to include('is not included in the list')
      end

      it 'allows nil status' do
        contact = build(:contact, status: nil)
        expect(contact).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe 'status scopes' do
      let!(:pending_contact) { create(:contact, :pending) }
      let!(:processing_contact) { create(:contact, :processing) }
      let!(:completed_contact) { create(:contact, :completed) }
      let!(:failed_contact) { create(:contact, :failed) }

      it '.pending returns only pending contacts' do
        expect(Contact.pending).to contain_exactly(pending_contact)
      end

      it '.processing returns only processing contacts' do
        expect(Contact.processing).to contain_exactly(processing_contact)
      end

      it '.completed returns only completed contacts' do
        expect(Contact.completed).to contain_exactly(completed_contact)
      end

      it '.failed returns only failed contacts' do
        expect(Contact.failed).to contain_exactly(failed_contact)
      end

      it '.not_processed returns pending and failed contacts' do
        expect(Contact.not_processed).to contain_exactly(pending_contact, failed_contact)
      end
    end

    describe 'fraud risk scopes' do
      let!(:high_risk) { create(:contact, :high_fraud_risk) }
      let!(:medium_risk) { create(:contact, :completed, sms_pumping_risk_level: 'medium') }
      let!(:low_risk) { create(:contact, :low_fraud_risk) }
      let!(:blocked) { create(:contact, :blocked_number) }

      it '.high_risk returns high risk contacts' do
        expect(Contact.high_risk).to include(high_risk, blocked)
      end

      it '.medium_risk returns medium risk contacts' do
        expect(Contact.medium_risk).to contain_exactly(medium_risk)
      end

      it '.low_risk returns low risk contacts' do
        expect(Contact.low_risk).to contain_exactly(low_risk)
      end

      it '.blocked_numbers returns blocked contacts' do
        expect(Contact.blocked_numbers).to contain_exactly(blocked)
      end
    end

    describe 'line type scopes' do
      let!(:mobile_contact) { create(:contact, :mobile) }
      let!(:landline_contact) { create(:contact, :landline) }
      let!(:voip_contact) { create(:contact, :voip) }
      let!(:toll_free) { create(:contact, :completed, line_type: 'tollFree') }

      it '.mobile returns only mobile contacts' do
        expect(Contact.mobile).to contain_exactly(mobile_contact)
      end

      it '.landline returns only landline contacts' do
        expect(Contact.landline).to contain_exactly(landline_contact)
      end

      it '.voip returns voip variants' do
        expect(Contact.voip).to contain_exactly(voip_contact)
      end

      it '.toll_free returns toll-free contacts' do
        expect(Contact.toll_free).to contain_exactly(toll_free)
      end
    end

    describe 'validation scopes' do
      let!(:valid_contact) { create(:contact, :completed, phone_valid: true) }
      let!(:invalid_contact) { create(:contact, :completed, phone_valid: false) }

      it '.valid_numbers returns only valid numbers' do
        expect(Contact.valid_numbers).to contain_exactly(valid_contact)
      end

      it '.invalid_numbers returns only invalid numbers' do
        expect(Contact.invalid_numbers).to contain_exactly(invalid_contact)
      end
    end

    describe 'business intelligence scopes' do
      let!(:business) { create(:contact, :business) }
      let!(:consumer) { create(:contact, :consumer) }
      let!(:micro) { create(:contact, :micro_business) }
      let!(:small) { create(:contact, :small_business) }
      let!(:medium) { create(:contact, :medium_business) }
      let!(:large) { create(:contact, :large_business) }
      let!(:enterprise) { create(:contact, :enterprise_business) }

      it '.businesses returns only businesses' do
        expect(Contact.businesses).to include(business, micro, small, medium, large, enterprise)
        expect(Contact.businesses).not_to include(consumer)
      end

      it '.consumers returns only consumers' do
        expect(Contact.consumers).to contain_exactly(consumer)
      end

      it '.business_enriched returns enriched businesses' do
        expect(Contact.business_enriched).to include(business, micro, small, medium, large, enterprise)
      end

      it '.needs_enrichment returns completed but not enriched' do
        needs_enrichment = create(:contact, :completed, business_enriched: false)
        expect(Contact.needs_enrichment).to include(needs_enrichment)
        expect(Contact.needs_enrichment).not_to include(business)
      end

      describe 'business size scopes' do
        it '.micro_businesses returns micro businesses' do
          expect(Contact.micro_businesses).to contain_exactly(micro)
        end

        it '.small_businesses returns small businesses' do
          expect(Contact.small_businesses).to contain_exactly(small)
        end

        it '.medium_businesses returns medium businesses' do
          Contact.delete_all
          medium_contact = create(:contact, :business, business_employee_count: 250)
          expect(Contact.medium_businesses).to contain_exactly(medium_contact)
        end

        it '.large_businesses returns large businesses' do
          expect(Contact.large_businesses).to contain_exactly(large)
        end

        it '.enterprise_businesses returns enterprise businesses' do
          expect(Contact.enterprise_businesses).to contain_exactly(enterprise)
        end
      end

      it '.by_industry filters by industry' do
        tech_business = create(:contact, :business, business_industry: 'Technology')
        retail_business = create(:contact, :business, business_industry: 'Retail')

        expect(Contact.by_industry('Technology')).to include(tech_business)
        expect(Contact.by_industry('Technology')).not_to include(retail_business)
      end

      it '.by_business_type filters by business type' do
        private_company = create(:contact, :business, business_type: 'Private Company')
        public_company = create(:contact, :business, business_type: 'Public Company')

        expect(Contact.by_business_type('Private Company')).to include(private_company)
        expect(Contact.by_business_type('Private Company')).not_to include(public_company)
      end
    end

    describe 'email enrichment scopes' do
      let!(:email_enriched) { create(:contact, :with_email_enrichment) }
      let!(:verified_email) { create(:contact, :with_email_enrichment, email_verified: true) }
      let!(:not_enriched) { create(:contact, :business, email_enriched: false) }

      it '.email_enriched returns email enriched contacts' do
        expect(Contact.email_enriched).to include(email_enriched, verified_email)
        expect(Contact.email_enriched).not_to include(not_enriched)
      end

      it '.with_verified_email returns verified emails only' do
        expect(Contact.with_verified_email).to include(verified_email)
      end

      it '.needs_email_enrichment returns business enriched without email' do
        expect(Contact.needs_email_enrichment).to include(not_enriched)
        expect(Contact.needs_email_enrichment).not_to include(email_enriched)
      end
    end

    describe 'duplicate detection scopes' do
      let!(:primary) { create(:contact, :with_fingerprints, is_duplicate: false) }
      let!(:duplicate) { create(:contact, :duplicate, duplicate_of: primary) }
      let!(:high_quality) { create(:contact, :high_quality) }
      let!(:low_quality) { create(:contact, :low_quality) }

      it '.potential_duplicates returns unchecked or old checks' do
        unchecked = create(:contact, :completed, duplicate_checked_at: nil)
        expect(Contact.potential_duplicates).to include(unchecked)
      end

      it '.confirmed_duplicates returns duplicates' do
        expect(Contact.confirmed_duplicates).to contain_exactly(duplicate)
      end

      it '.primary_contacts excludes duplicates' do
        expect(Contact.primary_contacts).to include(primary)
        expect(Contact.primary_contacts).not_to include(duplicate)
      end

      it '.high_quality returns contacts with score >= 70' do
        expect(Contact.high_quality).to include(high_quality)
        expect(Contact.high_quality).not_to include(low_quality)
      end

      it '.low_quality returns contacts with score < 40' do
        expect(Contact.low_quality).to include(low_quality)
        expect(Contact.low_quality).not_to include(high_quality)
      end
    end

    describe 'address enrichment scopes' do
      let!(:address_enriched) { create(:contact, :with_address_enrichment) }
      let!(:verified_address) { create(:contact, :with_address_enrichment, address_verified: true) }
      let!(:consumer_no_address) { create(:contact, :consumer, address_enriched: false) }

      it '.address_enriched returns address enriched contacts' do
        expect(Contact.address_enriched).to include(address_enriched, verified_address)
        expect(Contact.address_enriched).not_to include(consumer_no_address)
      end

      it '.with_verified_address returns verified addresses only' do
        expect(Contact.with_verified_address).to include(verified_address)
      end

      it '.needs_address_enrichment returns consumers without address' do
        expect(Contact.needs_address_enrichment).to include(consumer_no_address)
        expect(Contact.needs_address_enrichment).not_to include(address_enriched)
      end
    end

    describe 'Verizon coverage scopes' do
      let!(:has_5g) { create(:contact, :with_verizon_coverage) }
      let!(:has_fios) do
        create(:contact, :with_address_enrichment, verizon_coverage_checked: true, verizon_fios_available: true)
      end
      let!(:no_coverage) { create(:contact, :with_address_enrichment, verizon_coverage_checked: false) }

      it '.verizon_5g_available returns 5G available contacts' do
        expect(Contact.verizon_5g_available).to contain_exactly(has_5g)
      end

      it '.verizon_fios_available returns Fios available contacts' do
        expect(Contact.verizon_fios_available).to contain_exactly(has_fios)
      end

      it '.verizon_home_internet_available returns any home internet' do
        expect(Contact.verizon_home_internet_available).to include(has_5g, has_fios)
      end

      it '.verizon_coverage_checked returns checked contacts' do
        expect(Contact.verizon_coverage_checked).to include(has_5g, has_fios)
        expect(Contact.verizon_coverage_checked).not_to include(no_coverage)
      end

      it '.needs_verizon_check returns address enriched without coverage check' do
        expect(Contact.needs_verizon_check).to include(no_coverage)
        expect(Contact.needs_verizon_check).not_to include(has_5g)
      end
    end

    describe 'Trust Hub verification scopes' do
      let!(:verified) { create(:contact, :trust_hub_verified) }
      let!(:pending) { create(:contact, :trust_hub_pending) }
      let!(:rejected) { create(:contact, :business, trust_hub_enriched: true, trust_hub_status: 'twilio-rejected') }
      let!(:needs_verification) { create(:contact, :business, trust_hub_enriched: false) }

      it '.trust_hub_verified returns verified contacts' do
        expect(Contact.trust_hub_verified).to contain_exactly(verified)
      end

      it '.trust_hub_enriched returns enriched contacts' do
        expect(Contact.trust_hub_enriched).to include(verified, pending, rejected)
      end

      it '.trust_hub_pending returns pending statuses' do
        expect(Contact.trust_hub_pending).to contain_exactly(pending)
      end

      it '.trust_hub_rejected returns rejected statuses' do
        expect(Contact.trust_hub_rejected).to contain_exactly(rejected)
      end

      it '.trust_hub_approved returns approved statuses' do
        expect(Contact.trust_hub_approved).to contain_exactly(verified)
      end

      it '.needs_trust_hub_verification returns business enriched without trust hub' do
        expect(Contact.needs_trust_hub_verification).to include(needs_verification)
        expect(Contact.needs_trust_hub_verification).not_to include(verified)
      end
    end
  end

  describe 'business intelligence methods' do
    describe '#business? and #consumer?' do
      it 'returns true for businesses' do
        business = create(:contact, :business)
        expect(business.business?).to be true
        expect(business.is_business?).to be true
        expect(business.consumer?).to be false
      end

      it 'returns true for consumers' do
        consumer = create(:contact, :consumer)
        expect(consumer.business?).to be false
        expect(consumer.consumer?).to be true
      end

      it 'defaults to consumer when is_business is nil' do
        contact = create(:contact, :completed, is_business: nil)
        expect(contact.consumer?).to be true
      end
    end

    describe '#business_size_category' do
      it 'returns correct category for micro businesses' do
        micro = create(:contact, :micro_business)
        expect(micro.business_size_category).to eq('Micro (1-10)')
      end

      it 'returns correct category for small businesses' do
        small = create(:contact, :small_business)
        expect(small.business_size_category).to eq('Small (11-50)')
      end

      it 'returns correct category for medium businesses' do
        medium = create(:contact, :medium_business)
        expect(medium.business_size_category).to eq('Medium (51-200)')
      end

      it 'returns correct category for large businesses' do
        large = create(:contact, :large_business)
        expect(large.business_size_category).to eq('Large (201-1000)')
      end

      it 'returns correct category for enterprise businesses' do
        enterprise = create(:contact, :enterprise_business)
        expect(enterprise.business_size_category).to eq('Enterprise (1000+)')
      end

      it 'returns Unknown when employee range is nil' do
        business = create(:contact, :business, business_employee_range: nil)
        expect(business.business_size_category).to eq('Unknown')
      end
    end

    describe '#business_display_name' do
      it 'uses business_name when available' do
        business = create(:contact, :business, business_name: 'Acme Corp', caller_name: 'ACME')
        expect(business.business_display_name).to eq('Acme Corp')
      end

      it 'falls back to caller_name when business_name is nil' do
        contact = create(:contact, :completed, business_name: nil, caller_name: 'JOHN DOE')
        expect(contact.business_display_name).to eq('JOHN DOE')
      end

      it 'falls back to formatted_phone_number when names are nil' do
        contact = create(:contact, :completed, business_name: nil, caller_name: nil,
                                               formatted_phone_number: '+14155551234')
        expect(contact.business_display_name).to eq('+14155551234')
      end

      it 'uses raw_phone_number as last resort' do
        contact = create(:contact, raw_phone_number: '+14155551234', business_name: nil, caller_name: nil,
                                   formatted_phone_number: nil)
        expect(contact.business_display_name).to eq('+14155551234')
      end
    end

    describe '#business_age' do
      it 'calculates age from founded year' do
        current_year = Date.current.year
        business = create(:contact, :business, business_founded_year: current_year - 5)
        expect(business.business_age).to eq(5)
      end

      it 'returns nil when founded year is not present' do
        business = create(:contact, :business, business_founded_year: nil)
        expect(business.business_age).to be_nil
      end
    end
  end

  describe 'phone intelligence methods' do
    describe '#is_mobile?, #is_landline?, #is_voip?' do
      it 'correctly identifies mobile' do
        mobile = create(:contact, :mobile)
        expect(mobile.is_mobile?).to be true
        expect(mobile.is_landline?).to be false
        expect(mobile.is_voip?).to be false
      end

      it 'correctly identifies landline' do
        landline = create(:contact, :landline)
        expect(landline.is_mobile?).to be false
        expect(landline.is_landline?).to be true
        expect(landline.is_voip?).to be false
      end

      it 'correctly identifies voip' do
        voip = create(:contact, :voip)
        expect(voip.is_mobile?).to be false
        expect(voip.is_landline?).to be false
        expect(voip.is_voip?).to be true
      end

      it 'identifies voip variants' do
        fixed_voip = create(:contact, :completed, line_type: 'fixedVoip')
        non_fixed_voip = create(:contact, :completed, line_type: 'nonFixedVoip')

        expect(fixed_voip.is_voip?).to be true
        expect(non_fixed_voip.is_voip?).to be true
      end
    end

    describe '#fraud_risk_display' do
      it 'returns Blocked for blocked numbers' do
        blocked = create(:contact, :blocked_number)
        expect(blocked.fraud_risk_display).to eq('Blocked')
      end

      it 'returns formatted risk level with score' do
        high_risk = create(:contact, :high_fraud_risk)
        expect(high_risk.fraud_risk_display).to eq('High (85/100)')
      end

      it 'returns Unknown when score is nil' do
        contact = create(:contact, :completed, sms_pumping_risk_score: nil)
        expect(contact.fraud_risk_display).to eq('Unknown')
      end
    end

    describe '#high_fraud_risk? and #safe_number?' do
      it 'identifies high fraud risk' do
        high_risk = create(:contact, :high_fraud_risk)
        expect(high_risk.high_fraud_risk?).to be true
        expect(high_risk.safe_number?).to be false
      end

      it 'identifies blocked numbers as high risk' do
        blocked = create(:contact, :blocked_number)
        expect(blocked.high_fraud_risk?).to be true
        expect(blocked.safe_number?).to be false
      end

      it 'identifies safe numbers' do
        safe = create(:contact, :low_fraud_risk)
        expect(safe.high_fraud_risk?).to be false
        expect(safe.safe_number?).to be true
      end
    end

    describe '#line_type_display' do
      it 'returns titleized line_type' do
        mobile = create(:contact, :mobile)
        expect(mobile.line_type_display).to eq('Mobile')
      end

      it 'falls back to device_type when line_type is blank' do
        contact = create(:contact, :completed, line_type: nil, device_type: 'landline')
        expect(contact.line_type_display).to eq('landline')
      end

      it 'returns Unknown when both are nil' do
        contact = create(:contact, :completed, line_type: nil, device_type: nil)
        expect(contact.line_type_display).to eq('Unknown')
      end
    end
  end

  describe 'enrichment methods' do
    describe '#email_quality' do
      it 'returns No Email when email is blank' do
        contact = create(:contact, :completed, email: nil)
        expect(contact.email_quality).to eq('No Email')
      end

      it 'returns Verified for verified emails' do
        verified = create(:contact, :with_email_enrichment, email_verified: true)
        expect(verified.email_quality).to eq('Verified')
      end

      it 'returns Unverified for high score unverified emails' do
        unverified = create(:contact, :completed, email: 'test@example.com', email_verified: false, email_score: 85)
        expect(unverified.email_quality).to eq('Unverified')
      end

      it 'returns Low Quality for low score emails' do
        low_quality = create(:contact, :completed, email: 'test@example.com', email_verified: false, email_score: 50)
        expect(low_quality.email_quality).to eq('Low Quality')
      end
    end

    describe '#address_display' do
      it 'returns full address when available' do
        contact = create(:contact, :with_address_enrichment)
        expect(contact.address_display).to include('123 Main St')
        expect(contact.address_display).to include('San Francisco')
        expect(contact.address_display).to include('CA 94102')
      end

      it 'returns No Address when address is incomplete' do
        contact = create(:contact, :consumer, consumer_address: nil)
        expect(contact.address_display).to eq('No Address')
      end
    end

    describe '#has_full_address?' do
      it 'returns true when all address fields present' do
        contact = create(:contact, :with_address_enrichment)
        expect(contact.has_full_address?).to be true
      end

      it 'returns false when any address field missing' do
        contact = create(:contact, :consumer, consumer_address: '123 Main', consumer_city: nil)
        expect(contact.has_full_address?).to be false
      end
    end

    describe '#full_address' do
      it 'returns formatted address' do
        contact = create(:contact, :with_address_enrichment)
        expected = '123 Main St, San Francisco, CA 94102, US'
        expect(contact.full_address).to eq(expected)
      end

      it 'returns nil when address incomplete' do
        contact = create(:contact, :consumer, consumer_address: nil)
        expect(contact.full_address).to be_nil
      end
    end
  end

  describe 'fingerprint calculations' do
    describe '#calculate_phone_fingerprint' do
      it 'extracts last 10 digits from formatted number' do
        contact = create(:contact, :completed, formatted_phone_number: '+14155551234')
        expect(contact.calculate_phone_fingerprint).to eq('4155551234')
      end

      it 'uses raw_phone_number when formatted is nil' do
        contact = create(:contact, raw_phone_number: '+14155551234', formatted_phone_number: nil)
        expect(contact.calculate_phone_fingerprint).to eq('4155551234')
      end

      it 'returns entire number if shorter than 10 digits' do
        contact = create(:contact, raw_phone_number: '+1234567', formatted_phone_number: nil)
        expect(contact.calculate_phone_fingerprint).to eq('1234567')
      end

      it 'returns nil when no phone number present' do
        contact = Contact.new(raw_phone_number: nil, formatted_phone_number: nil)
        expect(contact.calculate_phone_fingerprint).to be_nil
      end
    end

    describe '#calculate_name_fingerprint' do
      it 'normalizes business name' do
        business = create(:contact, :business, business_name: 'Acme Corp!')
        expect(business.calculate_name_fingerprint).to eq('acme corp')
      end

      it 'normalizes full name for consumers' do
        consumer = create(:contact, :consumer, full_name: 'John A. Doe')
        expect(consumer.calculate_name_fingerprint).to eq('a doe john')
      end

      it 'sorts words alphabetically' do
        business = create(:contact, :business, business_name: 'Zebra Alpha Beta')
        expect(business.calculate_name_fingerprint).to eq('alpha beta zebra')
      end

      it 'removes special characters' do
        business = create(:contact, :business, business_name: 'AT&T Corp.')
        expect(business.calculate_name_fingerprint).to eq('att corp')
      end

      it 'returns nil when no name present' do
        contact = create(:contact, :completed, business_name: nil, full_name: nil, is_business: true)
        expect(contact.calculate_name_fingerprint).to be_nil
      end
    end

    describe '#calculate_email_fingerprint' do
      it 'normalizes email to lowercase' do
        contact = create(:contact, :with_email_enrichment, email: 'John.Doe@Example.COM')
        expect(contact.calculate_email_fingerprint).to eq('john.doe@example.com')
      end

      it 'strips whitespace' do
        contact = create(:contact, :completed, email: '  john@example.com  ')
        expect(contact.calculate_email_fingerprint).to eq('john@example.com')
      end

      it 'returns nil when no email present' do
        contact = create(:contact, :completed, email: nil)
        expect(contact.calculate_email_fingerprint).to be_nil
      end
    end

    describe '#update_fingerprints!' do
      it 'updates all fingerprints without triggering callbacks' do
        contact = create(:contact, :business)
        # Clear fingerprints to verify they are updated/restored
        contact.update_columns(phone_fingerprint: nil, name_fingerprint: nil)

        expect do
          contact.update_fingerprints!
        end.to change { contact.reload.phone_fingerprint }
          .and(change { contact.reload.name_fingerprint })
      end

      it 'uses update_columns to skip callbacks' do
        contact = create(:contact, :business)
        expect(contact).to receive(:update_columns).and_call_original
        contact.update_fingerprints!
      end
    end
  end

  describe 'quality score calculation' do
    describe '#calculate_quality_score!' do
      it 'awards 20 points for valid phone' do
        contact = create(:contact, :completed, phone_valid: true)
        contact.calculate_quality_score!
        expect(contact.reload.data_quality_score).to be >= 20
      end

      it 'awards 20 points for verified email' do
        contact = create(:contact, :with_email_enrichment, email_verified: true)
        contact.calculate_quality_score!
        expect(contact.reload.data_quality_score).to be >= 20
      end

      it 'awards 10 points for unverified email' do
        contact = create(:contact, :completed, email: 'test@example.com', email_verified: false)
        contact.calculate_quality_score!
        expect(contact.reload.data_quality_score).to be >= 10
      end

      it 'awards 20 points for business enrichment' do
        contact = create(:contact, :business, business_enriched: true)
        contact.calculate_quality_score!
        expect(contact.reload.data_quality_score).to be >= 20
      end

      it 'awards points for name data' do
        contact = create(:contact, :consumer, first_name: 'John', last_name: 'Doe', full_name: 'John Doe')
        contact.calculate_quality_score!
        expect(contact.reload.data_quality_score).to be >= 15
      end

      it 'awards 10 points for low fraud risk' do
        contact = create(:contact, :low_fraud_risk)
        contact.calculate_quality_score!
        expect(contact.reload.data_quality_score).to be >= 10
      end

      it 'deducts 20 points for high fraud risk' do
        contact = create(:contact, :high_fraud_risk)
        contact.calculate_quality_score!
        # High risk contact gets points for being completed but loses 20 for fraud
        expect(contact.reload.data_quality_score).to be < 100
      end

      it 'never goes below 0' do
        contact = create(:contact, :high_fraud_risk, phone_valid: false)
        contact.calculate_quality_score!
        expect(contact.reload.data_quality_score).to be >= 0
      end

      it 'calculates completeness percentage' do
        contact = create(:contact, :high_quality)
        contact.calculate_quality_score!
        expect(contact.reload.completeness_percentage).to be > 0
      end

      it 'uses update_columns to skip callbacks' do
        contact = create(:contact, :completed)
        expect(contact).to receive(:update_columns).and_call_original
        contact.calculate_quality_score!
      end
    end

    describe '#calculate_completeness' do
      it 'returns percentage of filled fields' do
        contact = create(:contact, :high_quality)
        completeness = contact.calculate_completeness
        expect(completeness).to be_between(0, 100)
      end

      it 'returns 0 for minimal contact' do
        contact = create(:contact, :pending)
        expect(contact.calculate_completeness).to be <= 10
      end

      it 'returns high percentage for fully enriched contact' do
        contact = create(:contact, :business, :with_email_enrichment)
        expect(contact.calculate_completeness).to be >= 50
      end
    end
  end

  describe 'status transitions' do
    describe '#mark_processing!' do
      it 'updates status to processing' do
        contact = create(:contact, :pending)
        contact.mark_processing!
        expect(contact.reload.status).to eq('processing')
      end
    end

    describe '#mark_completed!' do
      it 'updates status to completed and sets timestamp' do
        contact = create(:contact, :processing)

        freeze_time do
          contact.mark_completed!
          expect(contact.reload.status).to eq('completed')
          expect(contact.lookup_performed_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    describe '#mark_failed!' do
      it 'updates status to failed and sets error message' do
        contact = create(:contact, :processing)
        contact.mark_failed!('Invalid number')

        expect(contact.reload.status).to eq('failed')
        expect(contact.error_code).to eq('Invalid number')
      end
    end

    describe '#lookup_completed?' do
      it 'returns true when completed with formatted number' do
        contact = create(:contact, :completed)
        expect(contact.lookup_completed?).to be true
      end

      it 'returns false when status is not completed' do
        contact = create(:contact, :pending)
        expect(contact.lookup_completed?).to be false
      end

      it 'returns false when formatted number is missing' do
        # 'completed' status requires lookup_performed_at to be valid
        contact = create(:contact, status: 'completed', formatted_phone_number: nil, lookup_performed_at: Time.current)
        expect(contact.lookup_completed?).to be false
      end
    end

    describe '#retriable?' do
      it 'returns true for failed with retriable error' do
        contact = create(:contact, :with_network_error)
        expect(contact.retriable?).to be true
      end

      it 'returns false for failed with permanent error' do
        contact = create(:contact, :with_permanent_failure)
        expect(contact.retriable?).to be false
      end

      it 'returns false for non-failed statuses' do
        contact = create(:contact, :completed)
        expect(contact.retriable?).to be false
      end
    end

    describe '#permanent_failure?' do
      it 'returns true for invalid number errors' do
        contact = create(:contact, :failed, error_code: 'Invalid number format')
        expect(contact.permanent_failure?).to be true
      end

      it 'returns true for not found errors' do
        contact = create(:contact, :failed, error_code: 'Number not found')
        expect(contact.permanent_failure?).to be true
      end

      it 'returns false for network errors' do
        contact = create(:contact, :with_network_error)
        expect(contact.permanent_failure?).to be false
      end

      it 'returns false when error_code is blank' do
        contact = create(:contact, :failed, error_code: nil)
        expect(contact.permanent_failure?).to be false
      end
    end
  end

  describe 'bulk operation helpers' do
    describe '.with_callbacks_skipped' do
      it 'skips callbacks during block execution' do
        Contact.with_callbacks_skipped do
          expect(Contact.skip_callbacks_for_bulk_import).to be true
        end
      end

      it 'restores original value after block' do
        Contact.skip_callbacks_for_bulk_import = false

        Contact.with_callbacks_skipped do
          # Inside block
        end

        expect(Contact.skip_callbacks_for_bulk_import).to be false
      end

      it 'restores value even if block raises error' do
        Contact.skip_callbacks_for_bulk_import = false

        expect do
          Contact.with_callbacks_skipped do
            raise StandardError, 'Test error'
          end
        end.to raise_error(StandardError)

        expect(Contact.skip_callbacks_for_bulk_import).to be false
      end
    end

    describe '.recalculate_bulk_metrics' do
      it 'recalculates fingerprints and quality scores for given contacts' do
        contact = create(:contact, :completed)
        # Initial state
        contact.update_column(:phone_fingerprint, nil)

        expect do
          Contact.recalculate_bulk_metrics([contact.id])
        end.to change { contact.reload.phone_fingerprint }.from(nil)
      end
    end
  end

  describe 'callbacks' do
    describe 'fingerprint updates' do
      it 'updates fingerprints when phone number changes' do
        contact = create(:contact, :completed)

        expect do
          contact.update(raw_phone_number: '+14155559999')
        end.to(change { contact.phone_fingerprint })
      end

      it 'updates fingerprints when business name changes' do
        contact = create(:contact, :business)

        expect do
          contact.update(business_name: 'New Company Name')
        end.to(change { contact.name_fingerprint })
      end

      it 'skips fingerprint updates during bulk import' do
        contact = create(:contact, :completed)

        Contact.with_callbacks_skipped do
          contact.update(raw_phone_number: '+14155559999')
          # Fingerprint should not update
        end
      end
    end

    describe 'quality score updates' do
      it 'recalculates quality score when email changes' do
        contact = create(:contact, :completed)

        expect do
          contact.update(email: 'new@example.com', email_verified: true)
        end.to(change { contact.data_quality_score })
      end

      it 'recalculates quality score when business enrichment changes' do
        contact = create(:contact, :completed)

        expect do
          contact.update(business_enriched: true)
        end.to(change { contact.data_quality_score })
      end

      it 'skips quality score calculation during bulk import' do
        contact = create(:contact, :completed)
        original_score = contact.data_quality_score

        Contact.with_callbacks_skipped do
          contact.update(email: 'new@example.com', email_verified: true)
        end

        expect(contact.reload.data_quality_score).to eq(original_score)
      end
    end
  end

  describe 'Verizon coverage helpers' do
    describe '#verizon_home_internet_available?' do
      it 'returns true when 5G available' do
        contact = create(:contact, :with_verizon_coverage, verizon_5g_home_available: true)
        expect(contact.verizon_home_internet_available?).to be true
      end

      it 'returns true when Fios available' do
        contact = create(:contact, :with_address_enrichment, verizon_fios_available: true)
        expect(contact.verizon_home_internet_available?).to be true
      end

      it 'returns false when no services available' do
        contact = create(:contact, :with_address_enrichment,
                         verizon_5g_home_available: false,
                         verizon_lte_home_available: false,
                         verizon_fios_available: false)
        expect(contact.verizon_home_internet_available?).to be false
      end
    end

    describe '#verizon_products_available' do
      it 'lists all available products' do
        contact = create(:contact, :with_address_enrichment,
                         verizon_fios_available: true,
                         verizon_5g_home_available: true,
                         verizon_lte_home_available: true)
        expect(contact.verizon_products_available).to eq('Fios, 5G Home, LTE Home')
      end

      it 'returns None when no products available' do
        contact = create(:contact, :with_address_enrichment,
                         verizon_fios_available: false,
                         verizon_5g_home_available: false,
                         verizon_lte_home_available: false)
        expect(contact.verizon_products_available).to eq('None')
      end
    end

    describe '#verizon_best_product' do
      it 'prioritizes Fios over other products' do
        contact = create(:contact, :with_address_enrichment,
                         verizon_fios_available: true,
                         verizon_5g_home_available: true)
        expect(contact.verizon_best_product).to eq('Fios')
      end

      it 'returns 5G Home when Fios unavailable' do
        contact = create(:contact, :with_verizon_coverage)
        expect(contact.verizon_best_product).to eq('5G Home')
      end

      it 'returns Not Available when no products available' do
        contact = create(:contact, :with_address_enrichment,
                         verizon_fios_available: false,
                         verizon_5g_home_available: false,
                         verizon_lte_home_available: false)
        expect(contact.verizon_best_product).to eq('Not Available')
      end
    end
  end

  describe 'Trust Hub helpers' do
    describe '#trust_hub_verified?' do
      it 'returns true for verified contacts' do
        contact = create(:contact, :trust_hub_verified)
        expect(contact.trust_hub_verified?).to be true
      end
    end

    describe '#trust_hub_pending?' do
      it 'returns true for pending statuses' do
        contact = create(:contact, :trust_hub_pending)
        expect(contact.trust_hub_pending?).to be true
      end

      it 'returns true for in-review status' do
        contact = create(:contact, :business, trust_hub_status: 'in-review')
        expect(contact.trust_hub_pending?).to be true
      end
    end

    describe '#trust_hub_approved?' do
      it 'returns true for approved statuses' do
        contact = create(:contact, :trust_hub_verified, trust_hub_status: 'twilio-approved')
        expect(contact.trust_hub_approved?).to be true
      end

      it 'returns true for compliant status' do
        contact = create(:contact, :business, trust_hub_status: 'compliant')
        expect(contact.trust_hub_approved?).to be true
      end
    end

    describe '#trust_hub_status_display' do
      it 'returns Not Checked when not enriched' do
        contact = create(:contact, :business, trust_hub_enriched: false)
        expect(contact.trust_hub_status_display).to eq('Not Checked')
      end

      it 'returns Verified when verified' do
        contact = create(:contact, :trust_hub_verified)
        expect(contact.trust_hub_status_display).to eq('Verified')
      end

      it 'returns titleized status otherwise' do
        contact = create(:contact, :business, business_name: 'Acme', trust_hub_status: 'pending-review',
                                              trust_hub_enriched: true)
        expect(contact.trust_hub_status_display).to eq('Pending Review')
      end
    end

    describe '#trust_hub_verification_level' do
      it 'returns Excellent for scores 90-100' do
        contact = create(:contact, :trust_hub_verified, trust_hub_verification_score: 95)
        expect(contact.trust_hub_verification_level).to eq('Excellent')
      end

      it 'returns Good for scores 70-89' do
        contact = create(:contact, :business, trust_hub_verification_score: 75)
        expect(contact.trust_hub_verification_level).to eq('Good')
      end

      it 'returns None when score is nil' do
        contact = create(:contact, :business, trust_hub_verification_score: nil)
        expect(contact.trust_hub_verification_level).to eq('None')
      end
    end
  end
end
