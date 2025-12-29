<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TwilioCredential extends Model
{
    use HasFactory;

    protected $fillable = [
        'account_sid',
        'auth_token',
        'enable_line_type_intelligence',
        'enable_caller_name',
        'enable_sms_pumping_risk',
        'enable_sim_swap',
        'enable_reassigned_number',
        'enable_real_phone_validation',
        'rpv_unique_name',
        'enable_icehook_scout',
        'notes',
        'enable_business_enrichment',
        'auto_enrich_businesses',
        'enrichment_confidence_threshold',
        'clearbit_api_key',
        'numverify_api_key',
        'enable_trust_hub',
        'trust_hub_policy_sid',
        'trust_hub_webhook_url',
        'auto_create_trust_hub_profiles',
        'trust_hub_reverification_days',
        'enable_email_enrichment',
        'hunter_api_key',
        'zerobounce_api_key',
        'enable_duplicate_detection',
        'duplicate_confidence_threshold',
        'auto_merge_duplicates',
        'enable_ai_features',
        'openai_api_key',
        'ai_model',
        'ai_max_tokens',
        'enable_openrouter',
        'openrouter_api_key',
        'openrouter_model',
        'preferred_llm_provider',
        'enable_zipcode_lookup',
        'google_places_api_key',
        'yelp_api_key',
        'results_per_zipcode',
        'auto_enrich_zipcode_results',
        'enable_address_enrichment',
        'enable_verizon_coverage_check',
        'whitepages_api_key',
        'truecaller_api_key',
        'auto_check_verizon_coverage',
        'verizon_api_key',
        'verizon_api_secret',
        'verizon_account_name',
        'google_geocoding_api_key',
        'anthropic_api_key',
        'google_ai_api_key',
    ];

    protected $casts = [
        'enable_line_type_intelligence' => 'boolean',
        'enable_caller_name' => 'boolean',
        'enable_sms_pumping_risk' => 'boolean',
        'enable_sim_swap' => 'boolean',
        'enable_reassigned_number' => 'boolean',
        'enable_real_phone_validation' => 'boolean',
        'enable_icehook_scout' => 'boolean',
        'enable_business_enrichment' => 'boolean',
        'auto_enrich_businesses' => 'boolean',
        'enable_trust_hub' => 'boolean',
        'auto_create_trust_hub_profiles' => 'boolean',
        'enable_email_enrichment' => 'boolean',
        'enable_duplicate_detection' => 'boolean',
        'auto_merge_duplicates' => 'boolean',
        'enable_ai_features' => 'boolean',
        'enable_openrouter' => 'boolean',
        'enable_zipcode_lookup' => 'boolean',
        'auto_enrich_zipcode_results' => 'boolean',
        'enable_address_enrichment' => 'boolean',
        'enable_verizon_coverage_check' => 'boolean',
        'auto_check_verizon_coverage' => 'boolean',
        'enrichment_confidence_threshold' => 'integer',
        'duplicate_confidence_threshold' => 'integer',
        'ai_max_tokens' => 'integer',
        'results_per_zipcode' => 'integer',
        'trust_hub_reverification_days' => 'integer',
    ];

    protected $hidden = [
        'auth_token',
        'clearbit_api_key',
        'numverify_api_key',
        'hunter_api_key',
        'zerobounce_api_key',
        'openai_api_key',
        'openrouter_api_key',
        'google_places_api_key',
        'yelp_api_key',
        'whitepages_api_key',
        'truecaller_api_key',
        'verizon_api_key',
        'verizon_api_secret',
        'google_geocoding_api_key',
        'anthropic_api_key',
        'google_ai_api_key',
    ];

    public static function current()
    {
        return static::first();
    }

    public function getDataPackagesAttribute()
    {
        $packages = [];

        if ($this->enable_line_type_intelligence) {
            $packages[] = 'line_type_intelligence';
        }
        if ($this->enable_caller_name) {
            $packages[] = 'caller_name';
        }
        if ($this->enable_sms_pumping_risk) {
            $packages[] = 'sms_pumping_risk';
        }
        if ($this->enable_sim_swap) {
            $packages[] = 'sim_swap';
        }
        if ($this->enable_reassigned_number) {
            $packages[] = 'reassigned_number';
        }

        return implode(',', $packages);
    }
}
