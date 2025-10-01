class Contact < ApplicationRecord
  # Include concerns for better organization
  include ErrorTrackable
  include StatusManageable
  
  # Status workflow: pending -> processing -> completed/failed
  STATUSES = %w[pending processing completed failed].freeze
  
  # Validations
  validates :raw_phone_number, presence: true
  validates :raw_phone_number, 
            format: {
              with: /\A\+?[1-9]\d{1,14}\z/,
              message: "must be a valid phone number (E.164 format recommended, e.g., +14155551234)"
            },
            on: :create
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  
  # Scopes for filtering
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :not_processed, -> { where(status: ['pending', 'failed']) }
  
  # Define searchable attributes for ActiveAdmin/Ransack
  def self.ransackable_attributes(auth_object = nil)
    ["carrier_name", "created_at", "device_type", "error_code",
     "formatted_phone_number", "id", "mobile_country_code",
     "mobile_network_code", "raw_phone_number", "updated_at",
     "status", "lookup_performed_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end
  
  # Check if lookup has been performed successfully
  def lookup_completed?
    status == 'completed' && formatted_phone_number.present?
  end
  
  # Check if lookup should be retried
  def retriable?
    status == 'failed' && error_code.present? && !permanent_failure?
  end
  
  # Mark as processing
  def mark_processing!
    update(status: 'processing')
  end
  
  # Mark as completed with timestamp
  def mark_completed!
    update(status: 'completed', lookup_performed_at: Time.current)
  end
  
  # Mark as failed with error
  def mark_failed!(error_message)
    update(
      status: 'failed',
      error_code: error_message,
      lookup_performed_at: Time.current
    )
  end
  
  private
  
  # Determine if failure is permanent (don't retry)
  def permanent_failure?
    return false if error_code.blank?
    
    # Permanent failures: invalid number format, not found, etc.
    error_code.match?(/invalid|not found|does not exist/i)
  end
end
