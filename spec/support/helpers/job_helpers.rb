# frozen_string_literal: true

# Job testing helpers for RSpec
# This file provides utilities for testing Sidekiq background jobs
#
# Usage:
#   include JobHelpers
#   
#   # Simulate concurrent job execution
#   results = run_concurrent_jobs(5) { LookupRequestJob.new.perform(contact.id) }
#   
#   # Track API calls during job execution
#   api_calls = track_api_calls { LookupRequestJob.new.perform(contact.id) }

module JobHelpers
  # Run a block concurrently in multiple threads
  # Returns an array of results or exceptions from each thread
  #
  # @param count [Integer] Number of concurrent threads to spawn
  # @param block [Proc] The block to execute in each thread
  # @return [Array] Results from each thread execution
  def run_concurrent_jobs(count, &block)
    threads = count.times.map do
      Thread.new do
        Thread.current.report_on_exception = false
        begin
          { success: true, result: block.call }
        rescue StandardError => e
          { success: false, error: e }
        end
      end
    end

    threads.map(&:value)
  end

  # Count how many threads successfully executed (didn't raise)
  #
  # @param results [Array] Results from run_concurrent_jobs
  # @return [Integer] Number of successful executions
  def successful_executions(results)
    results.count { |r| r[:success] }
  end

  # Count how many threads raised an exception
  #
  # @param results [Array] Results from run_concurrent_jobs
  # @return [Integer] Number of failed executions
  def failed_executions(results)
    results.count { |r| !r[:success] }
  end

  # Track API calls made during block execution
  # Useful for verifying idempotency (only one API call made)
  #
  # @param block [Proc] The block to execute
  # @return [Hash] Contains :result and :api_call_count
  def track_api_calls(&block)
    call_count = 0
    
    # Track Twilio client instantiation as proxy for API calls
    original_new = Twilio::REST::Client.method(:new)
    allow(Twilio::REST::Client).to receive(:new) do |*args|
      call_count += 1
      original_new.call(*args)
    end

    result = block.call

    { result: result, api_call_count: call_count }
  end

  # Create a mock Twilio lookup result
  #
  # @param overrides [Hash] Attributes to override in the mock
  # @return [Double] A mock lookup result object
  def mock_twilio_lookup_result(overrides = {})
    defaults = {
      phone_number: '+14155551234',
      valid: true,
      validation_errors: [],
      country_code: 'US',
      calling_country_code: '1',
      national_format: '(415) 555-1234',
      line_type_intelligence: {
        'type' => 'mobile',
        'confidence' => 95,
        'carrier_name' => 'AT&T',
        'mobile_network_code' => '410',
        'mobile_country_code' => '310'
      },
      caller_name: {
        'caller_name' => 'JOHN DOE',
        'caller_type' => 'CONSUMER'
      },
      sms_pumping_risk: {
        'sms_pumping_risk_score' => 15,
        'carrier_risk_category' => 'low',
        'number_blocked' => false
      }
    }.merge(overrides)

    double('LookupResult', defaults)
  end

  # Setup a complete Twilio client mock chain
  # Returns the mock phone_numbers object for further stubbing
  #
  # @param lookup_result [Double] The mock result to return from fetch
  # @return [Double] The mock phone_numbers object
  def setup_twilio_mock(lookup_result = nil)
    lookup_result ||= mock_twilio_lookup_result

    mock_client = double('TwilioClient')
    mock_lookups = double('Lookups')
    mock_v2 = double('V2')
    mock_phone_numbers = double('PhoneNumbers')

    allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:lookups).and_return(mock_lookups)
    allow(mock_lookups).to receive(:v2).and_return(mock_v2)
    allow(mock_v2).to receive(:phone_numbers).and_return(mock_phone_numbers)
    allow(mock_phone_numbers).to receive(:fetch).and_return(lookup_result)

    mock_phone_numbers
  end

  # Create a Twilio REST error for testing error handling
  #
  # @param code [Integer] Twilio error code
  # @param message [String] Error message
  # @param status_code [Integer] HTTP status code
  # @return [Twilio::REST::RestError] A Twilio error object
  def twilio_error(code:, message: 'Twilio error', status_code: 400)
    error = Twilio::REST::RestError.new(message, double(status_code: status_code, body: {}))
    allow(error).to receive(:code).and_return(code)
    error
  end

  # Wait for all Sidekiq jobs to complete (for integration tests)
  # Note: Only works with Sidekiq::Testing.inline! mode
  #
  # @param timeout [Integer] Maximum seconds to wait
  def drain_all_jobs(timeout: 30)
    Timeout.timeout(timeout) do
      loop do
        break if Sidekiq::Worker.jobs.empty?
        Sidekiq::Worker.drain_all
      end
    end
  end

  # Assert that a job was enqueued with specific arguments
  #
  # @param job_class [Class] The job class to check
  # @param args [Array] Expected arguments
  # @return [Boolean] Whether the job was enqueued
  def job_enqueued?(job_class, *args)
    job_class.jobs.any? do |job|
      job['args'] == args
    end
  end

  # Get the count of enqueued jobs for a specific class
  #
  # @param job_class [Class] The job class to count
  # @return [Integer] Number of enqueued jobs
  def enqueued_job_count(job_class)
    job_class.jobs.size
  end

  # Clear all enqueued jobs for a specific class
  #
  # @param job_class [Class] The job class to clear
  def clear_jobs(job_class)
    job_class.jobs.clear
  end
end

RSpec.configure do |config|
  config.include JobHelpers, type: :job
  config.include JobHelpers, type: :integration
end
