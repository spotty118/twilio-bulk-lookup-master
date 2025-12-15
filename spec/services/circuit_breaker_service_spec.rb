# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CircuitBreakerService, type: :service do
  # Mock Redis for testing
  let(:redis) { MockRedis.new }

  before do
    # Stub Redis.current to use MockRedis
    allow(Redis).to receive(:current).and_return(redis)

    # Reset all circuits before each test
    CircuitBreakerService::SERVICES.keys.each do |service_name|
      CircuitBreakerService.reset(service_name)
    end
  end

  describe '.call' do
    context 'with successful API call' do
      it 'executes the block and returns result' do
        result = CircuitBreakerService.call(:clearbit) do
          'API response'
        end

        expect(result).to eq('API response')
      end

      it 'keeps circuit closed after successful call' do
        CircuitBreakerService.call(:clearbit) { 'success' }

        state = CircuitBreakerService.state(:clearbit)
        expect(state).to eq(:closed)
      end
    end

    context 'with failing API calls' do
      it 'opens circuit after threshold failures' do
        config = CircuitBreakerService::SERVICES[:clearbit]
        threshold = config[:threshold]

        # Trigger failures up to threshold
        threshold.times do
          CircuitBreakerService.call(:clearbit) { raise StandardError, 'API failure' }
        rescue StandardError
          nil
        end

        # Circuit should now be open
        state = CircuitBreakerService.state(:clearbit)
        expect(state).to eq(:open)
      end

      it 'returns fallback when circuit is open' do
        # Open the circuit by triggering failures
        6.times do
          CircuitBreakerService.call(:clearbit) { raise 'Fail' }
        rescue StandardError
          nil
        end

        # Next call should hit fallback
        result = CircuitBreakerService.call(:clearbit) { 'Should not execute' }

        expect(result).to be_a(Hash)
        expect(result[:circuit_open]).to be true
        expect(result[:error]).to include('temporarily unavailable')
        expect(result[:service]).to eq(:clearbit)
      end

      it 'does not execute block when circuit is open' do
        executed = false

        # Open circuit
        6.times do
          CircuitBreakerService.call(:clearbit) { raise 'Fail' }
        rescue StandardError
          nil
        end

        # This should not execute the block
        CircuitBreakerService.call(:clearbit) { executed = true }

        expect(executed).to be false
      end
    end

    context 'with unknown service' do
      it 'logs warning and executes block without circuit breaker' do
        allow(Rails.logger).to receive(:warn)

        result = CircuitBreakerService.call(:unknown_service) { 'executed' }

        expect(result).to eq('executed')
        expect(Rails.logger).to have_received(:warn).with(/Unknown circuit breaker service/)
      end
    end
  end

  describe '.state' do
    it 'returns :closed for healthy circuit' do
      expect(CircuitBreakerService.state(:clearbit)).to eq(:closed)
    end

    it 'returns :open for failed circuit' do
      # Trigger failures
      6.times do
        CircuitBreakerService.call(:clearbit) { raise 'Fail' }
      rescue StandardError
        nil
      end

      expect(CircuitBreakerService.state(:clearbit)).to eq(:open)
    end

    it 'returns :unknown for unconfigured service' do
      expect(CircuitBreakerService.state(:invalid_service)).to eq(:unknown)
    end
  end

  describe '.all_states' do
    it 'returns states for all configured services' do
      states = CircuitBreakerService.all_states

      expect(states.keys).to match_array(CircuitBreakerService::SERVICES.keys)
    end

    it 'includes service metadata' do
      states = CircuitBreakerService.all_states
      clearbit_state = states[:clearbit]

      expect(clearbit_state).to include(
        :state,
        :color,
        :failures,
        :description,
        :threshold,
        :timeout
      )
    end

    it 'shows correct failure counts' do
      # Trigger 2 failures for Clearbit
      2.times do
        CircuitBreakerService.call(:clearbit) { raise 'Fail' }
      rescue StandardError
        nil
      end

      states = CircuitBreakerService.all_states
      expect(states[:clearbit][:failures]).to be >= 2
    end
  end

  describe '.reset' do
    it 'clears failures and closes circuit' do
      # Open circuit with failures
      6.times do
        CircuitBreakerService.call(:clearbit) { raise 'Fail' }
      rescue StandardError
        nil
      end
      expect(CircuitBreakerService.state(:clearbit)).to eq(:open)

      # Reset circuit
      CircuitBreakerService.reset(:clearbit)

      # Circuit should be closed now
      expect(CircuitBreakerService.state(:clearbit)).to eq(:closed)
    end

    it 'returns true for valid service' do
      expect(CircuitBreakerService.reset(:clearbit)).to be true
    end

    it 'returns false for invalid service' do
      expect(CircuitBreakerService.reset(:invalid)).to be false
    end
  end

  describe '.open_circuit' do
    it 'manually opens a circuit' do
      expect(CircuitBreakerService.state(:clearbit)).to eq(:closed)

      CircuitBreakerService.open_circuit(:clearbit)

      expect(CircuitBreakerService.state(:clearbit)).to eq(:open)
    end

    it 'returns true for valid service' do
      expect(CircuitBreakerService.open_circuit(:clearbit)).to be true
    end

    it 'returns false for invalid service' do
      expect(CircuitBreakerService.open_circuit(:invalid)).to be false
    end
  end

  describe 'integration with services' do
    it 'protects BusinessEnrichmentService from cascade failures' do
      # Mock external API to fail
      stub_request(:get, /prospector.clearbit.com/)
        .to_return(status: 500, body: 'Internal Server Error')

      contact = create(:contact, formatted_phone_number: '+14155551234')

      # Trigger failures
      6.times do
        BusinessEnrichmentService.enrich(contact)
      rescue StandardError
        nil
      end

      # Circuit should be open
      expect(CircuitBreakerService.state(:clearbit)).to eq(:open)

      # Next enrichment should fail fast
      start_time = Time.current
      BusinessEnrichmentService.enrich(contact)
      duration = (Time.current - start_time) * 1000

      # Should be instant (< 100ms) instead of waiting for timeout
      expect(duration).to be < 100
    end
  end

  describe 'per-service configuration' do
    it 'uses different thresholds for different services' do
      clearbit_config = CircuitBreakerService::SERVICES[:clearbit]
      openai_config = CircuitBreakerService::SERVICES[:openai]

      expect(clearbit_config[:threshold]).to eq(3)
      expect(openai_config[:threshold]).to eq(5)
    end

    it 'uses different timeouts for different services' do
      clearbit_config = CircuitBreakerService::SERVICES[:clearbit]
      openai_config = CircuitBreakerService::SERVICES[:openai]

      expect(clearbit_config[:timeout]).to eq(30)
      expect(openai_config[:timeout]).to eq(90)
    end
  end

  describe 'error logging' do
    it 'logs warnings for failures' do
      allow(Rails.logger).to receive(:warn)

      begin
        CircuitBreakerService.call(:clearbit) { raise 'Test failure' }
      rescue StandardError
        nil
      end

      expect(Rails.logger).to have_received(:warn).with(/Circuit breaker failure/)
    end

    it 'logs errors when circuit opens' do
      allow(Rails.logger).to receive(:error)

      # Trigger enough failures to open circuit
      6.times do
        CircuitBreakerService.call(:clearbit) { raise 'Fail' }
      rescue StandardError
        nil
      end

      expect(Rails.logger).to have_received(:error).with(/Circuit breaker OPENED/)
    end

    it 'logs info when circuit closes' do
      allow(Rails.logger).to receive(:info)

      CircuitBreakerService.reset(:clearbit)

      expect(Rails.logger).to have_received(:info).with(/Circuit breaker RESET/)
    end
  end
end
