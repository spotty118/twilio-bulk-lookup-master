# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Contact, type: :model do
  describe 'validations' do
    let(:contact) { Contact.new(raw_phone_number: '+14155551234') }

    context 'email format' do
      it 'allows valid email' do
        contact.email = 'test@example.com'
        contact.valid?
        expect(contact.errors[:email]).to be_empty
      end

      it 'rejects invalid email' do
        contact.email = 'invalid-email'
        contact.valid?
        expect(contact.errors[:email]).to include('is invalid')
      end

      it 'allows blank email' do
        contact.email = nil
        contact.valid?
        expect(contact.errors[:email]).to be_empty
      end
    end

    context 'data_quality_score' do
      it 'allows valid score' do
        contact.data_quality_score = 85
        contact.valid?
        expect(contact.errors[:data_quality_score]).to be_empty
      end

      it 'rejects score > 100' do
        contact.data_quality_score = 101
        contact.valid?
        expect(contact.errors[:data_quality_score]).to include('must be in 0..100')
      end

      it 'rejects score < 0' do
        contact.data_quality_score = -1
        contact.valid?
        expect(contact.errors[:data_quality_score]).to include('must be in 0..100')
      end

      it 'allows nil score' do
        contact.data_quality_score = nil
        contact.valid?
        expect(contact.errors[:data_quality_score]).to be_empty
      end
    end

    context 'completeness_percentage' do
      it 'allows valid percentage' do
        contact.completeness_percentage = 50
        contact.valid?
        expect(contact.errors[:completeness_percentage]).to be_empty
      end

      it 'rejects percentage > 100' do
        contact.completeness_percentage = 101
        contact.valid?
        expect(contact.errors[:completeness_percentage]).to include('must be in 0..100')
      end
    end

    context 'country_code' do
      it 'allows 2-letter code' do
        contact.country_code = 'US'
        contact.valid?
        expect(contact.errors[:country_code]).to be_empty
      end

      it 'rejects 3-letter code' do
        contact.country_code = 'USA'
        contact.valid?
        expect(contact.errors[:country_code]).to include('is the wrong length (should be 2 characters)')
      end
    end
  end
end
