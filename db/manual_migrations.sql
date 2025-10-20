-- ================================================================
-- MANUAL MIGRATION SCRIPT
-- Run this if you cannot use `rails db:migrate`
-- ================================================================
--
-- This script contains all migrations needed for the new features:
-- 1. Probability fields (verizon_5g_probability, verizon_lte_probability)
-- 2. Column preferences table (admin_user_column_preferences)
-- 3. Coordinates (latitude, longitude)
--
-- Usage:
--   psql -U your_user -d bulk_lookup_development -f db/manual_migrations.sql
--
-- ================================================================

BEGIN;

-- ================================================================
-- Migration 1: Add Probability Fields to Contacts
-- Timestamp: 20251020051031
-- ================================================================

DO $$
BEGIN
    -- Add verizon_5g_probability column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'contacts' AND column_name = 'verizon_5g_probability'
    ) THEN
        ALTER TABLE contacts ADD COLUMN verizon_5g_probability INTEGER;
        RAISE NOTICE 'Added verizon_5g_probability column';
    ELSE
        RAISE NOTICE 'verizon_5g_probability column already exists';
    END IF;

    -- Add verizon_lte_probability column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'contacts' AND column_name = 'verizon_lte_probability'
    ) THEN
        ALTER TABLE contacts ADD COLUMN verizon_lte_probability INTEGER;
        RAISE NOTICE 'Added verizon_lte_probability column';
    ELSE
        RAISE NOTICE 'verizon_lte_probability column already exists';
    END IF;

    -- Create index on verizon_5g_probability
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'contacts' AND indexname = 'index_contacts_on_verizon_5g_probability'
    ) THEN
        CREATE INDEX index_contacts_on_verizon_5g_probability ON contacts (verizon_5g_probability);
        RAISE NOTICE 'Created index on verizon_5g_probability';
    ELSE
        RAISE NOTICE 'Index on verizon_5g_probability already exists';
    END IF;

    -- Create index on verizon_lte_probability
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'contacts' AND indexname = 'index_contacts_on_verizon_lte_probability'
    ) THEN
        CREATE INDEX index_contacts_on_verizon_lte_probability ON contacts (verizon_lte_probability);
        RAISE NOTICE 'Created index on verizon_lte_probability';
    ELSE
        RAISE NOTICE 'Index on verizon_lte_probability already exists';
    END IF;
END $$;

-- ================================================================
-- Migration 2: Create Admin User Column Preferences Table
-- Timestamp: 20251020051050
-- ================================================================

DO $$
BEGIN
    -- Create table if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'admin_user_column_preferences'
    ) THEN
        CREATE TABLE admin_user_column_preferences (
            id BIGSERIAL PRIMARY KEY,
            admin_user_id BIGINT NOT NULL,
            resource_name VARCHAR NOT NULL,
            preferences JSONB DEFAULT '{}',
            created_at TIMESTAMP(6) NOT NULL,
            updated_at TIMESTAMP(6) NOT NULL,
            CONSTRAINT fk_admin_user_column_preferences_admin_user_id
                FOREIGN KEY (admin_user_id)
                REFERENCES admin_users(id)
                ON DELETE CASCADE
        );
        RAISE NOTICE 'Created admin_user_column_preferences table';
    ELSE
        RAISE NOTICE 'admin_user_column_preferences table already exists';
    END IF;

    -- Create index on admin_user_id
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'admin_user_column_preferences'
        AND indexname = 'index_admin_user_column_preferences_on_admin_user_id'
    ) THEN
        CREATE INDEX index_admin_user_column_preferences_on_admin_user_id
        ON admin_user_column_preferences (admin_user_id);
        RAISE NOTICE 'Created index on admin_user_id';
    ELSE
        RAISE NOTICE 'Index on admin_user_id already exists';
    END IF;

    -- Create unique composite index
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'admin_user_column_preferences'
        AND indexname = 'index_column_prefs_on_user_and_resource'
    ) THEN
        CREATE UNIQUE INDEX index_column_prefs_on_user_and_resource
        ON admin_user_column_preferences (admin_user_id, resource_name);
        RAISE NOTICE 'Created unique composite index';
    ELSE
        RAISE NOTICE 'Unique composite index already exists';
    END IF;
END $$;

-- ================================================================
-- Migration 3: Add Coordinates to Contacts
-- Timestamp: 20251020053443
-- ================================================================

DO $$
BEGIN
    -- Add latitude column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'contacts' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE contacts ADD COLUMN latitude NUMERIC(10, 6);
        RAISE NOTICE 'Added latitude column';
    ELSE
        RAISE NOTICE 'latitude column already exists';
    END IF;

    -- Add longitude column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'contacts' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE contacts ADD COLUMN longitude NUMERIC(10, 6);
        RAISE NOTICE 'Added longitude column';
    ELSE
        RAISE NOTICE 'longitude column already exists';
    END IF;

    -- Create composite index on latitude and longitude
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'contacts' AND indexname = 'index_contacts_on_latitude_and_longitude'
    ) THEN
        CREATE INDEX index_contacts_on_latitude_and_longitude
        ON contacts (latitude, longitude);
        RAISE NOTICE 'Created composite index on latitude and longitude';
    ELSE
        RAISE NOTICE 'Composite index on latitude and longitude already exists';
    END IF;
END $$;

-- ================================================================
-- Update schema_migrations table
-- ================================================================

DO $$
BEGIN
    -- Ensure schema_migrations table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'schema_migrations'
    ) THEN
        CREATE TABLE schema_migrations (
            version VARCHAR NOT NULL PRIMARY KEY
        );
        RAISE NOTICE 'Created schema_migrations table';
    END IF;

    -- Insert migration versions
    INSERT INTO schema_migrations (version)
    VALUES ('20251020051031')
    ON CONFLICT (version) DO NOTHING;

    INSERT INTO schema_migrations (version)
    VALUES ('20251020051050')
    ON CONFLICT (version) DO NOTHING;

    INSERT INTO schema_migrations (version)
    VALUES ('20251020053443')
    ON CONFLICT (version) DO NOTHING;

    RAISE NOTICE 'Updated schema_migrations table';
END $$;

COMMIT;

-- ================================================================
-- Verification Queries
-- ================================================================

-- Run these to verify the migrations were successful:

\echo ''
\echo '=== Verification: Contacts Table New Columns ==='
SELECT
    column_name,
    data_type,
    numeric_precision,
    numeric_scale,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'contacts'
AND column_name IN ('verizon_5g_probability', 'verizon_lte_probability', 'latitude', 'longitude')
ORDER BY column_name;

\echo ''
\echo '=== Verification: Contacts Table Indexes ==='
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'contacts'
AND indexname LIKE '%probability%' OR indexname LIKE '%latitude%' OR indexname LIKE '%longitude%'
ORDER BY indexname;

\echo ''
\echo '=== Verification: Admin User Column Preferences Table ==='
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'admin_user_column_preferences'
ORDER BY ordinal_position;

\echo ''
\echo '=== Verification: Schema Migrations ==='
SELECT version
FROM schema_migrations
WHERE version IN ('20251020051031', '20251020051050', '20251020053443')
ORDER BY version;

\echo ''
\echo '=== Migration Complete ==='
\echo 'If you see all expected columns, indexes, and migration versions above, the migrations were successful.'
