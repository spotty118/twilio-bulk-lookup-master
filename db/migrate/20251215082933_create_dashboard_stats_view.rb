# frozen_string_literal: true

class CreateDashboardStatsView < ActiveRecord::Migration[7.2]
  def up
    # Create materialized view for dashboard statistics
    # This pre-aggregates contact counts and metrics for faster dashboard loading
    execute <<-SQL
      CREATE MATERIALIZED VIEW dashboard_stats AS
      SELECT
        -- Status counts
        COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE status = 'processing') as processing_count,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
        COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
      #{'  '}
        -- Phone validation stats
        COUNT(*) FILTER (WHERE phone_valid = true) as valid_numbers_count,
        COUNT(*) FILTER (WHERE phone_valid = false) as invalid_numbers_count,
      #{'  '}
        -- Line type breakdown
        COUNT(*) FILTER (WHERE line_type = 'mobile') as mobile_count,
        COUNT(*) FILTER (WHERE line_type = 'landline') as landline_count,
        COUNT(*) FILTER (WHERE line_type = 'voip') as voip_count,
      #{'  '}
        -- Business intelligence
        COUNT(*) FILTER (WHERE is_business = true) as business_count,
        COUNT(*) FILTER (WHERE business_enriched = true) as business_enriched_count,
      #{'  '}
        -- Email verification
        COUNT(*) FILTER (WHERE email IS NOT NULL) as has_email_count,
        COUNT(*) FILTER (WHERE email_verified = true) as verified_email_count,
        COUNT(*) FILTER (WHERE email_enriched = true) as email_enriched_count,
      #{'  '}
        -- Address enrichment
        COUNT(*) FILTER (WHERE address_enriched = true) as address_enriched_count,
      #{'  '}
        -- Verizon coverage
        COUNT(*) FILTER (WHERE verizon_5g_home_available = true) as verizon_5g_available_count,
        COUNT(*) FILTER (WHERE verizon_lte_home_available = true) as verizon_lte_available_count,
        COUNT(*) FILTER (WHERE verizon_coverage_checked = true) as verizon_checked_count,
      #{'  '}
        -- Trust Hub
        COUNT(*) FILTER (WHERE trust_hub_verified = true) as trust_hub_verified_count,
        COUNT(*) FILTER (WHERE trust_hub_enriched = true) as trust_hub_enriched_count,
      #{'  '}
        -- SMS Pumping Risk
        COUNT(*) FILTER (WHERE sms_pumping_risk_level = 'low') as low_risk_count,
        COUNT(*) FILTER (WHERE sms_pumping_risk_level = 'medium') as medium_risk_count,
        COUNT(*) FILTER (WHERE sms_pumping_risk_level = 'high') as high_risk_count,
      #{'  '}
        -- Duplicates
        COUNT(*) FILTER (WHERE is_duplicate = true) as duplicate_count,
      #{'  '}
        -- Quality metrics
        AVG(data_quality_score) as avg_quality_score,
        AVG(completeness_percentage) as avg_completeness,
      #{'  '}
        -- CRM sync stats
        COUNT(*) FILTER (WHERE salesforce_id IS NOT NULL) as salesforce_synced_count,
        COUNT(*) FILTER (WHERE hubspot_id IS NOT NULL) as hubspot_synced_count,
        COUNT(*) FILTER (WHERE pipedrive_id IS NOT NULL) as pipedrive_synced_count,
      #{'  '}
        -- Engagement stats
        COUNT(*) FILTER (WHERE sms_sent_count > 0) as contacted_via_sms_count,
        COUNT(*) FILTER (WHERE voice_calls_count > 0) as contacted_via_voice_count,
        COUNT(*) FILTER (WHERE sms_opt_out = true) as sms_opt_out_count,
      #{'  '}
        -- Total count
        COUNT(*) as total_contacts,
      #{'  '}
        -- Last updated timestamp
        NOW() as updated_at
      FROM contacts;
    SQL

    # Create unique index for concurrent refresh
    execute <<-SQL
      CREATE UNIQUE INDEX dashboard_stats_updated_at_idx ON dashboard_stats (updated_at);
    SQL

    # Refresh is handled asynchronously after commits to avoid running inside write transactions.

    # Initial refresh
    execute 'REFRESH MATERIALIZED VIEW dashboard_stats;'
  end

  def down
    # Drop materialized view
    execute 'DROP MATERIALIZED VIEW IF EXISTS dashboard_stats;'
  end
end
