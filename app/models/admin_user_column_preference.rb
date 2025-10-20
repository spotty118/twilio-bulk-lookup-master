class AdminUserColumnPreference < ApplicationRecord
  belongs_to :admin_user

  validates :resource_name, presence: true
  validate :preferences_must_be_valid_structure

  # Default column configuration for Contact resource
  DEFAULT_COLUMNS = [
    { field: 'id', visible: true, label: 'ID', position: 1 },
    { field: 'raw_phone_number', visible: true, label: 'Phone Number', position: 2 },
    { field: 'formatted_phone_number', visible: true, label: 'Formatted', position: 3 },
    { field: 'status', visible: true, label: 'Status', position: 4 },
    { field: 'carrier_name', visible: true, label: 'Carrier', position: 5 },
    { field: 'device_type', visible: true, label: 'Type', position: 6 },
    { field: 'sms_pumping_risk_level', visible: true, label: 'Fraud Risk', position: 7 },
    { field: 'valid', visible: true, label: 'Valid', position: 8 },
    { field: 'business_name', visible: true, label: 'Business', position: 9 },
    { field: 'email', visible: true, label: 'Email', position: 10 },
    { field: 'data_quality_score', visible: true, label: 'Quality', position: 11 },
    { field: 'verizon_5g_probability', visible: false, label: 'Verizon 5G Probability', position: 12 },
    { field: 'verizon_lte_probability', visible: false, label: 'Verizon LTE Probability', position: 13 },
    { field: 'lookup_performed_at', visible: true, label: 'Processed At', position: 14 },
    { field: 'error_code', visible: true, label: 'Error', position: 15 }
  ].freeze

  # Find or initialize preferences for given user and resource
  def self.for_user_and_resource(admin_user, resource_name)
    pref = find_or_initialize_by(admin_user: admin_user, resource_name: resource_name)

    # Initialize with default configuration if new record
    if pref.new_record?
      pref.preferences = { 'columns' => DEFAULT_COLUMNS.map(&:stringify_keys) }
    else
      # Merge any new columns from defaults that user doesn't have yet
      pref.merge_new_default_columns
    end

    pref
  end

  # Returns array of column configuration hashes
  def column_config
    columns = preferences.dig('columns') || []

    # If empty, use defaults
    return DEFAULT_COLUMNS.map(&:dup) if columns.empty?

    # Convert string keys to symbols for easier access
    columns.map { |col| col.symbolize_keys }
  end

  # Updates preferences JSON with new column configuration
  def update_column_config(columns_array)
    # Validate structure
    return false unless valid_column_structure?(columns_array)

    # Convert to proper format
    formatted_columns = columns_array.map do |col|
      {
        'field' => col[:field] || col['field'],
        'visible' => to_boolean(col[:visible] || col['visible']),
        'label' => col[:label] || col['label'],
        'position' => (col[:position] || col['position']).to_i
      }
    end

    self.preferences = { 'columns' => formatted_columns }
    save
  end

  # Resets to default column configuration
  def reset_to_defaults!
    self.preferences = { 'columns' => DEFAULT_COLUMNS.map(&:stringify_keys) }
    save
  end

  # Merge new columns from defaults that user doesn't have yet
  def merge_new_default_columns
    current_fields = column_config.map { |c| c[:field] }
    default_fields = DEFAULT_COLUMNS.map { |c| c[:field] }

    new_fields = default_fields - current_fields

    if new_fields.any?
      current_columns = preferences['columns'] || []
      max_position = current_columns.map { |c| c['position'] }.max || 0

      new_fields.each_with_index do |field, index|
        default_col = DEFAULT_COLUMNS.find { |c| c[:field] == field }
        if default_col
          new_col = default_col.dup
          new_col[:position] = max_position + index + 1
          current_columns << new_col.stringify_keys
        end
      end

      self.preferences = { 'columns' => current_columns }
    end
  end

  private

  def preferences_must_be_valid_structure
    return if preferences.blank?

    unless preferences.is_a?(Hash)
      errors.add(:preferences, 'must be a hash')
      return
    end

    if preferences['columns'].present?
      unless preferences['columns'].is_a?(Array)
        errors.add(:preferences, 'columns must be an array')
      end
    end
  end

  def valid_column_structure?(columns_array)
    return false unless columns_array.is_a?(Array)

    columns_array.all? do |col|
      col.is_a?(Hash) &&
        (col[:field] || col['field']).present? &&
        (col[:label] || col['label']).present?
    end
  end

  def to_boolean(value)
    return true if value == true || value == 'true' || value == '1' || value == 1
    return false if value == false || value == 'false' || value == '0' || value == 0
    false
  end
end
