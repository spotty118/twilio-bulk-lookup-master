# frozen_string_literal: true

class Contact < ApplicationRecord
  # Include existing concerns
  include ErrorTrackable
  include StatusManageable

  # Include extracted domain concerns
  include Contact::BusinessIntelligence
  include Contact::PhoneIntelligence
  include Contact::EnrichmentTracking
  include Contact::VerizonCoverage
  include Contact::TrustHubVerification
  include Contact::DuplicateDetection

  # Associations - Critical for data integrity (prevents orphaned records)
  # api_usage_logs: Cascade delete with contact (logs belong to contact lifecycle)
  # webhooks: Nullify to preserve audit trail (webhooks may have independent value)
  has_many :api_usage_logs, dependent: :destroy
  has_many :webhooks, dependent: :nullify

  # Thread-local flag to skip expensive callbacks during bulk operations
  # Usage: Contact.skip_bulk_callbacks { Contact.insert_all(records) }
  thread_mattr_accessor :skip_callbacks_for_bulk_import
  self.skip_callbacks_for_bulk_import = false

  # Broadcast changes for real-time dashboard updates
  # Use throttled broadcasting to prevent overwhelming Redis during bulk operations
  after_update_commit :broadcast_refresh_throttled, unless: -> { Contact.skip_callbacks_for_bulk_import }
  after_create_commit :broadcast_refresh_throttled, unless: -> { Contact.skip_callbacks_for_bulk_import }
  after_destroy_commit :broadcast_refresh_throttled

  # Broadcast individual contact updates for live table refresh
  after_update_commit :broadcast_contact_update, unless: -> { Contact.skip_callbacks_for_bulk_import }

  # Status workflow: pending -> processing -> completed/failed
  STATUSES = %w[pending processing completed failed].freeze

  # Validations
  validates :raw_phone_number, presence: true
  validates :raw_phone_number,
            format: {
              with: /\A\+?[1-9]\d{1,14}\z/,
              message: 'must be a valid phone number (E.164 format recommended, e.g., +14155551234)'
            },
            if: ->(contact) { contact.raw_phone_number_changed? && contact.raw_phone_number.present? }
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true, if: -> { email.present? }
  validates :data_quality_score, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validates :completeness_percentage, numericality: { only_integer: true, in: 0..100 }, allow_nil: true
  validates :country_code, length: { is: 2 }, allow_blank: true

  # Callbacks
  before_save :reset_formatted_phone_when_changed, if: lambda {
    raw_phone_number_changed? && !formatted_phone_number_changed?
  }

  def reset_formatted_phone_when_changed
    self.formatted_phone_number = nil
  end

  # Base status scopes (core functionality, not domain-specific)
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :not_processed, -> { where(status: %w[pending failed]) }

  # Line status scopes (Real Phone Validation)
  scope :connected, -> { where(rpv_status: 'connected') }
  scope :disconnected, -> { where(rpv_status: 'disconnected') }

  # Porting status scopes (IceHook Scout)
  scope :ported, -> { where(scout_ported: true) }
  scope :not_ported, -> { where(scout_ported: false) }

  # Define searchable attributes for ActiveAdmin/Ransack
  def self.ransackable_attributes(_auth_object = nil)
    %w[carrier_name created_at device_type error_code
       formatted_phone_number id mobile_country_code
       mobile_network_code raw_phone_number updated_at
       status lookup_performed_at phone_valid country_code
       calling_country_code line_type line_type_confidence
       caller_name caller_type sms_pumping_risk_score
       sms_pumping_risk_level sms_pumping_carrier_risk_category
       sms_pumping_number_blocked validation_errors
       sim_swap_last_sim_swap_date sim_swap_swapped_period sim_swap_swapped_in_period
       reassigned_number_is_reassigned reassigned_number_last_verified_date
       is_business business_name business_type business_category
       business_industry business_employee_count business_employee_range
       business_annual_revenue business_revenue_range business_city
       business_state business_country business_website
       business_enriched business_enrichment_provider
       email email_verified email_score email_status
       first_name last_name full_name position department seniority
       linkedin_url email_enriched is_duplicate duplicate_of_id
       data_quality_score completeness_percentage
       consumer_address consumer_city consumer_state consumer_postal_code
       consumer_country address_type address_verified address_enriched
       address_confidence_score verizon_5g_home_available verizon_lte_home_available
       verizon_fios_available verizon_coverage_checked estimated_download_speed
       trust_hub_verified trust_hub_status trust_hub_business_sid trust_hub_enriched
       trust_hub_verification_score trust_hub_regulatory_status trust_hub_business_name
       api_cost api_response_time_ms rpv_status rpv_error_text rpv_iscell rpv_cnam rpv_carrier
       scout_ported scout_location_routing_number scout_operating_company_name scout_operating_company_type]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  # Bulk operation helper - skips callbacks for performance
  # Example: Contact.with_callbacks_skipped { Contact.insert_all(records) }
  def self.with_callbacks_skipped
    original_value = skip_callbacks_for_bulk_import
    self.skip_callbacks_for_bulk_import = true
    yield
  ensure
    self.skip_callbacks_for_bulk_import = original_value
  end

  # Batch recalculate fingerprints and quality scores for contacts
  # Useful after bulk imports that skipped callbacks
  def self.recalculate_bulk_metrics(contact_ids)
    where(id: contact_ids).find_each do |contact|
      contact.update_fingerprints!
      contact.calculate_quality_score!
    rescue StandardError => e
      # Don't let individual failures stop the entire batch
      ErrorTrackingService.capture(e, context: { contact_id: contact.id, action: 'recalculate_bulk_metrics' })
    end
  end

  # Check if lookup has been performed successfully
  def lookup_completed?
    status == 'completed' && formatted_phone_number.present?
  end

  # Check if lookup should be retried
  # A failed contact is retriable unless it has a permanent failure indication
  def retriable?
    status == 'failed' && !permanent_failure?
  end

  # Mark as processing
  def mark_processing!
    update!(status: 'processing')
  end

  # Mark as completed with timestamp
  def mark_completed!
    calculate_api_cost
    update!(status: 'completed', lookup_performed_at: Time.current)
  end

  # Mark as failed with error message
  def mark_failed!(error_message)
    update!(status: 'failed', error_code: error_message)
  end

  # Reset contact for fresh reprocessing
  #
  # ASSUMPTION CONTRACT (PHANTOM G1):
  # ASSUMES: Contact is persisted, status is 'completed' or 'failed'
  # GUARANTEES: Status becomes 'pending', lookup data cleared, returns boolean
  #
  # @return [Boolean] true if reset successful, false if cannot reset (e.g., processing)
  # @raise [ActiveRecord::RecordInvalid] if validation fails
  def reset_for_reprocessing!
    # Guard: Don't interrupt active processing
    return false if status == 'processing'

    update!(
      status: 'pending',
      error_code: nil,
      formatted_phone_number: nil,
      phone_valid: nil,
      lookup_performed_at: nil,
      # Reset enrichment tracking
      business_enriched: false,
      email_enriched: false,
      address_enriched: false,
      verizon_coverage_checked: false,
      trust_hub_enriched: false
    )

    true
  end

  # Determine if failure is permanent (don't retry)
  def permanent_failure?
    return false if error_code.blank?

    # Permanent failures: invalid number format, not found, etc.
    error_code.match?(/invalid|not found|does not exist/i)
  end

  def broadcast_refresh_throttled
    # Throttle broadcasts to once per second to prevent overwhelming Redis
    # during bulk operations (e.g., processing 1000s of contacts)
    throttle_key = 'contact_broadcast_throttle'

    # Check if we've broadcast recently (within last second)
    last_broadcast = Rails.cache.read(throttle_key)
    return if last_broadcast && last_broadcast > 1.second.ago

    # Set throttle timestamp
    Rails.cache.write(throttle_key, Time.current, expires_in: 2.seconds)

    # Schedule the actual broadcast slightly delayed to batch multiple changes
    # This uses ActiveJob to defer the broadcast, allowing multiple rapid changes
    # to be coalesced into a single broadcast
    DashboardBroadcastJob.perform_later
  rescue StandardError => e
    # Don't let broadcast failures affect contact operations
    Rails.logger.warn("Dashboard broadcast failed: #{e.message}")
  end

  # Broadcast individual contact update for live table refresh
  def broadcast_contact_update
    ContactBroadcastJob.perform_later(id)
  rescue StandardError => e
    Rails.logger.warn("Contact broadcast failed for #{id}: #{e.message}")
  end

  # Cost Tracking Constants
  LOOKUP_COST_PER_REQUEST = 0.005 # $0.005 per lookup

  # Calculate and store API cost
  def calculate_api_cost
    self.api_cost = LOOKUP_COST_PER_REQUEST
  end

  def broadcast_refresh
    # Direct broadcast without throttling (for backwards compatibility)
    broadcast_replace_to(
      'dashboard_stats',
      target: 'dashboard_stats',
      partial: 'admin/dashboard/stats',
      locals: { refresh: true }
    )
  end
end
