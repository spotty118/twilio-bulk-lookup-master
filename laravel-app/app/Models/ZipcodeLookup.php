<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ZipcodeLookup extends Model
{
    use HasFactory;

    protected $fillable = [
        'zipcode',
        'status',
        'provider',
        'businesses_found',
        'businesses_imported',
        'businesses_updated',
        'businesses_skipped',
        'lookup_started_at',
        'lookup_completed_at',
        'duration',
        'error_message',
        'search_params',
    ];

    protected $casts = [
        'lookup_started_at' => 'datetime',
        'lookup_completed_at' => 'datetime',
        'businesses_found' => 'integer',
        'businesses_imported' => 'integer',
        'businesses_updated' => 'integer',
        'businesses_skipped' => 'integer',
        'duration' => 'float',
        'search_params' => 'array',
    ];

    // Scopes
    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    public function scopeProcessing($query)
    {
        return $query->where('status', 'processing');
    }

    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    public function scopeRecent($query)
    {
        return $query->orderBy('created_at', 'desc');
    }

    // Helper methods
    public function getSuccessRateAttribute()
    {
        if ($this->businesses_found == 0) {
            return 0;
        }

        $successful = $this->businesses_imported + $this->businesses_updated;
        return round(($successful / $this->businesses_found) * 100);
    }

    public function getSearchParamsHashAttribute()
    {
        return $this->search_params ?? [];
    }
}
