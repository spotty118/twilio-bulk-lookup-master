<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Contact extends Model
{
    use HasFactory;

    protected $fillable = [
        'raw_phone_number',
        'formatted_phone_number',
        'status',
        'device_type',
        'line_type',
        'carrier_name',
        'country_code',
        'sms_pumping_risk_level',
        'sms_pumping_risk_score',
        'sms_pumping_number_blocked',
        'is_business',
        'business_name',
        'business_type',
        'business_industry',
        'business_employee_range',
        'business_website',
        'business_city',
        'business_state',
        'business_country',
        'business_postal_code',
        'email',
        'email_verified',
        'first_name',
        'last_name',
        'position',
        'consumer_address',
        'consumer_city',
        'consumer_state',
        'consumer_postal_code',
        'address_type',
        'address_verified',
        'verizon_5g_home_available',
        'verizon_lte_home_available',
        'verizon_fios_available',
        'estimated_download_speed',
        'rpv_status',
        'rpv_iscell',
        'rpv_carrier',
        'rpv_cnam',
        'rpv_error_text',
        'scout_ported',
        'scout_location_routing_number',
        'scout_operating_company_name',
        'scout_operating_company_type',
        'error_code',
        'lookup_performed_at',
        'duplicate_of_id',
        'duplicate_confidence',
        'duplicate_checked_at',
        'data_quality_score',
    ];

    protected $casts = [
        'is_business' => 'boolean',
        'email_verified' => 'boolean',
        'address_verified' => 'boolean',
        'verizon_5g_home_available' => 'boolean',
        'verizon_lte_home_available' => 'boolean',
        'verizon_fios_available' => 'boolean',
        'scout_ported' => 'boolean',
        'sms_pumping_number_blocked' => 'boolean',
        'lookup_performed_at' => 'datetime',
        'duplicate_checked_at' => 'datetime',
        'sms_pumping_risk_score' => 'integer',
        'duplicate_confidence' => 'integer',
        'data_quality_score' => 'integer',
    ];

    // Scopes for status
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    public function scopeProcessing($query)
    {
        return $query->where('status', 'processing');
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    // Scopes for risk levels
    public function scopeHighRisk($query)
    {
        return $query->where('sms_pumping_risk_level', 'high');
    }

    public function scopeMediumRisk($query)
    {
        return $query->where('sms_pumping_risk_level', 'medium');
    }

    public function scopeLowRisk($query)
    {
        return $query->where('sms_pumping_risk_level', 'low');
    }

    // Scopes for device types
    public function scopeMobile($query)
    {
        return $query->where('device_type', 'mobile');
    }

    public function scopeLandline($query)
    {
        return $query->where('device_type', 'landline');
    }

    public function scopeVoip($query)
    {
        return $query->where('device_type', 'voip');
    }

    // Scopes for contact type
    public function scopeBusinesses($query)
    {
        return $query->where('is_business', true);
    }

    public function scopeConsumers($query)
    {
        return $query->where('is_business', false);
    }

    // Scopes for line status
    public function scopeConnected($query)
    {
        return $query->where('rpv_status', 'connected');
    }

    public function scopeDisconnected($query)
    {
        return $query->where('rpv_status', 'disconnected');
    }

    // Scopes for porting
    public function scopePorted($query)
    {
        return $query->where('scout_ported', true);
    }

    public function scopeNotPorted($query)
    {
        return $query->where('scout_ported', false);
    }

    // Helper methods
    public function getBusinessDisplayNameAttribute()
    {
        if ($this->business_name) {
            return $this->business_name;
        }
        if ($this->first_name || $this->last_name) {
            return trim($this->first_name . ' ' . $this->last_name);
        }
        return $this->formatted_phone_number ?? $this->raw_phone_number;
    }

    public function isBusiness(): bool
    {
        return $this->is_business === true;
    }

    public function isConsumer(): bool
    {
        return $this->is_business === false;
    }

    public function hasFullAddress(): bool
    {
        return !empty($this->consumer_address) &&
               !empty($this->consumer_city) &&
               !empty($this->consumer_state);
    }

    public function getFullAddressAttribute()
    {
        if (!$this->hasFullAddress()) {
            return null;
        }

        $parts = [
            $this->consumer_address,
            $this->consumer_city,
            $this->consumer_state,
            $this->consumer_postal_code
        ];

        return implode(', ', array_filter($parts));
    }
}
