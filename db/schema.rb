# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_12_16_195319) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "api_token"
    t.index ["api_token"], name: "index_admin_users_on_api_token", unique: true
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "api_usage_logs", force: :cascade do |t|
    t.bigint "contact_id"
    t.string "provider", null: false
    t.string "service", null: false
    t.string "endpoint"
    t.decimal "cost", precision: 10, scale: 4, default: "0.0"
    t.string "currency", default: "USD"
    t.integer "credits_used", default: 0
    t.string "request_id"
    t.string "status"
    t.integer "response_time_ms"
    t.integer "http_status_code"
    t.jsonb "request_params", default: {}
    t.jsonb "response_data", default: {}
    t.text "error_message"
    t.datetime "requested_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id", "provider"], name: "index_api_usage_logs_on_contact_id_and_provider"
    t.index ["contact_id"], name: "index_api_usage_logs_on_contact_id"
    t.index ["provider", "requested_at"], name: "index_api_usage_logs_on_provider_and_requested_at"
    t.index ["provider"], name: "index_api_usage_logs_on_provider"
    t.index ["requested_at"], name: "index_api_usage_logs_on_requested_at"
    t.index ["service"], name: "index_api_usage_logs_on_service"
    t.index ["status"], name: "index_api_usage_logs_on_status"
    t.check_constraint "status IS NULL OR (status::text = ANY (ARRAY['success'::character varying, 'failed'::character varying, 'rate_limited'::character varying, 'error'::character varying, 'timeout'::character varying]::text[]))", name: "check_api_usage_log_status"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "raw_phone_number", null: false
    t.string "formatted_phone_number"
    t.string "mobile_network_code"
    t.string "error_code"
    t.string "mobile_country_code"
    t.string "carrier_name"
    t.string "device_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "status", default: "pending", null: false
    t.datetime "lookup_performed_at"
    t.boolean "phone_valid"
    t.jsonb "validation_errors", default: []
    t.string "country_code"
    t.string "calling_country_code"
    t.string "line_type"
    t.string "line_type_confidence"
    t.string "caller_name"
    t.string "caller_type"
    t.integer "sms_pumping_risk_score"
    t.string "sms_pumping_risk_level"
    t.string "sms_pumping_carrier_risk_category"
    t.boolean "sms_pumping_number_blocked"
    t.date "reassigned_number_last_verified_date"
    t.boolean "reassigned_number_is_reassigned"
    t.boolean "is_business", default: false
    t.string "business_name"
    t.string "business_legal_name"
    t.string "business_type"
    t.string "business_category"
    t.string "business_industry"
    t.integer "business_employee_count"
    t.string "business_employee_range"
    t.bigint "business_annual_revenue"
    t.string "business_revenue_range"
    t.integer "business_founded_year"
    t.string "business_address"
    t.string "business_city"
    t.string "business_state"
    t.string "business_country"
    t.string "business_postal_code"
    t.string "business_website"
    t.string "business_email_domain"
    t.string "business_linkedin_url"
    t.string "business_twitter_handle"
    t.text "business_description"
    t.jsonb "business_tags", default: []
    t.jsonb "business_tech_stack", default: []
    t.boolean "business_enriched", default: false
    t.string "business_enrichment_provider"
    t.datetime "business_enriched_at"
    t.integer "business_confidence_score"
    t.string "email"
    t.boolean "email_verified"
    t.integer "email_score"
    t.string "email_status"
    t.string "email_type"
    t.jsonb "additional_emails", default: []
    t.boolean "email_enriched", default: false
    t.string "email_enrichment_provider"
    t.datetime "email_enriched_at"
    t.string "first_name"
    t.string "last_name"
    t.string "full_name"
    t.string "position"
    t.string "department"
    t.string "seniority"
    t.string "linkedin_url"
    t.string "twitter_url"
    t.string "facebook_url"
    t.bigint "duplicate_of_id"
    t.boolean "is_duplicate", default: false
    t.integer "duplicate_confidence"
    t.datetime "duplicate_checked_at"
    t.jsonb "merge_history", default: []
    t.string "phone_fingerprint"
    t.string "name_fingerprint"
    t.string "email_fingerprint"
    t.integer "data_quality_score"
    t.integer "completeness_percentage"
    t.string "consumer_address"
    t.string "consumer_city"
    t.string "consumer_state"
    t.string "consumer_postal_code"
    t.string "consumer_country", default: "USA"
    t.string "address_type"
    t.boolean "address_verified"
    t.boolean "address_enriched", default: false
    t.string "address_enrichment_provider"
    t.datetime "address_enriched_at"
    t.integer "address_confidence_score"
    t.boolean "verizon_5g_home_available"
    t.boolean "verizon_lte_home_available"
    t.boolean "verizon_fios_available"
    t.boolean "verizon_coverage_checked", default: false
    t.datetime "verizon_coverage_checked_at"
    t.jsonb "verizon_coverage_data"
    t.string "estimated_download_speed"
    t.string "estimated_upload_speed"
    t.boolean "trust_hub_verified", default: false
    t.string "trust_hub_status"
    t.string "trust_hub_business_sid"
    t.string "trust_hub_customer_profile_sid"
    t.string "trust_hub_business_name"
    t.string "trust_hub_business_type"
    t.string "trust_hub_registration_number"
    t.string "trust_hub_tax_id"
    t.string "trust_hub_website"
    t.string "trust_hub_regulatory_status"
    t.string "trust_hub_compliance_type"
    t.string "trust_hub_country"
    t.string "trust_hub_region"
    t.datetime "trust_hub_verified_at"
    t.integer "trust_hub_verification_score"
    t.jsonb "trust_hub_verification_data", default: {}
    t.jsonb "trust_hub_checks_completed", default: []
    t.jsonb "trust_hub_checks_failed", default: []
    t.boolean "trust_hub_enriched", default: false
    t.datetime "trust_hub_enriched_at"
    t.text "trust_hub_error"
    t.integer "sms_sent_count", default: 0
    t.integer "sms_delivered_count", default: 0
    t.integer "sms_failed_count", default: 0
    t.datetime "sms_last_sent_at"
    t.boolean "sms_opt_out", default: false
    t.datetime "sms_opt_out_at"
    t.integer "voice_calls_count", default: 0
    t.integer "voice_answered_count", default: 0
    t.integer "voice_voicemail_count", default: 0
    t.datetime "voice_last_called_at"
    t.boolean "voice_opt_out", default: false
    t.datetime "last_engagement_at"
    t.integer "engagement_score", default: 0
    t.string "engagement_status"
    t.string "salesforce_id"
    t.datetime "salesforce_synced_at"
    t.string "salesforce_sync_status"
    t.string "hubspot_id"
    t.datetime "hubspot_synced_at"
    t.string "hubspot_sync_status"
    t.string "pipedrive_id"
    t.datetime "pipedrive_synced_at"
    t.string "pipedrive_sync_status"
    t.boolean "crm_sync_enabled", default: true
    t.jsonb "crm_sync_errors", default: {}
    t.datetime "last_crm_sync_at"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.datetime "geocoded_at"
    t.string "geocoding_accuracy"
    t.string "geocoding_provider"
    t.decimal "api_cost", precision: 8, scale: 4
    t.integer "api_response_time_ms"
    t.index ["address_enriched", "verizon_coverage_checked"], name: "index_contacts_on_address_and_verizon_check", where: "((address_enriched = true) AND (verizon_coverage_checked = false))"
    t.index ["address_enriched"], name: "index_contacts_on_address_enriched"
    t.index ["business_email_domain"], name: "index_contacts_on_business_email_domain"
    t.index ["business_employee_range"], name: "index_contacts_on_business_employee_range"
    t.index ["business_enriched", "email_enriched"], name: "index_contacts_on_business_and_email_enriched", where: "((business_enriched = true) AND (email_enriched = false))"
    t.index ["business_enriched", "status"], name: "idx_contacts_be_false_status", where: "(business_enriched = false)"
    t.index ["business_enriched"], name: "index_contacts_on_business_enriched"
    t.index ["business_industry"], name: "index_contacts_on_business_industry"
    t.index ["business_industry"], name: "index_contacts_on_business_industry_partial", where: "(business_industry IS NOT NULL)"
    t.index ["business_name"], name: "index_contacts_on_business_name"
    t.index ["business_revenue_range"], name: "index_contacts_on_business_revenue_range"
    t.index ["business_type"], name: "index_contacts_on_business_type"
    t.index ["carrier_name", "device_type"], name: "index_contacts_on_carrier_and_device_where_completed", where: "((status)::text = 'completed'::text)"
    t.index ["consumer_postal_code"], name: "index_contacts_on_consumer_postal_code"
    t.index ["consumer_state"], name: "index_contacts_on_consumer_state"
    t.index ["country_code"], name: "index_contacts_on_country_code"
    t.index ["created_at"], name: "index_contacts_on_created_at_where_pending", where: "((status)::text = 'pending'::text)"
    t.index ["data_quality_score", "status"], name: "idx_contacts_qs_lt60_status", where: "(data_quality_score < 60)"
    t.index ["data_quality_score"], name: "index_contacts_on_data_quality_score"
    t.index ["data_quality_score"], name: "index_contacts_on_quality_score"
    t.index ["duplicate_of_id", "is_duplicate"], name: "index_contacts_on_duplicate_of_id_and_is_duplicate"
    t.index ["duplicate_of_id"], name: "index_contacts_on_duplicate_of_id"
    t.index ["email"], name: "index_contacts_on_email"
    t.index ["email_enriched"], name: "index_contacts_on_email_enriched"
    t.index ["email_fingerprint"], name: "index_contacts_on_email_fingerprint"
    t.index ["email_fingerprint"], name: "index_contacts_on_email_fingerprint_partial", where: "(email_fingerprint IS NOT NULL)"
    t.index ["email_verified"], name: "index_contacts_on_email_verified"
    t.index ["engagement_status"], name: "index_contacts_on_engagement_status"
    t.index ["error_code"], name: "index_contacts_on_error_code"
    t.index ["formatted_phone_number"], name: "index_contacts_on_formatted_phone_number"
    t.index ["full_name"], name: "index_contacts_on_full_name"
    t.index ["geocoded_at"], name: "index_contacts_on_geocoded_at"
    t.index ["hubspot_id"], name: "index_contacts_on_hubspot_id", unique: true, where: "(hubspot_id IS NOT NULL)"
    t.index ["hubspot_id"], name: "index_contacts_on_hubspot_id_partial", where: "(hubspot_id IS NOT NULL)"
    t.index ["is_business", "address_enriched"], name: "index_contacts_on_is_business_and_address_enriched", where: "((is_business = false) AND (address_enriched = false))"
    t.index ["is_business", "business_employee_range"], name: "index_contacts_on_business_and_size"
    t.index ["is_business", "business_enriched"], name: "index_contacts_on_is_business_and_enriched"
    t.index ["is_business", "business_industry"], name: "index_contacts_on_business_and_industry"
    t.index ["is_business", "trust_hub_enriched", "business_enriched"], name: "index_contacts_on_trust_hub_needs", where: "((is_business = true) AND (trust_hub_enriched = false) AND (business_enriched = true))"
    t.index ["is_business", "trust_hub_verified"], name: "index_contacts_on_business_and_trust_verified"
    t.index ["is_business"], name: "index_contacts_on_is_business"
    t.index ["is_duplicate", "duplicate_checked_at"], name: "index_contacts_on_duplicate_status", where: "(is_duplicate = false)"
    t.index ["is_duplicate"], name: "index_contacts_on_is_duplicate"
    t.index ["last_crm_sync_at"], name: "index_contacts_on_last_crm_sync_at"
    t.index ["last_engagement_at"], name: "index_contacts_on_last_engagement_at"
    t.index ["last_name", "first_name"], name: "index_contacts_on_name"
    t.index ["latitude", "longitude"], name: "index_contacts_on_latitude_and_longitude"
    t.index ["line_type"], name: "index_contacts_on_line_type"
    t.index ["lookup_performed_at"], name: "index_contacts_on_lookup_performed_at"
    t.index ["name_fingerprint"], name: "index_contacts_on_name_fingerprint"
    t.index ["name_fingerprint"], name: "index_contacts_on_name_fingerprint_partial", where: "(name_fingerprint IS NOT NULL)"
    t.index ["phone_fingerprint"], name: "index_contacts_on_phone_fingerprint"
    t.index ["phone_fingerprint"], name: "index_contacts_on_phone_fingerprint_partial", where: "(phone_fingerprint IS NOT NULL)"
    t.index ["phone_valid"], name: "index_contacts_on_phone_valid"
    t.index ["pipedrive_id"], name: "index_contacts_on_pipedrive_id", unique: true, where: "(pipedrive_id IS NOT NULL)"
    t.index ["pipedrive_id"], name: "index_contacts_on_pipedrive_id_partial", where: "(pipedrive_id IS NOT NULL)"
    t.index ["salesforce_id"], name: "index_contacts_on_salesforce_id", unique: true, where: "(salesforce_id IS NOT NULL)"
    t.index ["salesforce_id"], name: "index_contacts_on_salesforce_id_partial", where: "(salesforce_id IS NOT NULL)"
    t.index ["sms_opt_out"], name: "index_contacts_on_sms_opt_out"
    t.index ["sms_pumping_risk_level", "country_code"], name: "index_contacts_on_risk_and_country"
    t.index ["sms_pumping_risk_level"], name: "index_contacts_on_sms_pumping_risk_level"
    t.index ["sms_pumping_risk_level"], name: "index_contacts_on_sms_pumping_risk_level_partial", where: "(sms_pumping_risk_level IS NOT NULL)"
    t.index ["sms_pumping_risk_score"], name: "index_contacts_on_sms_pumping_risk_score"
    t.index ["status", "address_enriched"], name: "index_contacts_on_status_and_address_enriched"
    t.index ["status", "business_enriched"], name: "index_contacts_on_status_and_business_enriched"
    t.index ["status", "created_at"], name: "index_contacts_on_status_and_created_at"
    t.index ["status", "email_enriched"], name: "index_contacts_on_status_and_email_enriched"
    t.index ["status", "lookup_performed_at"], name: "index_contacts_on_status_and_lookup_performed_at"
    t.index ["status"], name: "index_contacts_on_status"
    t.index ["trust_hub_business_sid"], name: "index_contacts_on_trust_hub_business_sid"
    t.index ["trust_hub_compliance_type"], name: "index_contacts_on_trust_hub_compliance_type"
    t.index ["trust_hub_enriched"], name: "index_contacts_on_trust_hub_enriched"
    t.index ["trust_hub_regulatory_status"], name: "index_contacts_on_trust_hub_regulatory_status"
    t.index ["trust_hub_status"], name: "index_contacts_on_trust_hub_status"
    t.index ["trust_hub_verified", "trust_hub_status"], name: "index_contacts_on_trust_verified_and_status"
    t.index ["trust_hub_verified"], name: "index_contacts_on_trust_hub_verified"
    t.index ["updated_at"], name: "index_contacts_on_updated_at_where_failed", where: "((status)::text = 'failed'::text)"
    t.index ["verizon_5g_home_available"], name: "index_contacts_on_verizon_5g_home_available"
    t.index ["verizon_coverage_checked"], name: "index_contacts_on_verizon_coverage_checked"
    t.index ["verizon_lte_home_available"], name: "index_contacts_on_verizon_lte_home_available"
    t.index ["voice_opt_out"], name: "index_contacts_on_voice_opt_out"
    t.check_constraint "completeness_percentage IS NULL OR completeness_percentage >= 0 AND completeness_percentage <= 100", name: "check_completeness_percentage_range"
    t.check_constraint "data_quality_score IS NULL OR data_quality_score >= 0 AND data_quality_score <= 100", name: "check_data_quality_score_range"
    t.check_constraint "duplicate_confidence IS NULL OR duplicate_confidence >= 0 AND duplicate_confidence <= 100", name: "check_duplicate_confidence_range"
    t.check_constraint "sms_pumping_risk_level IS NULL OR (sms_pumping_risk_level::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying]::text[]))", name: "check_sms_pumping_risk_level"
    t.check_constraint "sms_pumping_risk_score IS NULL OR sms_pumping_risk_score >= 0 AND sms_pumping_risk_score <= 100", name: "check_sms_pumping_risk_score_range"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "check_contact_status"
  end

  create_table "twilio_credentials", force: :cascade do |t|
    t.string "account_sid"
    t.string "auth_token"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "enable_line_type_intelligence", default: true
    t.boolean "enable_caller_name", default: true
    t.boolean "enable_sms_pumping_risk", default: true
    t.boolean "enable_sim_swap", default: false
    t.boolean "enable_reassigned_number", default: false
    t.text "notes"
    t.boolean "enable_business_enrichment", default: true
    t.string "clearbit_api_key"
    t.string "numverify_api_key"
    t.boolean "auto_enrich_businesses", default: true
    t.integer "enrichment_confidence_threshold", default: 50
    t.boolean "enable_email_enrichment", default: true
    t.string "hunter_api_key"
    t.string "zerobounce_api_key"
    t.integer "email_verification_confidence_threshold", default: 70
    t.boolean "enable_duplicate_detection", default: true
    t.integer "duplicate_confidence_threshold", default: 80
    t.boolean "auto_merge_duplicates", default: false
    t.boolean "enable_ai_features", default: true
    t.string "openai_api_key"
    t.string "ai_model", default: "gpt-4o-mini"
    t.integer "ai_max_tokens", default: 500
    t.boolean "enable_zipcode_lookup", default: false
    t.string "google_places_api_key"
    t.string "yelp_api_key"
    t.integer "results_per_zipcode", default: 20
    t.boolean "auto_enrich_zipcode_results", default: true
    t.boolean "enable_address_enrichment", default: false
    t.boolean "enable_verizon_coverage_check", default: false
    t.string "whitepages_api_key"
    t.string "truecaller_api_key"
    t.boolean "auto_check_verizon_coverage", default: true
    t.boolean "enable_trust_hub", default: false
    t.string "trust_hub_policy_sid"
    t.string "trust_hub_webhook_url"
    t.boolean "auto_create_trust_hub_profiles", default: false
    t.integer "trust_hub_reverification_days", default: 90
    t.string "google_geocoding_api_key"
    t.boolean "enable_geocoding", default: false
    t.string "anthropic_api_key"
    t.string "google_ai_api_key"
    t.boolean "enable_anthropic", default: false
    t.boolean "enable_google_ai", default: false
    t.string "preferred_llm_provider", default: "openai"
    t.string "anthropic_model", default: "claude-3-5-sonnet-20241022"
    t.string "google_ai_model", default: "gemini-1.5-flash"
    t.boolean "enable_sms_messaging", default: false
    t.boolean "enable_voice_messaging", default: false
    t.string "twilio_phone_number"
    t.string "twilio_messaging_service_sid"
    t.string "voice_call_webhook_url"
    t.boolean "voice_recording_enabled", default: false
    t.text "sms_intro_template"
    t.text "sms_follow_up_template"
    t.integer "max_sms_per_hour", default: 100
    t.integer "max_calls_per_hour", default: 50
    t.boolean "enable_salesforce_sync", default: false
    t.string "salesforce_instance_url"
    t.string "salesforce_client_id"
    t.string "salesforce_client_secret"
    t.string "salesforce_access_token"
    t.string "salesforce_refresh_token"
    t.boolean "salesforce_auto_sync", default: false
    t.boolean "enable_hubspot_sync", default: false
    t.string "hubspot_api_key"
    t.string "hubspot_portal_id"
    t.boolean "hubspot_auto_sync", default: false
    t.boolean "enable_pipedrive_sync", default: false
    t.string "pipedrive_api_key"
    t.string "pipedrive_company_domain"
    t.boolean "pipedrive_auto_sync", default: false
    t.integer "crm_sync_interval_minutes", default: 60
    t.string "crm_sync_direction", default: "bidirectional"
    t.boolean "is_singleton", default: true, null: false
    t.datetime "salesforce_token_expires_at"
    t.string "verizon_api_key"
    t.string "verizon_api_secret"
    t.string "verizon_account_name"
    t.index ["is_singleton"], name: "index_twilio_credentials_singleton", unique: true, where: "(is_singleton = true)"
  end

  create_table "webhooks", force: :cascade do |t|
    t.bigint "contact_id"
    t.string "source", null: false
    t.string "event_type", null: false
    t.string "external_id"
    t.jsonb "payload", default: {}
    t.jsonb "headers", default: {}
    t.string "status", default: "pending"
    t.datetime "processed_at"
    t.text "processing_error"
    t.integer "retry_count", default: 0
    t.datetime "received_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "idempotency_key"
    t.index ["contact_id"], name: "index_webhooks_on_contact_id"
    t.index ["event_type"], name: "index_webhooks_on_event_type"
    t.index ["external_id"], name: "index_webhooks_on_external_id"
    t.index ["idempotency_key"], name: "index_webhooks_on_idempotency_key", unique: true
    t.index ["received_at"], name: "index_webhooks_on_received_at"
    t.index ["source", "event_type"], name: "index_webhooks_on_source_and_event_type"
    t.index ["source", "external_id"], name: "index_webhooks_on_source_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["source"], name: "index_webhooks_on_source"
    t.index ["status"], name: "index_webhooks_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processing'::character varying, 'processed'::character varying, 'failed'::character varying]::text[])", name: "check_webhook_status"
  end

  create_table "zipcode_lookups", force: :cascade do |t|
    t.string "zipcode", null: false
    t.string "status", default: "pending", null: false
    t.integer "businesses_found", default: 0
    t.integer "businesses_imported", default: 0
    t.integer "businesses_updated", default: 0
    t.integer "businesses_skipped", default: 0
    t.string "provider"
    t.text "search_params"
    t.text "error_message"
    t.datetime "lookup_started_at"
    t.datetime "lookup_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_zipcode_lookups_on_created_at"
    t.index ["status"], name: "index_zipcode_lookups_on_status"
    t.index ["zipcode"], name: "index_zipcode_lookups_on_zipcode"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processing'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "check_zipcode_lookup_status"
  end

  add_foreign_key "api_usage_logs", "contacts"
  add_foreign_key "contacts", "contacts", column: "duplicate_of_id"
  add_foreign_key "webhooks", "contacts"
end
