# frozen_string_literal: true

# Sprint 3: Add database CHECK constraints for data integrity
#
# Adds PostgreSQL CHECK constraints to enforce valid values at the database level,
# preventing invalid data from being inserted even if model validations are bypassed.
#
class AddDatabaseCheckConstraints < ActiveRecord::Migration[7.2]
  def up
    # Contact status constraint - must match model validation
    execute <<-SQL
      ALTER TABLE contacts#{' '}
      ADD CONSTRAINT check_contact_status#{' '}
      CHECK (status IN ('pending', 'processing', 'completed', 'failed'));
    SQL

    # SMS pumping risk level constraint
    execute <<-SQL
      ALTER TABLE contacts#{' '}
      ADD CONSTRAINT check_sms_pumping_risk_level#{' '}
      CHECK (sms_pumping_risk_level IS NULL OR sms_pumping_risk_level IN ('low', 'medium', 'high'));
    SQL

    # SMS pumping risk score range (0-100)
    execute <<-SQL
      ALTER TABLE contacts#{' '}
      ADD CONSTRAINT check_sms_pumping_risk_score_range#{' '}
      CHECK (sms_pumping_risk_score IS NULL OR (sms_pumping_risk_score >= 0 AND sms_pumping_risk_score <= 100));
    SQL

    # Data quality score range (0-100)
    execute <<-SQL
      ALTER TABLE contacts#{' '}
      ADD CONSTRAINT check_data_quality_score_range#{' '}
      CHECK (data_quality_score IS NULL OR (data_quality_score >= 0 AND data_quality_score <= 100));
    SQL

    # Completeness percentage range (0-100)
    execute <<-SQL
      ALTER TABLE contacts#{' '}
      ADD CONSTRAINT check_completeness_percentage_range#{' '}
      CHECK (completeness_percentage IS NULL OR (completeness_percentage >= 0 AND completeness_percentage <= 100));
    SQL

    # Duplicate confidence range (0-100)
    execute <<-SQL
      ALTER TABLE contacts#{' '}
      ADD CONSTRAINT check_duplicate_confidence_range#{' '}
      CHECK (duplicate_confidence IS NULL OR (duplicate_confidence >= 0 AND duplicate_confidence <= 100));
    SQL

    # Webhook status constraint
    execute <<-SQL
      ALTER TABLE webhooks#{' '}
      ADD CONSTRAINT check_webhook_status#{' '}
      CHECK (status IN ('pending', 'processing', 'processed', 'failed'));
    SQL

    # API usage log status constraint
    execute <<-SQL
      ALTER TABLE api_usage_logs#{' '}
      ADD CONSTRAINT check_api_usage_log_status#{' '}
      CHECK (status IS NULL OR status IN ('success', 'failed', 'rate_limited', 'error', 'timeout'));
    SQL

    # Zipcode lookup status constraint
    execute <<-SQL
      ALTER TABLE zipcode_lookups#{' '}
      ADD CONSTRAINT check_zipcode_lookup_status#{' '}
      CHECK (status IN ('pending', 'processing', 'completed', 'failed'));
    SQL
  end

  def down
    execute 'ALTER TABLE contacts DROP CONSTRAINT IF EXISTS check_contact_status;'
    execute 'ALTER TABLE contacts DROP CONSTRAINT IF EXISTS check_sms_pumping_risk_level;'
    execute 'ALTER TABLE contacts DROP CONSTRAINT IF EXISTS check_sms_pumping_risk_score_range;'
    execute 'ALTER TABLE contacts DROP CONSTRAINT IF EXISTS check_data_quality_score_range;'
    execute 'ALTER TABLE contacts DROP CONSTRAINT IF EXISTS check_completeness_percentage_range;'
    execute 'ALTER TABLE contacts DROP CONSTRAINT IF EXISTS check_duplicate_confidence_range;'
    execute 'ALTER TABLE webhooks DROP CONSTRAINT IF EXISTS check_webhook_status;'
    execute 'ALTER TABLE api_usage_logs DROP CONSTRAINT IF EXISTS check_api_usage_log_status;'
    execute 'ALTER TABLE zipcode_lookups DROP CONSTRAINT IF EXISTS check_zipcode_lookup_status;'
  end
end
