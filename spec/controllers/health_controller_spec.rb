# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe 'GET #show' do
    it 'returns 200 OK' do
      get :show
      expect(response).to have_http_status(:ok)
    end

    it 'returns JSON with status ok' do
      get :show
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ok')
    end

    it 'includes timestamp' do
      get :show
      json = JSON.parse(response.body)
      expect(json['timestamp']).to be_present
    end

    it 'includes version' do
      get :show
      json = JSON.parse(response.body)
      expect(json['version']).to eq(HttpClient::APP_VERSION)
    end
  end

  describe 'GET #ready' do
    context 'when all dependencies are healthy' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        allow_any_instance_of(Redis).to receive(:ping).and_return('PONG')
        allow_any_instance_of(Redis).to receive(:info).and_return({
                                                                    'connected_clients' => '5',
                                                                    'used_memory_human' => '1M',
                                                                    'uptime_in_seconds' => '86400'
                                                                  })
        allow_any_instance_of(Redis).to receive(:close)
      end

      it 'returns 200 OK' do
        get :ready
        expect(response).to have_http_status(:ok)
      end

      it 'returns status ok' do
        get :ready
        json = JSON.parse(response.body)
        expect(json['status']).to eq('ok')
      end

      it 'includes database and redis checks' do
        get :ready
        json = JSON.parse(response.body)
        expect(json['checks']).to have_key('database')
        expect(json['checks']).to have_key('redis')
      end
    end

    context 'when database is down' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute)
          .and_raise(ActiveRecord::ConnectionNotEstablished)
        allow_any_instance_of(Redis).to receive(:ping).and_return('PONG')
        allow_any_instance_of(Redis).to receive(:info).and_return({})
        allow_any_instance_of(Redis).to receive(:close)
      end

      it 'returns 503 Service Unavailable' do
        get :ready
        expect(response).to have_http_status(:service_unavailable)
      end

      it 'returns status error' do
        get :ready
        json = JSON.parse(response.body)
        expect(json['status']).to eq('error')
      end
    end
  end

  describe 'GET #detailed' do
    before do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
      allow_any_instance_of(Redis).to receive(:ping).and_return('PONG')
      allow_any_instance_of(Redis).to receive(:info).and_return({
                                                                  'connected_clients' => '5',
                                                                  'used_memory_human' => '1M',
                                                                  'uptime_in_seconds' => '86400'
                                                                })
      allow_any_instance_of(Redis).to receive(:close)

      # Mock Sidekiq
      stats = double(
        processes_size: 2,
        workers_size: 1,
        scheduled_size: 0,
        retry_size: 0,
        dead_size: 0,
        failed: 10,
        processed: 1000,
        enqueued: 5
      )
      allow(Sidekiq::Stats).to receive(:new).and_return(stats)
      allow(Sidekiq::Queue).to receive(:new).and_return(double(size: 5))
    end

    it 'returns 200 OK' do
      get :detailed
      expect(response).to have_http_status(:ok)
    end

    it 'includes environment info' do
      get :detailed
      json = JSON.parse(response.body)
      expect(json['environment']).to eq(Rails.env)
      expect(json['ruby_version']).to eq(RUBY_VERSION)
    end

    it 'includes memory usage' do
      get :detailed
      json = JSON.parse(response.body)
      expect(json['memory']).to have_key('rss_mb')
    end

    it 'includes all check types' do
      get :detailed
      json = JSON.parse(response.body)
      expect(json['checks'].keys).to include(
        'database', 'redis', 'sidekiq', 'twilio_credentials', 'circuit_breakers'
      )
    end
  end

  describe 'GET #queue' do
    before do
      allow(Contact).to receive(:count).and_return(100)
      allow(Contact).to receive(:pending).and_return(double(count: 10))
      allow(Contact).to receive(:processing).and_return(double(count: 5))
      allow(Contact).to receive(:completed).and_return(double(count: 80))
      allow(Contact).to receive(:failed).and_return(double(count: 5))

      stats = double(
        processed: 1000,
        failed: 10,
        enqueued: 5,
        scheduled_size: 0,
        retry_size: 2,
        dead_size: 1,
        processes_size: 2,
        workers_size: 1
      )
      allow(Sidekiq::Stats).to receive(:new).and_return(stats)
    end

    it 'returns contact statistics' do
      get :queue
      json = JSON.parse(response.body)
      expect(json['contacts']['total']).to eq(100)
      expect(json['contacts']['pending']).to eq(10)
      expect(json['contacts']['completed']).to eq(80)
    end

    it 'returns sidekiq statistics' do
      get :queue
      json = JSON.parse(response.body)
      expect(json['sidekiq']['processed']).to eq(1000)
      expect(json['sidekiq']['workers']).to eq(1)
    end
  end
end
