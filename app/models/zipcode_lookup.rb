class ZipcodeLookup < ApplicationRecord
  # ========================================
  # Constants
  # ========================================
  STATUSES = %w[pending processing completed failed].freeze

  # ========================================
  # Ransack Configuration (for ActiveAdmin filtering)
  # ========================================
  def self.ransackable_attributes(auth_object = nil)
    %w[zipcode status provider businesses_found businesses_imported businesses_updated businesses_skipped created_at updated_at lookup_started_at lookup_completed_at]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  # ========================================
  # Validations
  # ========================================
  validates :zipcode, presence: true, format: { with: /\A\d{5}\z/, message: "must be a 5-digit US zipcode" }
  validates :status, inclusion: { in: STATUSES }

  # ========================================
  # Scopes
  # ========================================
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }

  # ========================================
  # Callbacks
  # ========================================
  before_validation :normalize_zipcode

  # ========================================
  # Instance Methods
  # ========================================

  def mark_processing!
    update!(
      status: 'processing',
      lookup_started_at: Time.current
    )
  end

  def mark_completed!(stats = {})
    update!(
      status: 'completed',
      lookup_completed_at: Time.current,
      businesses_found: stats[:found] || 0,
      businesses_imported: stats[:imported] || 0,
      businesses_updated: stats[:updated] || 0,
      businesses_skipped: stats[:skipped] || 0
    )
  end

  def mark_failed!(error)
    update!(
      status: 'failed',
      lookup_completed_at: Time.current,
      error_message: error.to_s
    )
  end

  def duration
    return nil unless lookup_started_at && lookup_completed_at
    lookup_completed_at - lookup_started_at
  end

  def success_rate
    found = businesses_found.to_i
    return 0 if found.zero?

    imported = businesses_imported.to_i
    updated = businesses_updated.to_i
    ((imported + updated).to_f / found * 100).round(1)
  end

  def search_params_hash
    return {} unless search_params.present?
    JSON.parse(search_params)
  rescue JSON::ParserError
    {}
  end

  def search_params_hash=(hash)
    self.search_params = hash.to_json
  end

  private

  def normalize_zipcode
    self.zipcode = zipcode.to_s.strip if zipcode.present?
  end
end
