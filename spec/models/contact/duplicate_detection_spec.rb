# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contact::DuplicateDetection, type: :model do
  # Tests for duplicate detection fingerprinting
  # Requirements: 3.1, 3.2, 3.3, 3.4, 3.5

  describe 'fingerprint determinism' do
    # Requirements: 3.2, 3.5 - Identical phones produce identical fingerprints

    it 'generates identical phone fingerprints for identical phone numbers' do
      phone = '+14155551234'
      contact1 = build(:contact, formatted_phone_number: phone)
      contact2 = build(:contact, formatted_phone_number: phone)

      fingerprint1 = contact1.send(:calculate_phone_fingerprint)
      fingerprint2 = contact2.send(:calculate_phone_fingerprint)

      expect(fingerprint1).to eq(fingerprint2)
    end

    it 'generates identical fingerprints regardless of country code prefix' do
      # Both should normalize to last 10 digits
      contact1 = build(:contact, formatted_phone_number: '+14155551234')
      contact2 = build(:contact, formatted_phone_number: '+441234155551234')

      fingerprint1 = contact1.send(:calculate_phone_fingerprint)
      fingerprint2 = contact2.send(:calculate_phone_fingerprint)

      # Both should extract last 10 digits
      expect(fingerprint1).to eq('4155551234')
      expect(fingerprint2).to eq('4155551234')
    end

    it 'uses consistent hashing algorithm across multiple calls' do
      contact = build(:contact, formatted_phone_number: '+14155551234')

      fingerprints = 5.times.map { contact.send(:calculate_phone_fingerprint) }

      expect(fingerprints.uniq.size).to eq(1)
    end

    it 'generates identical name fingerprints for identical names' do
      name = 'Acme Corporation'
      contact1 = build(:contact, business_name: name, is_business: true)
      contact2 = build(:contact, business_name: name, is_business: true)

      fingerprint1 = contact1.send(:calculate_name_fingerprint)
      fingerprint2 = contact2.send(:calculate_name_fingerprint)

      expect(fingerprint1).to eq(fingerprint2)
    end

    it 'normalizes name fingerprints (case insensitive, sorted words)' do
      contact1 = build(:contact, business_name: 'Acme Corp', is_business: true)
      contact2 = build(:contact, business_name: 'ACME CORP', is_business: true)
      contact3 = build(:contact, business_name: 'Corp Acme', is_business: true)

      fingerprint1 = contact1.send(:calculate_name_fingerprint)
      fingerprint2 = contact2.send(:calculate_name_fingerprint)
      fingerprint3 = contact3.send(:calculate_name_fingerprint)

      expect(fingerprint1).to eq(fingerprint2)
      expect(fingerprint1).to eq(fingerprint3)
    end

    it 'generates identical email fingerprints for identical emails' do
      email = 'test@example.com'
      contact1 = build(:contact, email: email)
      contact2 = build(:contact, email: email)

      fingerprint1 = contact1.send(:calculate_email_fingerprint)
      fingerprint2 = contact2.send(:calculate_email_fingerprint)

      expect(fingerprint1).to eq(fingerprint2)
    end

    it 'normalizes email fingerprints (case insensitive, trimmed)' do
      contact1 = build(:contact, email: 'Test@Example.COM')
      contact2 = build(:contact, email: '  test@example.com  ')

      fingerprint1 = contact1.send(:calculate_email_fingerprint)
      fingerprint2 = contact2.send(:calculate_email_fingerprint)

      expect(fingerprint1).to eq(fingerprint2)
    end
  end

  describe 'fingerprint uniqueness' do
    # Requirements: 3.3 - Different phones produce different fingerprints

    it 'generates different phone fingerprints for different phone numbers' do
      contact1 = build(:contact, formatted_phone_number: '+14155551234')
      contact2 = build(:contact, formatted_phone_number: '+14155559999')

      fingerprint1 = contact1.send(:calculate_phone_fingerprint)
      fingerprint2 = contact2.send(:calculate_phone_fingerprint)

      expect(fingerprint1).not_to eq(fingerprint2)
    end

    it 'generates different name fingerprints for different names' do
      contact1 = build(:contact, business_name: 'Acme Corp', is_business: true)
      contact2 = build(:contact, business_name: 'Beta Inc', is_business: true)

      fingerprint1 = contact1.send(:calculate_name_fingerprint)
      fingerprint2 = contact2.send(:calculate_name_fingerprint)

      expect(fingerprint1).not_to eq(fingerprint2)
    end

    it 'generates different email fingerprints for different emails' do
      contact1 = build(:contact, email: 'alice@example.com')
      contact2 = build(:contact, email: 'bob@example.com')

      fingerprint1 = contact1.send(:calculate_email_fingerprint)
      fingerprint2 = contact2.send(:calculate_email_fingerprint)

      expect(fingerprint1).not_to eq(fingerprint2)
    end

    it 'handles nil values gracefully' do
      contact = build(:contact, formatted_phone_number: nil, raw_phone_number: nil)
      expect(contact.send(:calculate_phone_fingerprint)).to be_nil

      contact = build(:contact, business_name: nil, full_name: nil)
      expect(contact.send(:calculate_name_fingerprint)).to be_nil

      contact = build(:contact, email: nil)
      expect(contact.send(:calculate_email_fingerprint)).to be_nil
    end
  end

  describe 'fingerprint recalculation' do
    # Requirements: 3.1, 3.4 - Updates trigger fingerprint recalculation

    it 'recalculates phone fingerprint when phone number is updated' do
      contact = create(:contact, formatted_phone_number: '+14155551234')
      original_fingerprint = contact.phone_fingerprint

      contact.update!(formatted_phone_number: '+14155559999')

      expect(contact.reload.phone_fingerprint).not_to eq(original_fingerprint)
      expect(contact.phone_fingerprint).to eq('4155559999')
    end

    it 'recalculates phone fingerprint when raw_phone_number is updated' do
      contact = create(:contact, raw_phone_number: '+14155551234')
      original_fingerprint = contact.phone_fingerprint

      contact.update!(raw_phone_number: '+14155558888')

      expect(contact.reload.phone_fingerprint).not_to eq(original_fingerprint)
    end

    it 'recalculates name fingerprint when business_name is updated' do
      contact = create(:contact, :business, business_name: 'Acme Corp')
      original_fingerprint = contact.name_fingerprint

      contact.update!(business_name: 'Beta Inc')

      expect(contact.reload.name_fingerprint).not_to eq(original_fingerprint)
      expect(contact.name_fingerprint).to eq('beta inc')
    end

    it 'recalculates name fingerprint when full_name is updated' do
      contact = create(:contact, :consumer, full_name: 'John Doe')
      original_fingerprint = contact.name_fingerprint

      contact.update!(full_name: 'Jane Smith')

      expect(contact.reload.name_fingerprint).not_to eq(original_fingerprint)
      expect(contact.name_fingerprint).to eq('jane smith')
    end

    it 'recalculates email fingerprint when email is updated' do
      contact = create(:contact, email: 'old@example.com')
      original_fingerprint = contact.email_fingerprint

      contact.update!(email: 'new@example.com')

      expect(contact.reload.email_fingerprint).not_to eq(original_fingerprint)
      expect(contact.email_fingerprint).to eq('new@example.com')
    end

    it 'does not recalculate fingerprints when unrelated fields are updated' do
      contact = create(:contact, formatted_phone_number: '+14155551234')
      original_phone_fingerprint = contact.phone_fingerprint

      # Update an unrelated field
      contact.update!(carrier_name: 'Verizon')

      expect(contact.reload.phone_fingerprint).to eq(original_phone_fingerprint)
    end
  end

  describe '#update_fingerprints!' do
    it 'updates all fingerprints using update_columns' do
      contact = create(:contact,
                       formatted_phone_number: '+14155551234',
                       business_name: 'Test Corp',
                       is_business: true,
                       email: 'test@example.com')

      # Clear fingerprints to test recalculation
      contact.update_columns(phone_fingerprint: nil, name_fingerprint: nil, email_fingerprint: nil)

      contact.update_fingerprints!

      expect(contact.phone_fingerprint).to eq('4155551234')
      expect(contact.name_fingerprint).to eq('corp test')
      expect(contact.email_fingerprint).to eq('test@example.com')
    end

    it 'uses update_columns to skip callbacks' do
      contact = create(:contact)

      expect(contact).to receive(:update_columns).once.and_call_original

      contact.update_fingerprints!
    end
  end

  describe 'duplicate detection helpers' do
    it '#has_duplicates? returns true when duplicates exist' do
      primary = create(:contact)
      create(:contact, duplicate_of: primary, is_duplicate: true)

      expect(primary.has_duplicates?).to be true
    end

    it '#has_duplicates? returns false when no duplicates exist' do
      contact = create(:contact)

      expect(contact.has_duplicates?).to be false
    end

    it '#duplicate_contacts returns all contacts marked as duplicates' do
      primary = create(:contact)
      dup1 = create(:contact, duplicate_of: primary, is_duplicate: true)
      dup2 = create(:contact, duplicate_of: primary, is_duplicate: true)

      expect(primary.duplicate_contacts).to contain_exactly(dup1, dup2)
    end
  end

  describe 'scopes' do
    let!(:primary_contact) { create(:contact, is_duplicate: false) }
    let!(:duplicate_contact) { create(:contact, is_duplicate: true, duplicate_of: primary_contact) }
    let!(:high_quality_contact) { create(:contact, data_quality_score: 85) }
    let!(:low_quality_contact) { create(:contact, data_quality_score: 25) }

    it '.primary_contacts returns non-duplicate contacts' do
      expect(Contact.primary_contacts).to include(primary_contact)
      expect(Contact.primary_contacts).not_to include(duplicate_contact)
    end

    it '.confirmed_duplicates returns duplicate contacts' do
      expect(Contact.confirmed_duplicates).to include(duplicate_contact)
      expect(Contact.confirmed_duplicates).not_to include(primary_contact)
    end

    it '.high_quality returns contacts with score >= 70' do
      expect(Contact.high_quality).to include(high_quality_contact)
      expect(Contact.high_quality).not_to include(low_quality_contact)
    end

    it '.low_quality returns contacts with score < 40' do
      expect(Contact.low_quality).to include(low_quality_contact)
      expect(Contact.low_quality).not_to include(high_quality_contact)
    end
  end
end
