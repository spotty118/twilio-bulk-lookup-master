# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HttpClient do
  let(:test_uri) { URI('https://api.example.com/test') }
  let(:circuit_name) { 'test-api' }

  # Clean up circuit state before each test
  before do
    HttpClient.reset_circuit!(circuit_name)
    Rails.cache.clear
  end

  after do
    HttpClient.reset_circuit!(circuit_name)
  end

  describe '.get' do
    context 'without circuit breaker' do
      it 'performs HTTP GET request successfully' do
        stub_request(:get, test_uri.to_s)
          .to_return(status: 200, body: '{"success": true}')

        response = HttpClient.get(test_uri)

        expect(response.code).to eq('200')
        expect(response.body).to eq('{"success": true}')
      end

      it 'allows custom headers via block' do
        stub_request(:get, test_uri.to_s)
          .with(headers: { 'Authorization' => 'Bearer token123' })
          .to_return(status: 200)

        response = HttpClient.get(test_uri) do |request|
          request['Authorization'] = 'Bearer token123'
        end

        expect(response.code).to eq('200')
      end

      it 'uses default timeouts' do
        # Verify Net::HTTP.start is called with correct timeouts
        expect(Net::HTTP).to receive(:start).with(
          test_uri.hostname,
          test_uri.port,
          hash_including(
            use_ssl: true,
            read_timeout: 10,
            open_timeout: 5,
            connect_timeout: 5
          )
        ).and_call_original

        stub_request(:get, test_uri.to_s).to_return(status: 200)
        HttpClient.get(test_uri)
      end

      it 'allows timeout overrides' do
        expect(Net::HTTP).to receive(:start).with(
          test_uri.hostname,
          test_uri.port,
          hash_including(read_timeout: 30)
        ).and_call_original

        stub_request(:get, test_uri.to_s).to_return(status: 200)
        HttpClient.get(test_uri, read_timeout: 30)
      end

      it 'raises TimeoutError on read timeout' do
        stub_request(:get, test_uri.to_s).to_timeout

        expect {
          HttpClient.get(test_uri)
        }.to raise_error(HttpClient::TimeoutError, /timed out/)
      end
    end

    context 'with circuit breaker' do
      it 'records successful requests' do
        stub_request(:get, test_uri.to_s).to_return(status: 200)

        HttpClient.get(test_uri, circuit_name: circuit_name)

        # Circuit state should be cleared (success resets failure count)
        expect(HttpClient.circuit_state(circuit_name)).to be_nil
      end

      it 'records failed requests and increments failure count' do
        stub_request(:get, test_uri.to_s).to_timeout

        expect {
          HttpClient.get(test_uri, circuit_name: circuit_name)
        }.to raise_error(HttpClient::TimeoutError)

        state = HttpClient.circuit_state(circuit_name)
        expect(state[:failures]).to eq(1)
      end

      it 'opens circuit after 5 consecutive failures' do
        stub_request(:get, test_uri.to_s).to_timeout

        # Fail 5 times
        5.times do
          expect {
            HttpClient.get(test_uri, circuit_name: circuit_name)
          }.to raise_error(HttpClient::TimeoutError)
        end

        # Circuit should now be open
        state = HttpClient.circuit_state(circuit_name)
        expect(state[:open]).to be true
        expect(state[:failures]).to eq(5)
      end

      it 'raises CircuitOpenError when circuit is open' do
        # Open the circuit
        stub_request(:get, test_uri.to_s).to_timeout
        5.times do
          HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil
        end

        # Next request should raise CircuitOpenError immediately (no HTTP request)
        expect {
          HttpClient.get(test_uri, circuit_name: circuit_name)
        }.to raise_error(HttpClient::CircuitOpenError, /is open/)

        # Verify no HTTP request was made (circuit short-circuited)
        # WebMock would raise if request was made without stub
      end

      it 'includes retry time in CircuitOpenError message' do
        stub_request(:get, test_uri.to_s).to_timeout
        5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

        expect {
          HttpClient.get(test_uri, circuit_name: circuit_name)
        }.to raise_error(HttpClient::CircuitOpenError, /retry in \d+s/)
      end

      it 'auto-closes circuit after cool-off period (60 seconds)' do
        stub_request(:get, test_uri.to_s).to_timeout

        # Open circuit
        5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

        # Fast-forward time by 61 seconds
        travel 61.seconds do
          # Circuit should auto-close and allow request through
          stub_request(:get, test_uri.to_s).to_return(status: 200)

          response = HttpClient.get(test_uri, circuit_name: circuit_name)
          expect(response.code).to eq('200')

          # Circuit state should be cleared after successful request
          expect(HttpClient.circuit_state(circuit_name)).to be_nil
        end
      end

      it 'resets failure count on successful request after failures' do
        stub_request(:get, test_uri.to_s).to_timeout

        # Fail 3 times
        3.times do
          HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil
        end

        expect(HttpClient.circuit_state(circuit_name)[:failures]).to eq(3)

        # Succeed once
        stub_request(:get, test_uri.to_s).to_return(status: 200)
        HttpClient.get(test_uri, circuit_name: circuit_name)

        # Failure count should be reset
        expect(HttpClient.circuit_state(circuit_name)).to be_nil
      end
    end
  end

  describe '.post' do
    it 'performs HTTP POST request with JSON body' do
      stub_request(:post, test_uri.to_s)
        .with(
          body: '{"key":"value"}',
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(status: 201, body: '{"created": true}')

      response = HttpClient.post(test_uri, body: { key: 'value' })

      expect(response.code).to eq('201')
      expect(response.body).to eq('{"created": true}')
    end

    it 'accepts raw string body' do
      stub_request(:post, test_uri.to_s)
        .with(body: 'raw body')
        .to_return(status: 200)

      response = HttpClient.post(test_uri, body: 'raw body')
      expect(response.code).to eq('200')
    end

    it 'works with circuit breaker' do
      stub_request(:post, test_uri.to_s).to_return(status: 200)

      response = HttpClient.post(test_uri, body: {}, circuit_name: circuit_name)
      expect(response.code).to eq('200')
      expect(HttpClient.circuit_state(circuit_name)).to be_nil
    end

    it 'records failures with circuit breaker' do
      stub_request(:post, test_uri.to_s).to_timeout

      expect {
        HttpClient.post(test_uri, body: {}, circuit_name: circuit_name)
      }.to raise_error(HttpClient::TimeoutError)

      expect(HttpClient.circuit_state(circuit_name)[:failures]).to eq(1)
    end
  end

  describe 'distributed circuit breaker (Redis-backed)' do
    it 'shares circuit state across processes via Rails.cache' do
      # Simulate Process 1 opening circuit
      stub_request(:get, test_uri.to_s).to_timeout
      5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      # Simulate Process 2 checking state
      # In a real multi-process scenario, this would be a different Ruby process
      # But Rails.cache (Redis) ensures the state is shared
      expect {
        HttpClient.get(test_uri, circuit_name: circuit_name)
      }.to raise_error(HttpClient::CircuitOpenError)
    end

    it 'circuit state expires after 5 minutes of inactivity' do
      stub_request(:get, test_uri.to_s).to_timeout
      3.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      # Fast-forward 6 minutes
      travel 6.minutes do
        # Circuit state should be expired from cache
        expect(HttpClient.circuit_state(circuit_name)).to be_nil

        # New request should start with fresh failure count
        HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil
        expect(HttpClient.circuit_state(circuit_name)[:failures]).to eq(1)
      end
    end

    it 'prevents cache stampede with race_condition_ttl' do
      # This is implicitly tested by the implementation
      # Rails.cache.fetch with race_condition_ttl ensures atomic reads/writes

      stub_request(:get, test_uri.to_s).to_timeout

      # Multiple concurrent failures should correctly increment counter
      threads = 3.times.map do
        Thread.new do
          HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil
        end
      end

      threads.each(&:join)

      # All failures should be recorded
      expect(HttpClient.circuit_state(circuit_name)[:failures]).to eq(3)
    end
  end

  describe '.circuit_state' do
    it 'returns nil for non-existent circuit' do
      expect(HttpClient.circuit_state('nonexistent')).to be_nil
    end

    it 'returns circuit state with failures, open status, and timestamps' do
      stub_request(:get, test_uri.to_s).to_timeout
      3.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      state = HttpClient.circuit_state(circuit_name)
      expect(state[:failures]).to eq(3)
      expect(state[:first_failure_at]).to be_a(Time)
      expect(state[:open]).to be_falsey
    end

    it 'returns state when circuit is open' do
      stub_request(:get, test_uri.to_s).to_timeout
      5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      state = HttpClient.circuit_state(circuit_name)
      expect(state[:open]).to be true
      expect(state[:open_until]).to be_a(Time)
      expect(state[:open_until]).to be > Time.current
    end
  end

  describe '.reset_circuit!' do
    it 'manually resets circuit state' do
      stub_request(:get, test_uri.to_s).to_timeout
      5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      # Circuit is open
      expect(HttpClient.circuit_state(circuit_name)[:open]).to be true

      # Manually reset
      HttpClient.reset_circuit!(circuit_name)

      # Circuit state should be cleared
      expect(HttpClient.circuit_state(circuit_name)).to be_nil

      # Next request should go through
      stub_request(:get, test_uri.to_s).to_return(status: 200)
      response = HttpClient.get(test_uri, circuit_name: circuit_name)
      expect(response.code).to eq('200')
    end

    it 'logs circuit reset' do
      allow(Rails.logger).to receive(:info)

      HttpClient.reset_circuit!(circuit_name)

      expect(Rails.logger).to have_received(:info).with(
        /Circuit #{circuit_name} manually reset/
      )
    end
  end

  describe 'logging' do
    it 'logs when circuit opens' do
      allow(Rails.logger).to receive(:warn)

      stub_request(:get, test_uri.to_s).to_timeout
      5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      expect(Rails.logger).to have_received(:warn).with(
        /Circuit #{circuit_name} opened after 5 failures/
      )
    end

    it 'logs when circuit closes after cool-off' do
      allow(Rails.logger).to receive(:info)

      stub_request(:get, test_uri.to_s).to_timeout
      5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      travel 61.seconds do
        stub_request(:get, test_uri.to_s).to_return(status: 200)
        HttpClient.get(test_uri, circuit_name: circuit_name)

        expect(Rails.logger).to have_received(:info).with(
          /Circuit #{circuit_name} closed after cool-off period/
        )
      end
    end
  end

  describe 'error handling' do
    it 'raises TimeoutError for Net::OpenTimeout' do
      stub_request(:get, test_uri.to_s).to_raise(Net::OpenTimeout)

      expect {
        HttpClient.get(test_uri)
      }.to raise_error(HttpClient::TimeoutError)
    end

    it 'raises TimeoutError for Net::ReadTimeout' do
      stub_request(:get, test_uri.to_s).to_raise(Net::ReadTimeout)

      expect {
        HttpClient.get(test_uri)
      }.to raise_error(HttpClient::TimeoutError)
    end

    it 'does not wrap other errors' do
      stub_request(:get, test_uri.to_s).to_raise(SocketError)

      expect {
        HttpClient.get(test_uri)
      }.to raise_error(SocketError)
    end
  end

  describe 'use cases' do
    it 'handles intermittent failures correctly' do
      stub_request(:get, test_uri.to_s).to_timeout.times(2).then.to_return(status: 200)

      # Fail twice
      2.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      # Succeed once
      response = HttpClient.get(test_uri, circuit_name: circuit_name)
      expect(response.code).to eq('200')

      # Failure count should be reset
      expect(HttpClient.circuit_state(circuit_name)).to be_nil

      # Can continue making requests
      stub_request(:get, test_uri.to_s).to_return(status: 200)
      response = HttpClient.get(test_uri, circuit_name: circuit_name)
      expect(response.code).to eq('200')
    end

    it 'prevents wasting API credits during outage' do
      stub_request(:get, test_uri.to_s).to_timeout

      # Make 5 requests (opens circuit)
      5.times { HttpClient.get(test_uri, circuit_name: circuit_name) rescue nil }

      # Next 10 requests should short-circuit (no HTTP request made)
      10.times do
        expect {
          HttpClient.get(test_uri, circuit_name: circuit_name)
        }.to raise_error(HttpClient::CircuitOpenError)
      end

      # Only 5 HTTP requests were made, 10 were short-circuited
      # This saves API credits during outages
    end
  end
end
