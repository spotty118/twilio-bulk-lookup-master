# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BusinessEnrichmentService do
  let(:twilio_credential) { create(:twilio_credential, enable_business_enrichment: true) }

  before do
    # Ensure TwilioCredential singleton exists
    TwilioCredential.delete_all
    twilio_credential
  end

  describe '.enrich' do
    context 'when contact should not be enriched' do
      let(:contact) { create(:contact, :completed, caller_type: nil, caller_name: nil) }

      it 'returns false without making API calls' do
        result = described_class.enrich(contact)
        expect(result).to be false
      end
    end

    context 'when contact is a business' do
      # Use a non-US contact without caller_name to test pure API error handling
      # (US contacts with caller_name will fall back to CNAM)
      let(:contact) { create(:contact, :completed, caller_type: 'business', caller_name: nil, country_code: 'GB') }

      context 'with API errors (HTTP 500)' do
        before do
          # Set up API keys so the service actually makes requests
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('CLEARBIT_API_KEY').and_return('test_clearbit_key')
          allow(ENV).to receive(:[]).with('NUMVERIFY_API_KEY').and_return('test_numverify_key')

          # Stub Clearbit API to return error
          stub_request(:get, /prospector\.clearbit\.com/)
            .to_return(status: 500, body: 'Internal Server Error')

          # Stub NumVerify API to return error
          stub_request(:get, /apilayer\.net/)
            .to_return(status: 500, body: 'Internal Server Error')
        end

        it 'returns gracefully without raising' do
          expect { described_class.enrich(contact) }.not_to raise_error
        end

        it 'does not corrupt contact data on API error' do
          original_business_name = contact.business_name

          described_class.enrich(contact)
          contact.reload

          # Contact data should remain unchanged when all providers fail
          expect(contact.business_name).to eq(original_business_name)
        end
      end

      context 'with HTTParty exceptions' do
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('CLEARBIT_API_KEY').and_return('test_clearbit_key')
          allow(ENV).to receive(:[]).with('NUMVERIFY_API_KEY').and_return('test_numverify_key')

          # Stub to raise HTTParty error
          stub_request(:get, /prospector\.clearbit\.com/)
            .to_raise(HTTParty::Error.new('Connection failed'))

          stub_request(:get, /apilayer\.net/)
            .to_raise(HTTParty::Error.new('Connection failed'))
        end

        it 'logs the error and returns gracefully without raising' do
          expect(Rails.logger).to receive(:warn).at_least(:once)

          expect { described_class.enrich(contact) }.not_to raise_error
        end
      end

      context 'with invalid JSON response' do
        before do
          stub_request(:get, /prospector\.clearbit\.com/)
            .to_return(status: 200, body: 'not valid json {{{')

          stub_request(:get, /apilayer\.net/)
            .to_return(status: 200, body: 'also not valid json')
        end

        it 'handles invalid response and does not corrupt contact data' do
          original_attributes = contact.attributes.slice(
            'business_name', 'business_type', 'business_industry'
          )

          expect { described_class.enrich(contact) }.not_to raise_error

          contact.reload
          # Data should remain unchanged when all providers return invalid JSON
          expect(contact.attributes.slice('business_name', 'business_type', 'business_industry'))
            .to eq(original_attributes)
        end
      end

      context 'with timeout errors' do
        before do
          stub_request(:get, /prospector\.clearbit\.com/)
            .to_timeout

          stub_request(:get, /apilayer\.net/)
            .to_timeout
        end

        it 'handles timeout gracefully without raising' do
          expect { described_class.enrich(contact) }.not_to raise_error
        end
      end
    end
  end


  describe 'provider fallback' do
    let(:contact) { create(:contact, :completed, caller_type: 'business', caller_name: 'Test Business', country_code: 'US') }

    before do
      # Set up API keys
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CLEARBIT_API_KEY').and_return('test_clearbit_key')
      allow(ENV).to receive(:[]).with('NUMVERIFY_API_KEY').and_return('test_numverify_key')
    end

    context 'when Clearbit fails' do
      before do
        # Clearbit fails
        stub_request(:get, /prospector\.clearbit\.com/)
          .to_return(status: 500, body: 'Server Error')

        # NumVerify succeeds with valid business data
        stub_request(:get, /apilayer\.net/)
          .to_return(
            status: 200,
            body: {
              valid: true,
              line_type: 'landline',
              carrier: 'Test Carrier',
              country_name: 'United States'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'falls back to NumVerify provider' do
        result = described_class.enrich(contact)

        # Should succeed using NumVerify fallback
        expect(result).to be true
        contact.reload
        expect(contact.business_enrichment_provider).to eq('numverify')
      end
    end

    context 'when Clearbit and NumVerify both fail' do
      before do
        stub_request(:get, /prospector\.clearbit\.com/)
          .to_return(status: 500, body: 'Server Error')

        stub_request(:get, /apilayer\.net/)
          .to_return(status: 500, body: 'Server Error')
      end

      it 'falls back to CNAM data from Twilio' do
        result = described_class.enrich(contact)

        # Should succeed using existing caller name as fallback
        expect(result).to be true
        contact.reload
        expect(contact.business_enrichment_provider).to eq('twilio_cnam')
        expect(contact.business_name).to eq('Test Business')
      end
    end

    context 'when all providers fail for non-US contact' do
      let(:contact) { create(:contact, :completed, caller_type: 'business', caller_name: nil, country_code: 'GB') }

      before do
        stub_request(:get, /prospector\.clearbit\.com/)
          .to_return(status: 500, body: 'Server Error')

        stub_request(:get, /apilayer\.net/)
          .to_return(status: 500, body: 'Server Error')
      end

      it 'returns false when no provider succeeds' do
        result = described_class.enrich(contact)
        expect(result).to be false
      end
    end
  end

  describe 'error isolation' do
    let(:contact) { create(:contact, :completed, caller_type: 'business', caller_name: 'Test Corp') }

    context 'when database error occurs during update' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CLEARBIT_API_KEY').and_return('test_key')

        # Clearbit returns valid data
        stub_request(:get, /prospector\.clearbit\.com/)
          .to_return(
            status: 200,
            body: {
              results: [{
                company: {
                  name: 'Test Company',
                  domain: 'test.com'
                }
              }]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        stub_request(:get, /company\.clearbit\.com/)
          .to_return(
            status: 200,
            body: {
              name: 'Test Company',
              domain: 'test.com',
              category: { industry: 'Technology' }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Simulate database error on update
        allow(contact).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(contact))
      end

      it 'logs database error and returns false' do
        expect(Rails.logger).to receive(:error).with(/Database error/)

        result = described_class.enrich(contact)
        expect(result).to be false
      end
    end

    context 'when contact is deleted during enrichment' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('CLEARBIT_API_KEY').and_return('test_key')

        stub_request(:get, /prospector\.clearbit\.com/)
          .to_return(
            status: 200,
            body: { results: [{ company: { name: 'Test' } }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        allow(contact).to receive(:update!).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'handles record not found gracefully' do
        expect(Rails.logger).to receive(:error).with(/Contact not found/)

        result = described_class.enrich(contact)
        expect(result).to be false
      end
    end
  end

  describe 'circuit breaker integration' do
    let(:contact) { create(:contact, :completed, caller_type: 'business', caller_name: 'Test') }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CLEARBIT_API_KEY').and_return('test_key')
    end

    context 'when circuit breaker is open' do
      before do
        # Simulate circuit breaker returning open state
        allow(CircuitBreakerService).to receive(:call).with(:clearbit).and_return(
          { circuit_open: true, error: 'Service unavailable' }
        )
        allow(CircuitBreakerService).to receive(:call).with(:numverify).and_return(
          { circuit_open: true, error: 'Service unavailable' }
        )
      end

      it 'handles circuit open gracefully and falls back' do
        result = described_class.enrich(contact)

        # Should fall back to CNAM since circuit is open
        expect(result).to be true
        contact.reload
        expect(contact.business_enrichment_provider).to eq('twilio_cnam')
      end
    end
  end
end
