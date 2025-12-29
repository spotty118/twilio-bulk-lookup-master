<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * DashboardStats - Read-only model for accessing the dashboard_stats materialized view
 *
 * This model provides fast access to pre-aggregated dashboard statistics.
 * The underlying materialized view would need to be created separately via migration.
 * 
 * Note: In Laravel, we typically use database views or direct queries for this functionality.
 * This is a placeholder model showing the Rails equivalent structure.
 */
class DashboardStats extends Model
{
    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'dashboard_stats';

    /**
     * The primary key for the model.
     *
     * @var string
     */
    protected $primaryKey = 'updated_at';

    /**
     * Indicates if the IDs are auto-incrementing.
     *
     * @var bool
     */
    public $incrementing = false;

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'updated_at' => 'datetime',
        'avg_quality_score' => 'float',
        'avg_completeness' => 'float',
    ];

    /**
     * This is a read-only model - prevent writes
     */
    public function isReadOnly(): bool
    {
        return true;
    }

    /**
     * Get the current (latest) stats
     */
    public static function current(): self
    {
        return self::first() ?? new self(['total_contacts' => 0]);
    }

    /**
     * Get stats as an array for easier use in controllers/views
     */
    public function toStatsArray(): array
    {
        return [
            // Status breakdown
            'pending' => $this->pending_count ?? 0,
            'processing' => $this->processing_count ?? 0,
            'completed' => $this->completed_count ?? 0,
            'failed' => $this->failed_count ?? 0,

            // Phone validation
            'valid_numbers' => $this->valid_numbers_count ?? 0,
            'invalid_numbers' => $this->invalid_numbers_count ?? 0,

            // Line types
            'mobile' => $this->mobile_count ?? 0,
            'landline' => $this->landline_count ?? 0,
            'voip' => $this->voip_count ?? 0,

            // Business
            'businesses' => $this->business_count ?? 0,
            'business_enriched' => $this->business_enriched_count ?? 0,

            // Email
            'has_email' => $this->has_email_count ?? 0,
            'verified_emails' => $this->verified_email_count ?? 0,
            'email_enriched' => $this->email_enriched_count ?? 0,

            // Address
            'address_enriched' => $this->address_enriched_count ?? 0,

            // Verizon
            'verizon_5g_available' => $this->verizon_5g_available_count ?? 0,
            'verizon_lte_available' => $this->verizon_lte_available_count ?? 0,
            'verizon_checked' => $this->verizon_checked_count ?? 0,

            // Trust Hub
            'trust_hub_verified' => $this->trust_hub_verified_count ?? 0,
            'trust_hub_enriched' => $this->trust_hub_enriched_count ?? 0,

            // Risk levels
            'low_risk' => $this->low_risk_count ?? 0,
            'medium_risk' => $this->medium_risk_count ?? 0,
            'high_risk' => $this->high_risk_count ?? 0,

            // Duplicates
            'duplicates' => $this->duplicate_count ?? 0,

            // Quality
            'avg_quality_score' => round($this->avg_quality_score ?? 0, 2),
            'avg_completeness' => round($this->avg_completeness ?? 0, 2),

            // CRM
            'salesforce_synced' => $this->salesforce_synced_count ?? 0,
            'hubspot_synced' => $this->hubspot_synced_count ?? 0,
            'pipedrive_synced' => $this->pipedrive_synced_count ?? 0,

            // Engagement
            'contacted_via_sms' => $this->contacted_via_sms_count ?? 0,
            'contacted_via_voice' => $this->contacted_via_voice_count ?? 0,
            'sms_opt_outs' => $this->sms_opt_out_count ?? 0,

            // Total
            'total_contacts' => $this->total_contacts ?? 0,

            // Metadata
            'last_updated' => $this->updated_at,
        ];
    }

    /**
     * Calculate enrichment percentage
     */
    public function enrichmentPercentage(): float
    {
        if (($this->total_contacts ?? 0) === 0) {
            return 0;
        }

        $enriched = ($this->business_enriched_count ?? 0) + 
                   ($this->email_enriched_count ?? 0) + 
                   ($this->address_enriched_count ?? 0);
        $total = $this->total_contacts * 3;

        return round(($enriched / $total) * 100, 1);
    }

    /**
     * Calculate completion rate
     */
    public function completionRate(): float
    {
        if (($this->total_contacts ?? 0) === 0) {
            return 0;
        }

        return round((($this->completed_count ?? 0) / $this->total_contacts) * 100, 1);
    }

    /**
     * Calculate business percentage
     */
    public function businessPercentage(): float
    {
        if (($this->total_contacts ?? 0) === 0) {
            return 0;
        }

        return round((($this->business_count ?? 0) / $this->total_contacts) * 100, 1);
    }

    /**
     * Calculate email verification rate
     */
    public function emailVerificationRate(): float
    {
        if (($this->has_email_count ?? 0) === 0) {
            return 0;
        }

        return round((($this->verified_email_count ?? 0) / $this->has_email_count) * 100, 1);
    }
}
