# frozen_string_literal: true

# DashboardStats - Read-only model for accessing the dashboard_stats materialized view
#
# This model provides fast access to pre-aggregated dashboard statistics.
# The underlying materialized view is refreshed asynchronously after contact changes.
#
# Usage:
#   stats = DashboardStats.current
#   puts stats.total_contacts
#   puts stats.pending_count
#   puts stats.avg_quality_score
#
class DashboardStats < ApplicationRecord
  self.table_name = 'dashboard_stats'
  self.primary_key = 'updated_at'

  # This is a read-only model - prevent writes
  def readonly?
    true
  end

  # Get the current (latest) stats
  # Since there's only one row, this returns that row
  def self.current
    first || new(total_contacts: 0)
  end

  # Manually refresh the materialized view.
  # Uses a non-concurrent refresh if already inside a transaction.
  def self.refresh!
    if connection.open_transactions.positive?
      connection.execute('REFRESH MATERIALIZED VIEW dashboard_stats;')
    else
      connection.execute('REFRESH MATERIALIZED VIEW CONCURRENTLY dashboard_stats;')
    end
  end

  # Get stats as a hash for easier use in controllers/views
  def to_stats_hash
    {
      # Status breakdown
      pending: pending_count,
      processing: processing_count,
      completed: completed_count,
      failed: failed_count,

      # Phone validation
      valid_numbers: valid_numbers_count,
      invalid_numbers: invalid_numbers_count,

      # Line types
      mobile: mobile_count,
      landline: landline_count,
      voip: voip_count,

      # Business
      businesses: business_count,
      business_enriched: business_enriched_count,

      # Email
      has_email: has_email_count,
      verified_emails: verified_email_count,
      email_enriched: email_enriched_count,

      # Address
      address_enriched: address_enriched_count,

      # Verizon
      verizon_5g_available: verizon_5g_available_count,
      verizon_lte_available: verizon_lte_available_count,
      verizon_checked: verizon_checked_count,

      # Trust Hub
      trust_hub_verified: trust_hub_verified_count,
      trust_hub_enriched: trust_hub_enriched_count,

      # Risk levels
      low_risk: low_risk_count,
      medium_risk: medium_risk_count,
      high_risk: high_risk_count,

      # Duplicates
      duplicates: duplicate_count,

      # Quality
      avg_quality_score: avg_quality_score&.round(2),
      avg_completeness: avg_completeness&.round(2),

      # CRM
      salesforce_synced: salesforce_synced_count,
      hubspot_synced: hubspot_synced_count,
      pipedrive_synced: pipedrive_synced_count,

      # Engagement
      contacted_via_sms: contacted_via_sms_count,
      contacted_via_voice: contacted_via_voice_count,
      sms_opt_outs: sms_opt_out_count,

      # Total
      total_contacts: total_contacts,

      # Metadata
      last_updated: updated_at
    }
  end

  # Calculate percentages for common metrics
  def enrichment_percentage
    return 0 if total_contacts.zero?

    ((business_enriched_count + email_enriched_count + address_enriched_count).to_f / (total_contacts * 3) * 100).round(1)
  end

  def completion_rate
    return 0 if total_contacts.zero?

    (completed_count.to_f / total_contacts * 100).round(1)
  end

  def business_percentage
    return 0 if total_contacts.zero?

    (business_count.to_f / total_contacts * 100).round(1)
  end

  def email_verification_rate
    return 0 if has_email_count.zero?

    (verified_email_count.to_f / has_email_count * 100).round(1)
  end
end
