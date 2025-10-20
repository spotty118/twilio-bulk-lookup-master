class AddVerizonCoverageToContacts < ActiveRecord::Migration[7.2]
  def change
    # Verizon home internet availability
    add_column :contacts, :verizon_5g_home_available, :boolean
    add_column :contacts, :verizon_lte_home_available, :boolean
    add_column :contacts, :verizon_fios_available, :boolean

    # Coverage details
    add_column :contacts, :verizon_coverage_checked, :boolean, default: false
    add_column :contacts, :verizon_coverage_checked_at, :datetime
    add_column :contacts, :verizon_coverage_data, :jsonb # Store raw coverage data

    # Signal strength and speed estimates
    add_column :contacts, :estimated_download_speed, :string # e.g., "300-940 Mbps"
    add_column :contacts, :estimated_upload_speed, :string

    # Indexes
    add_index :contacts, :verizon_5g_home_available
    add_index :contacts, :verizon_lte_home_available
    add_index :contacts, :verizon_coverage_checked
  end
end
