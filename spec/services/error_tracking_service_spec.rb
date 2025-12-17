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
      expect(Rails.logger).to receive(:error).with(/contact_id/)
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
