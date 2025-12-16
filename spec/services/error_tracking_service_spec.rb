# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ErrorTrackingService do
  describe '.capture' do
    let(:error) { StandardError.new('Test error') }
    let(:context) { { contact_id: 123, job_id: 'abc123' } }

    it 'logs the error with context' do
      expect(Rails.logger).to receive(:error).with(/Test error/)
      described_class.capture(error, context: context)
    end

    it 'includes context in the log entry' do
      expect(Rails.logger).to receive(:error).with(/contact_id.*123/)
      described_class.capture(error, context: context)
    end

    context 'when Sentry is configured' do
      before do
        stub_const('Sentry', double)
        allow(Sentry).to receive(:capture_exception)
      end

      it 'sends the exception to Sentry' do
        expect(Sentry).to receive(:capture_exception).with(error, hash_including(:extra))
        described_class.capture(error, context: context)
      end
    end
  end

  describe '.track_api_error' do
    it 'logs API errors with service name' do
      expect(Rails.logger).to receive(:error).with(/Hunter/)
      described_class.track_api_error(
        service: 'Hunter',
        error: 'Rate limit exceeded',
        context: { contact_id: 1 }
      )
    end

    it 'categorizes API errors correctly' do
      expect(Rails.logger).to receive(:error).with(/api_error/)
      described_class.track_api_error(
        service: 'Clearbit',
        error: 'Connection timeout'
      )
    end
  end

  describe '.track_circuit_breaker' do
    it 'logs circuit breaker state changes' do
      expect(Rails.logger).to receive(:error).with(/Circuit breaker open/)
      described_class.track_circuit_breaker(
        service: :twilio,
        state: :open,
        context: { failures: 5 }
      )
    end

    it 'logs info level for closed state' do
      expect(Rails.logger).to receive(:info).with(/Circuit breaker closed/)
      described_class.track_circuit_breaker(
        service: :twilio,
        state: :closed
      )
    end
  end

  describe '.categorize_error' do
    it 'categorizes timeout errors as transient' do
      error = StandardError.new('Connection timeout')
      expect(described_class.categorize_error(error)).to eq(:transient)
    end

    it 'categorizes rate limit errors as transient' do
      error = StandardError.new('429 Too Many Requests')
      expect(described_class.categorize_error(error)).to eq(:transient)
    end

    it 'categorizes invalid number errors as permanent' do
      error = StandardError.new('invalid_number: not a valid phone')
      expect(described_class.categorize_error(error)).to eq(:permanent)
    end

    it 'categorizes missing key errors as configuration' do
      error = StandardError.new('missing_key: API key not configured')
      expect(described_class.categorize_error(error)).to eq(:configuration)
    end

    it 'defaults to internal for unknown errors' do
      error = StandardError.new('Something unexpected happened')
      expect(described_class.categorize_error(error)).to eq(:internal)
    end
  end

  describe 'structured logging' do
    it 'outputs JSON in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(Rails.logger).to receive(:error) do |message|
        expect { JSON.parse(message) }.not_to raise_error
      end

      described_class.capture(StandardError.new('Test'))
    end

    it 'outputs readable format in development' do
      allow(Rails.env).to receive(:production?).and_return(false)

      expect(Rails.logger).to receive(:error).with(/\[ERROR\]/)

      described_class.capture(StandardError.new('Test'))
    end
  end
end
