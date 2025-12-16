# frozen_string_literal: true

require 'rails_helper'
require 'middleware/request_logger'

RSpec.describe Middleware::RequestLogger do
  let(:app) { ->(env) { [200, {}, ['OK']] } }
  let(:middleware) { described_class.new(app) }
  let(:request) { Rack::MockRequest.new(middleware) }
  let(:logger) { instance_double(Logger) }

  before do
    allow(Rails).to receive(:logger).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe '#call' do
    it 'calls the app' do
      response = request.get('/')
      expect(response.status).to eq(200)
      expect(response.body).to eq('OK')
    end

    it 'logs request start' do
      expect(logger).to receive(:info).with(hash_including(event: 'request_started', path: '/'))
      request.get('/')
    end

    it 'logs request completion' do
      expect(logger).to receive(:info).with(hash_including(event: 'request_completed', status: 200))
      request.get('/')
    end

    it 'calculates duration' do
      expect(logger).to receive(:info).with(hash_including(event: 'request_completed')) do |log_data|
        expect(log_data[:duration_ms]).to be_a(Numeric)
      end
      request.get('/')
    end

    context 'with sensitive parameters' do
      it 'redacts sensitive keys' do
        expect(logger).to receive(:info).with(hash_including(event: 'request_started')) do |log_data|
          expect(log_data[:params]['password']).to eq('[REDACTED]')
          expect(log_data[:params]['token']).to eq('[REDACTED]')
          expect(log_data[:params]['safe_param']).to eq('safe')
        end

        request.post('/', params: { password: 'secret', token: '12345', safe_param: 'safe' })
      end

      it 'redacts nested sensitive keys' do
        expect(logger).to receive(:info).with(hash_including(event: 'request_started')) do |log_data|
          expect(log_data[:params]['user']['password']).to eq('[REDACTED]')
        end

        request.post('/', params: { user: { password: 'secret' } })
      end
    end

    context 'when an exception occurs' do
      let(:app) { ->(_env) { raise StandardError, 'Something went wrong' } }

      it 'logs the exception and re-raises' do
        expect(logger).to receive(:error).with(hash_including(
                                                 event: 'request_failed',
                                                 error: 'Something went wrong',
                                                 error_class: 'StandardError'
                                               ))

        expect { request.get('/') }.to raise_error(StandardError, 'Something went wrong')
      end
    end
  end
end
