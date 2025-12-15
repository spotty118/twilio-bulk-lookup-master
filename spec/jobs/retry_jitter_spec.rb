# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Job Retry Jitter Configuration', type: :job do
  # COGNITIVE HYPERCLUSTER TEST SUITE
  # Test Fix: Retry jitter prevents thundering herd problem
  # Coverage: 14 retry_on occurrences across 12 job classes
  # Edge Cases: Jitter range (0-29s), exponential backoff, attempt limits

  describe 'LookupRequestJob retry configuration' do
    it 'uses exponential backoff with jitter for Twilio errors' do
      # Verify wait time calculation includes jitter
      wait_proc = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:wait]

      # Test wait time for execution 1
      allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(15)
      wait_time_exec_1 = wait_proc.call(1)
      expect(wait_time_exec_1).to eq(1**4 + 15) # 1 + 15 = 16 seconds

      # Test wait time for execution 2
      allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(20)
      wait_time_exec_2 = wait_proc.call(2)
      expect(wait_time_exec_2).to eq(2**4 + 20) # 16 + 20 = 36 seconds

      # Test wait time for execution 3
      allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(5)
      wait_time_exec_3 = wait_proc.call(3)
      expect(wait_time_exec_3).to eq(3**4 + 5) # 81 + 5 = 86 seconds
    end

    it 'limits retries to 3 attempts' do
      attempts = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:attempts]
      expect(attempts).to eq(3)
    end

    it 'uses exponential backoff with jitter for network errors' do
      # Only test if Faraday is defined (conditional retry_on)
      skip 'Faraday not defined' unless defined?(Faraday::Error)

      wait_proc = LookupRequestJob.retry_on_options_for(Faraday::Error)[:wait]

      allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(10)
      wait_time = wait_proc.call(1)
      expect(wait_time).to eq(1**4 + 10) # 1 + 10 = 11 seconds
    end

    it 'adds random jitter between 0 and 29 seconds' do
      wait_proc = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:wait]

      # Collect 100 samples of jitter
      jitters = 100.times.map do
        wait_time = wait_proc.call(1)
        wait_time - (1**4) # Subtract base wait time to get jitter
      end

      # Verify jitter is within expected range
      expect(jitters.min).to be >= 0
      expect(jitters.max).to be < 30

      # Verify jitter is actually random (not always the same)
      expect(jitters.uniq.count).to be > 1
    end
  end

  describe 'BusinessEnrichmentJob retry configuration' do
    it 'uses exponential backoff with jitter' do
      wait_proc = BusinessEnrichmentJob.retry_on_options_for(StandardError)[:wait]

      allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(12)
      wait_time = wait_proc.call(1)
      expect(wait_time).to eq(1**4 + 12)
    end

    it 'limits retries to 2 attempts' do
      attempts = BusinessEnrichmentJob.retry_on_options_for(StandardError)[:attempts]
      expect(attempts).to eq(2)
    end
  end

  describe 'All jobs use consistent jitter pattern' do
    let(:job_classes) do
      [
        LookupRequestJob,
        BusinessEnrichmentJob,
        EmailEnrichmentJob,
        AddressEnrichmentJob,
        DuplicateDetectionJob,
        BusinessLookupJob,
        VerizonCoverageCheckJob,
        GeocodingJob,
        TrustHubEnrichmentJob,
        CrmSyncJob,
        WebhookProcessorJob,
        RecalculateContactMetricsJob
      ]
    end

    it 'all jobs use rand(30) for jitter' do
      job_classes.each do |job_class|
        # Get all retry_on configurations
        retry_configs = job_class.instance_variable_get(:@retry_on_options) || []

        # Skip if no retry configurations
        next if retry_configs.empty?

        retry_configs.each do |config|
          wait_proc = config[:wait]
          next unless wait_proc.is_a?(Proc)

          # Test that jitter is applied
          allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(15)
          wait_time = wait_proc.call(1)

          # Verify wait time includes jitter
          # Base exponential backoff: executions ** 4
          # Jitter: + rand(30)
          expect(wait_time).to eq(1**4 + 15),
            "#{job_class} should use (executions ** 4) + rand(30) pattern"
        end
      end
    end

    it 'prevents thundering herd with randomized delays' do
      # Simulate 10 concurrent job retries
      job_instances = 10.times.map { LookupRequestJob.new }
      wait_proc = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:wait]

      # Collect wait times for all jobs at execution 2
      wait_times = job_instances.map { wait_proc.call(2) }

      # Verify all wait times are different (jitter prevents synchronization)
      expect(wait_times.uniq.count).to be > 1,
        "Jitter should prevent all jobs from retrying at the exact same time"

      # Verify all wait times are within expected range
      # Base: 2**4 = 16, Jitter: 0-29
      expect(wait_times.min).to be >= 16
      expect(wait_times.max).to be < 16 + 30
    end
  end

  describe 'Edge cases' do
    it 'handles execution count 0 (should not happen but defensive)' do
      wait_proc = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:wait]

      allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(5)
      wait_time = wait_proc.call(0)
      expect(wait_time).to eq(0**4 + 5) # 0 + 5 = 5 seconds
    end

    it 'handles large execution counts without overflow' do
      wait_proc = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:wait]

      allow_any_instance_of(Kernel).to receive(:rand).with(30).and_return(10)
      wait_time = wait_proc.call(10)

      # 10**4 = 10,000 seconds = ~2.7 hours
      expect(wait_time).to eq(10_000 + 10)
      expect(wait_time).to be < 11_000 # Sanity check
    end

    it 'jitter is always non-negative' do
      wait_proc = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:wait]

      # rand(30) always returns 0-29
      1000.times do
        wait_time = wait_proc.call(1)
        expect(wait_time).to be >= 1**4 # At minimum, base wait time
      end
    end
  end

  describe 'Retry callbacks' do
    it 'LookupRequestJob marks contact as failed after exhausting retries' do
      contact = create(:contact, :processing)

      # Mock retry exhaustion callback
      callback = LookupRequestJob.retry_on_options_for(Twilio::REST::RestError)[:block]

      job = LookupRequestJob.new
      error = Twilio::REST::RestError.new('API error', double(status: 500, body: '{}'))

      callback.call(job, error, contact.id)

      expect(contact.reload.status).to eq('failed')
      expect(contact.error_code).to include('Twilio API error after retries')
    end

    it 'BusinessEnrichmentJob logs warning after exhausting retries' do
      contact = create(:contact, :completed)
      allow(Rails.logger).to receive(:warn)

      callback = BusinessEnrichmentJob.retry_on_options_for(StandardError)[:block]

      job = BusinessEnrichmentJob.new
      error = StandardError.new('Enrichment failed')

      callback.call(job, error, contact.id)

      expect(Rails.logger).to have_received(:warn).with(
        /Business enrichment failed for contact #{contact.id}/
      )
    end
  end
end
