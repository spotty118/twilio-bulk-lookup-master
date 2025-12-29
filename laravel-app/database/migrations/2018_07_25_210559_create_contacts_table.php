<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('contacts', function (Blueprint $table) {
            $table->id();

            // Basic phone information
            $table->string('raw_phone_number')->index();
            $table->string('formatted_phone_number')->nullable()->index();
            $table->string('mobile_network_code')->nullable();
            $table->string('error_code')->nullable()->index();
            $table->string('mobile_country_code')->nullable();
            $table->string('carrier_name')->nullable();
            $table->string('device_type')->nullable();

            // Status and lookup tracking
            $table->string('status')->default('pending')->index();
            $table->timestamp('lookup_performed_at')->nullable()->index();
            $table->boolean('phone_valid')->nullable()->index();
            $table->json('validation_errors')->nullable();

            // Country and calling codes
            $table->string('country_code', 2)->nullable()->index();
            $table->string('calling_country_code')->nullable();

            // Twilio Lookup v2 Data Packages
            // Line Type Intelligence
            $table->string('line_type')->nullable()->index();
            $table->string('line_type_confidence')->nullable();

            // Caller Name
            $table->string('caller_name')->nullable();
            $table->string('caller_type')->nullable();

            // SMS Pumping Risk
            $table->integer('sms_pumping_risk_score')->nullable()->index();
            $table->string('sms_pumping_risk_level')->nullable()->index();
            $table->string('sms_pumping_carrier_risk_category')->nullable();
            $table->boolean('sms_pumping_number_blocked')->nullable();

            // SIM Swap
            $table->timestamp('sim_swap_last_sim_swap_date')->nullable();
            $table->string('sim_swap_swapped_period')->nullable();
            $table->boolean('sim_swap_swapped_in_period')->nullable();

            // Reassigned Number
            $table->date('reassigned_number_last_verified_date')->nullable();
            $table->boolean('reassigned_number_is_reassigned')->nullable();

            // Real Phone Validation (RPV)
            $table->string('rpv_status')->nullable()->index();
            $table->string('rpv_error_text')->nullable();
            $table->string('rpv_iscell')->nullable();
            $table->string('rpv_cnam')->nullable();
            $table->string('rpv_carrier')->nullable();

            // IceHook Scout
            $table->boolean('scout_ported')->nullable()->index();
            $table->string('scout_location_routing_number')->nullable();
            $table->string('scout_operating_company_name')->nullable();
            $table->string('scout_operating_company_type')->nullable();

            // Business Intelligence
            $table->boolean('is_business')->default(false)->index();
            $table->string('business_name')->nullable()->index();
            $table->string('business_legal_name')->nullable();
            $table->string('business_type')->nullable()->index();
            $table->string('business_category')->nullable();
            $table->string('business_industry')->nullable()->index();
            $table->integer('business_employee_count')->nullable();
            $table->string('business_employee_range')->nullable()->index();
            $table->bigInteger('business_annual_revenue')->nullable();
            $table->string('business_revenue_range')->nullable()->index();
            $table->integer('business_founded_year')->nullable();
            $table->string('business_address')->nullable();
            $table->string('business_city')->nullable();
            $table->string('business_state')->nullable();
            $table->string('business_country')->nullable();
            $table->string('business_postal_code')->nullable();
            $table->string('business_website')->nullable();
            $table->string('business_email_domain')->nullable()->index();
            $table->string('business_linkedin_url')->nullable();
            $table->string('business_twitter_handle')->nullable();
            $table->text('business_description')->nullable();
            $table->json('business_tags')->nullable();
            $table->json('business_tech_stack')->nullable();
            $table->boolean('business_enriched')->default(false)->index();
            $table->string('business_enrichment_provider')->nullable();
            $table->timestamp('business_enriched_at')->nullable();
            $table->integer('business_confidence_score')->nullable();

            // Email Enrichment
            $table->string('email')->nullable()->index();
            $table->boolean('email_verified')->nullable()->index();
            $table->integer('email_score')->nullable();
            $table->string('email_status')->nullable();
            $table->string('email_type')->nullable();
            $table->json('additional_emails')->nullable();
            $table->boolean('email_enriched')->default(false)->index();
            $table->string('email_enrichment_provider')->nullable();
            $table->timestamp('email_enriched_at')->nullable();

            // Contact Person Information
            $table->string('first_name')->nullable();
            $table->string('last_name')->nullable();
            $table->string('full_name')->nullable()->index();
            $table->string('position')->nullable();
            $table->string('department')->nullable();
            $table->string('seniority')->nullable();
            $table->string('linkedin_url')->nullable();
            $table->string('twitter_url')->nullable();
            $table->string('facebook_url')->nullable();

            // Duplicate Detection
            $table->foreignId('duplicate_of_id')->nullable()->index();
            $table->boolean('is_duplicate')->default(false)->index();
            $table->integer('duplicate_confidence')->nullable();
            $table->timestamp('duplicate_checked_at')->nullable();
            $table->json('merge_history')->nullable();
            $table->string('phone_fingerprint')->nullable()->index();
            $table->string('name_fingerprint')->nullable()->index();
            $table->string('email_fingerprint')->nullable()->index();

            // Data Quality
            $table->integer('data_quality_score')->nullable()->index();
            $table->integer('completeness_percentage')->nullable();

            // Consumer Address Enrichment
            $table->string('consumer_address')->nullable();
            $table->string('consumer_city')->nullable();
            $table->string('consumer_state')->nullable()->index();
            $table->string('consumer_postal_code')->nullable()->index();
            $table->string('consumer_country')->default('USA');
            $table->string('address_type')->nullable();
            $table->boolean('address_verified')->nullable();
            $table->boolean('address_enriched')->default(false)->index();
            $table->string('address_enrichment_provider')->nullable();
            $table->timestamp('address_enriched_at')->nullable();
            $table->integer('address_confidence_score')->nullable();

            // Verizon Coverage Data
            $table->boolean('verizon_5g_home_available')->nullable()->index();
            $table->boolean('verizon_lte_home_available')->nullable()->index();
            $table->boolean('verizon_fios_available')->nullable();
            $table->boolean('verizon_coverage_checked')->default(false)->index();
            $table->timestamp('verizon_coverage_checked_at')->nullable();
            $table->json('verizon_coverage_data')->nullable();
            $table->string('estimated_download_speed')->nullable();
            $table->string('estimated_upload_speed')->nullable();

            // Trust Hub Verification
            $table->boolean('trust_hub_verified')->default(false)->index();
            $table->string('trust_hub_status')->nullable()->index();
            $table->string('trust_hub_business_sid')->nullable()->index();
            $table->string('trust_hub_customer_profile_sid')->nullable();
            $table->string('trust_hub_business_name')->nullable();
            $table->string('trust_hub_business_type')->nullable();
            $table->string('trust_hub_registration_number')->nullable();
            $table->string('trust_hub_tax_id')->nullable();
            $table->string('trust_hub_website')->nullable();
            $table->string('trust_hub_regulatory_status')->nullable()->index();
            $table->string('trust_hub_compliance_type')->nullable()->index();
            $table->string('trust_hub_country')->nullable();
            $table->string('trust_hub_region')->nullable();
            $table->timestamp('trust_hub_verified_at')->nullable();
            $table->integer('trust_hub_verification_score')->nullable();
            $table->json('trust_hub_verification_data')->nullable();
            $table->json('trust_hub_checks_completed')->nullable();
            $table->json('trust_hub_checks_failed')->nullable();
            $table->boolean('trust_hub_enriched')->default(false)->index();
            $table->timestamp('trust_hub_enriched_at')->nullable();
            $table->text('trust_hub_error')->nullable();

            // SMS Messaging Tracking
            $table->integer('sms_sent_count')->default(0);
            $table->integer('sms_delivered_count')->default(0);
            $table->integer('sms_failed_count')->default(0);
            $table->timestamp('sms_last_sent_at')->nullable();
            $table->boolean('sms_opt_out')->default(false)->index();
            $table->timestamp('sms_opt_out_at')->nullable();

            // Voice Messaging Tracking
            $table->integer('voice_calls_count')->default(0);
            $table->integer('voice_answered_count')->default(0);
            $table->integer('voice_voicemail_count')->default(0);
            $table->timestamp('voice_last_called_at')->nullable();
            $table->boolean('voice_opt_out')->default(false)->index();

            // Engagement Tracking
            $table->timestamp('last_engagement_at')->nullable()->index();
            $table->integer('engagement_score')->default(0);
            $table->string('engagement_status')->nullable()->index();

            // CRM Integration
            $table->string('salesforce_id')->nullable()->index();
            $table->timestamp('salesforce_synced_at')->nullable();
            $table->string('salesforce_sync_status')->nullable();
            $table->string('hubspot_id')->nullable()->index();
            $table->timestamp('hubspot_synced_at')->nullable();
            $table->string('hubspot_sync_status')->nullable();
            $table->string('pipedrive_id')->nullable()->index();
            $table->timestamp('pipedrive_synced_at')->nullable();
            $table->string('pipedrive_sync_status')->nullable();
            $table->boolean('crm_sync_enabled')->default(true);
            $table->json('crm_sync_errors')->nullable();
            $table->timestamp('last_crm_sync_at')->nullable()->index();

            // Geocoding
            $table->decimal('latitude', 10, 6)->nullable();
            $table->decimal('longitude', 10, 6)->nullable();
            $table->timestamp('geocoded_at')->nullable()->index();
            $table->string('geocoding_accuracy')->nullable();
            $table->string('geocoding_provider')->nullable();

            // Cost Tracking
            $table->decimal('api_cost', 8, 4)->nullable();
            $table->integer('api_response_time_ms')->nullable();

            $table->timestamps();

            // Composite indexes for common queries
            $table->index(['status', 'created_at']);
            $table->index(['status', 'lookup_performed_at']);
            $table->index(['status', 'business_enriched']);
            $table->index(['status', 'email_enriched']);
            $table->index(['status', 'address_enriched']);
            $table->index(['is_business', 'business_enriched']);
            $table->index(['is_business', 'business_industry']);
            $table->index(['is_business', 'business_employee_range']);
            $table->index(['is_business', 'trust_hub_verified']);
            $table->index(['duplicate_of_id', 'is_duplicate']);
            $table->index(['last_name', 'first_name']);
            $table->index(['latitude', 'longitude']);
            $table->index(['sms_pumping_risk_level', 'country_code']);
            $table->index(['trust_hub_verified', 'trust_hub_status']);
            $table->index(['carrier_name', 'device_type']);
        });

        // Add self-referencing foreign key for duplicate_of_id
        Schema::table('contacts', function (Blueprint $table) {
            $table->foreign('duplicate_of_id')
                  ->references('id')
                  ->on('contacts')
                  ->onDelete('set null');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('contacts');
    }
};
