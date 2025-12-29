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
        Schema::create('twilio_credentials', function (Blueprint $table) {
            $table->id();

            // Basic Twilio credentials
            $table->string('account_sid')->unique();
            $table->text('auth_token'); // Encrypted in model

            // Twilio Lookup v2 Data Package Configuration
            $table->boolean('enable_line_type_intelligence')->default(true);
            $table->boolean('enable_caller_name')->default(true);
            $table->boolean('enable_sms_pumping_risk')->default(true);
            $table->boolean('enable_sim_swap')->default(false);
            $table->boolean('enable_reassigned_number')->default(false);
            $table->boolean('enable_real_phone_validation')->default(true);
            $table->string('rpv_unique_name')->default('real_phone_validation_rpv_turbo');
            $table->boolean('enable_icehook_scout')->default(false);

            // Business Enrichment Configuration
            $table->boolean('enable_business_enrichment')->default(true);
            $table->text('clearbit_api_key')->nullable(); // Encrypted
            $table->text('numverify_api_key')->nullable(); // Encrypted
            $table->boolean('auto_enrich_businesses')->default(true);
            $table->integer('enrichment_confidence_threshold')->default(50);

            // Business Directory Configuration
            $table->boolean('enable_zipcode_lookup')->default(false);
            $table->text('google_places_api_key')->nullable(); // Encrypted
            $table->text('yelp_api_key')->nullable(); // Encrypted
            $table->integer('results_per_zipcode')->default(20);
            $table->boolean('auto_enrich_zipcode_results')->default(true);

            // Email Enrichment Configuration
            $table->boolean('enable_email_enrichment')->default(true);
            $table->text('hunter_api_key')->nullable(); // Encrypted
            $table->text('zerobounce_api_key')->nullable(); // Encrypted
            $table->integer('email_verification_confidence_threshold')->default(70);

            // Address Enrichment Configuration
            $table->boolean('enable_address_enrichment')->default(false);
            $table->text('whitepages_api_key')->nullable(); // Encrypted
            $table->text('truecaller_api_key')->nullable(); // Encrypted

            // Verizon Coverage Configuration
            $table->boolean('enable_verizon_coverage_check')->default(false);
            $table->boolean('auto_check_verizon_coverage')->default(true);
            $table->string('verizon_api_key')->nullable();
            $table->string('verizon_api_secret')->nullable();
            $table->string('verizon_account_name')->nullable();

            // Duplicate Detection Configuration
            $table->boolean('enable_duplicate_detection')->default(true);
            $table->integer('duplicate_confidence_threshold')->default(80);
            $table->boolean('auto_merge_duplicates')->default(false);

            // Trust Hub Configuration
            $table->boolean('enable_trust_hub')->default(false);
            $table->string('trust_hub_policy_sid')->nullable();
            $table->string('trust_hub_webhook_url')->nullable();
            $table->boolean('auto_create_trust_hub_profiles')->default(false);
            $table->integer('trust_hub_reverification_days')->default(90);

            // Geocoding Configuration
            $table->boolean('enable_geocoding')->default(false);
            $table->text('google_geocoding_api_key')->nullable(); // Encrypted

            // AI/LLM Configuration
            $table->boolean('enable_ai_features')->default(true);
            $table->text('openai_api_key')->nullable(); // Encrypted
            $table->string('ai_model')->default('gpt-4o-mini');
            $table->integer('ai_max_tokens')->default(500);
            $table->text('anthropic_api_key')->nullable(); // Encrypted
            $table->text('google_ai_api_key')->nullable(); // Encrypted
            $table->text('openrouter_api_key')->nullable(); // Encrypted
            $table->boolean('enable_anthropic')->default(false);
            $table->boolean('enable_google_ai')->default(false);
            $table->boolean('enable_openrouter')->default(false);
            $table->string('preferred_llm_provider')->default('openai');
            $table->string('anthropic_model')->default('claude-3-5-sonnet-20241022');
            $table->string('google_ai_model')->default('gemini-1.5-flash');
            $table->string('openrouter_model')->nullable();

            // SMS/Voice Messaging Configuration
            $table->boolean('enable_sms_messaging')->default(false);
            $table->boolean('enable_voice_messaging')->default(false);
            $table->string('twilio_phone_number')->nullable();
            $table->string('twilio_messaging_service_sid')->nullable();
            $table->string('voice_call_webhook_url')->nullable();
            $table->boolean('voice_recording_enabled')->default(false);
            $table->text('sms_intro_template')->nullable();
            $table->text('sms_follow_up_template')->nullable();
            $table->integer('max_sms_per_hour')->default(100);
            $table->integer('max_calls_per_hour')->default(50);

            // CRM Sync Configuration
            $table->boolean('enable_salesforce_sync')->default(false);
            $table->string('salesforce_instance_url')->nullable();
            $table->string('salesforce_client_id')->nullable();
            $table->string('salesforce_client_secret')->nullable();
            $table->string('salesforce_access_token')->nullable();
            $table->string('salesforce_refresh_token')->nullable();
            $table->timestamp('salesforce_token_expires_at')->nullable();
            $table->boolean('salesforce_auto_sync')->default(false);

            $table->boolean('enable_hubspot_sync')->default(false);
            $table->string('hubspot_api_key')->nullable();
            $table->string('hubspot_portal_id')->nullable();
            $table->boolean('hubspot_auto_sync')->default(false);

            $table->boolean('enable_pipedrive_sync')->default(false);
            $table->string('pipedrive_api_key')->nullable();
            $table->string('pipedrive_company_domain')->nullable();
            $table->boolean('pipedrive_auto_sync')->default(false);

            $table->integer('crm_sync_interval_minutes')->default(60);
            $table->string('crm_sync_direction')->default('bidirectional');

            // Singleton enforcement
            $table->boolean('is_singleton')->default(true);

            // Notes
            $table->text('notes')->nullable();

            $table->timestamps();

            // Unique index for singleton pattern
            $table->unique('is_singleton', 'twilio_credentials_singleton_unique')
                  ->where('is_singleton', true);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('twilio_credentials');
    }
};
