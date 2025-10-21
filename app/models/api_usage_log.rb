class ApiUsageLog < ApplicationRecord
  belongs_to :contact, optional: true

  # Validations
  validates :provider, :service, :requested_at, presence: true
  validates :status, inclusion: { in: %w[success failed rate_limited error timeout] }, allow_nil: true

  # Scopes
  scope :successful, -> { where(status: 'success') }
  scope :failed, -> { where(status: ['failed', 'error', 'timeout']) }
  scope :rate_limited, -> { where(status: 'rate_limited') }
  scope :recent, -> { where('requested_at >= ?', 24.hours.ago) }
  scope :today, -> { where('requested_at >= ?', Time.current.beginning_of_day) }
  scope :this_month, -> { where('requested_at >= ?', Time.current.beginning_of_month) }

  # Provider scopes
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :twilio, -> { where(provider: 'twilio') }
  scope :clearbit, -> { where(provider: 'clearbit') }
  scope :hunter, -> { where(provider: 'hunter') }
  scope :zerobounce, -> { where(provider: 'zerobounce') }
  scope :google_places, -> { where(provider: 'google_places') }
  scope :google_geocoding, -> { where(provider: 'google_geocoding') }
  scope :openai, -> { where(provider: 'openai') }
  scope :anthropic, -> { where(provider: 'anthropic') }
  scope :google_ai, -> { where(provider: 'google_ai') }

  # Cost analysis helpers
  def self.total_cost(start_date: nil, end_date: nil)
    scope = all
    scope = scope.where('requested_at >= ?', start_date) if start_date
    scope = scope.where('requested_at <= ?', end_date) if end_date
    scope.sum(:cost)
  end

  def self.total_cost_by_provider(start_date: nil, end_date: nil)
    scope = all
    scope = scope.where('requested_at >= ?', start_date) if start_date
    scope = scope.where('requested_at <= ?', end_date) if end_date
    scope.group(:provider).sum(:cost)
  end

  def self.usage_stats(start_date: nil, end_date: nil)
    scope = all
    scope = scope.where('requested_at >= ?', start_date) if start_date
    scope = scope.where('requested_at <= ?', end_date) if end_date

    {
      total_requests: scope.count,
      successful_requests: scope.successful.count,
      failed_requests: scope.failed.count,
      total_cost: scope.sum(:cost),
      average_response_time: scope.average(:response_time_ms)&.to_f&.round(2),
      by_provider: scope.group(:provider).count,
      cost_by_provider: scope.group(:provider).sum(:cost)
    }
  end

  # Calculate cost based on provider and service
  def self.calculate_cost(provider, service, credits_used = 1)
    # Cost matrix (in USD)
    costs = {
      'twilio' => {
        'lookup_basic' => 0.005,
        'lookup_line_type' => 0.01,
        'lookup_caller_name' => 0.01,
        'lookup_sms_pumping' => 0.01,
        'lookup_sim_swap' => 0.01,
        'sms_send' => 0.0079,
        'voice_call' => 0.0140
      },
      'clearbit' => {
        'enrichment' => 0.10
      },
      'hunter' => {
        'email_search' => 0.05,
        'email_verify' => 0.01
      },
      'zerobounce' => {
        'email_verify' => 0.008
      },
      'google_places' => {
        'search' => 0.017,
        'details' => 0.017
      },
      'google_geocoding' => {
        'geocode' => 0.005
      },
      'openai' => {
        'gpt-4' => 0.03,
        'gpt-4o-mini' => 0.0015
      },
      'anthropic' => {
        'claude-3-5-sonnet' => 0.003,
        'claude-3-haiku' => 0.00025
      },
      'google_ai' => {
        'gemini-flash' => 0.000075,
        'gemini-pro' => 0.00125
      },
      'whitepages' => {
        'phone_lookup' => 0.05
      },
      'yelp' => {
        'search' => 0.0 # Free tier
      }
    }

    cost_per_unit = costs.dig(provider, service) || 0.0
    cost_per_unit * credits_used
  end

  # Log an API call
  def self.log_api_call(params)
    create!(
      contact_id: params[:contact_id],
      provider: params[:provider],
      service: params[:service],
      endpoint: params[:endpoint],
      cost: params[:cost] || calculate_cost(params[:provider], params[:service], params[:credits_used] || 1),
      currency: params[:currency] || 'USD',
      credits_used: params[:credits_used] || 1,
      request_id: params[:request_id],
      status: params[:status],
      response_time_ms: params[:response_time_ms],
      http_status_code: params[:http_status_code],
      request_params: params[:request_params] || {},
      response_data: params[:response_data] || {},
      error_message: params[:error_message],
      requested_at: params[:requested_at] || Time.current
    )
  rescue => e
    Rails.logger.error "Failed to log API usage: #{e.message}"
    nil
  end

  # Class method to get ransackable attributes
  def self.ransackable_attributes(auth_object = nil)
    ["provider", "service", "status", "cost", "credits_used", "requested_at",
     "created_at", "updated_at", "contact_id", "http_status_code", "response_time_ms"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["contact"]
  end
end
