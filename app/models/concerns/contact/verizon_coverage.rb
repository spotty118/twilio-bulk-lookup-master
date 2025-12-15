# frozen_string_literal: true

module Contact::VerizonCoverage
  extend ActiveSupport::Concern

  included do
    # Verizon coverage scopes
    scope :verizon_5g_available, -> { where(verizon_5g_home_available: true) }
    scope :verizon_lte_available, -> { where(verizon_lte_home_available: true) }
    scope :verizon_fios_available, -> { where(verizon_fios_available: true) }
    scope :verizon_home_internet_available, -> { where('verizon_5g_home_available = ? OR verizon_lte_home_available = ? OR verizon_fios_available = ?', true, true, true) }
    scope :verizon_coverage_checked, -> { where(verizon_coverage_checked: true) }
    scope :needs_verizon_check, -> { where(address_enriched: true, verizon_coverage_checked: false).where.not(consumer_address: nil) }
  end

  # Verizon coverage status
  def verizon_coverage_checked?
    verizon_coverage_checked == true
  end

  def verizon_home_internet_available?
    verizon_5g_home_available == true || verizon_lte_home_available == true || verizon_fios_available == true
  end

  # Available products list
  def verizon_products_available
    products = []
    products << 'Fios' if verizon_fios_available
    products << '5G Home' if verizon_5g_home_available
    products << 'LTE Home' if verizon_lte_home_available
    products.empty? ? 'None' : products.join(', ')
  end

  # Best available product (priority order)
  def verizon_best_product
    return 'Fios' if verizon_fios_available
    return '5G Home' if verizon_5g_home_available
    return 'LTE Home' if verizon_lte_home_available
    'Not Available'
  end

  # Speed display with upload/download
  def estimated_speed_display
    return nil unless estimated_download_speed.present?

    down = estimated_download_speed
    up = estimated_upload_speed.present? ? " / #{estimated_upload_speed}" : ''
    "#{down}#{up}"
  end
end
