<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ApiUsageLog extends Model
{
    use HasFactory;

    /**
     * Sensitive keys that should be redacted before logging (GDPR/PII compliance)
     */
    private const SENSITIVE_KEYS = [
        'password', 'token', 'secret', 'key', 'api_key', 'auth_token',
        'access_token', 'refresh_token', 'authorization', 'bearer',
        'credentials', 'account_sid', 'auth_code', 'ssn', 'social_security_number',
        'tax_id', 'ein', 'passport', 'drivers_license', 'credit_card',
        'card_number', 'cvv', 'ccv', 'security_code', 'bank_account',
        'routing_number', 'private_key', 'certificate', 'pem',
    ];

    /**
     * The attributes that are mass assignable.
     *
     * @var array<string>
     */
    protected $fillable = [
        'contact_id',
        'provider',
        'service',
        'endpoint',
        'cost',
        'currency',
        'credits_used',
        'request_id',
        'status',
        'response_time_ms',
        'http_status_code',
        'request_params',
        'response_data',
        'error_message',
        'requested_at',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'cost' => 'decimal:4',
        'request_params' => 'array',
        'response_data' => 'array',
        'requested_at' => 'datetime',
    ];

    /**
     * Boot method for model events
     */
    protected static function boot()
    {
        parent::boot();

        static::saving(function ($log) {
            $log->redactSensitiveData();
        });
    }

    /**
     * Relationships
     */
    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class);
    }

    /**
     * Query Scopes
     */
    public function scopeSuccessful($query)
    {
        return $query->where('status', 'success');
    }

    public function scopeFailed($query)
    {
        return $query->whereIn('status', ['failed', 'error', 'timeout']);
    }

    public function scopeRateLimited($query)
    {
        return $query->where('status', 'rate_limited');
    }

    public function scopeRecent($query)
    {
        return $query->where('requested_at', '>=', now()->subDay());
    }

    public function scopeToday($query)
    {
        return $query->whereDate('requested_at', today());
    }

    public function scopeThisMonth($query)
    {
        return $query->whereYear('requested_at', now()->year)
                     ->whereMonth('requested_at', now()->month);
    }

    public function scopeByProvider($query, string $provider)
    {
        return $query->where('provider', $provider);
    }

    /**
     * Static helper methods for cost analysis
     */
    public static function totalCost($startDate = null, $endDate = null)
    {
        $query = self::query();

        if ($startDate) {
            $query->where('requested_at', '>=', $startDate);
        }
        if ($endDate) {
            $query->where('requested_at', '<=', $endDate);
        }

        return $query->sum('cost');
    }

    public static function totalCostByProvider($startDate = null, $endDate = null)
    {
        $query = self::query();

        if ($startDate) {
            $query->where('requested_at', '>=', $startDate);
        }
        if ($endDate) {
            $query->where('requested_at', '<=', $endDate);
        }

        return $query->groupBy('provider')
                     ->selectRaw('provider, SUM(cost) as total')
                     ->pluck('total', 'provider');
    }

    public static function usageStats($startDate = null, $endDate = null)
    {
        $query = self::query();

        if ($startDate) {
            $query->where('requested_at', '>=', $startDate);
        }
        if ($endDate) {
            $query->where('requested_at', '<=', $endDate);
        }

        return [
            'total_requests' => $query->count(),
            'successful_requests' => (clone $query)->successful()->count(),
            'failed_requests' => (clone $query)->failed()->count(),
            'total_cost' => $query->sum('cost'),
            'average_response_time' => round($query->avg('response_time_ms'), 2),
            'by_provider' => (clone $query)->groupBy('provider')->selectRaw('provider, COUNT(*) as count')->pluck('count', 'provider'),
            'cost_by_provider' => self::totalCostByProvider($startDate, $endDate),
        ];
    }

    /**
     * Calculate cost based on provider and service
     */
    public static function calculateCost(string $provider, string $service, int $creditsUsed = 1): float
    {
        $costs = [
            'twilio' => [
                'lookup_basic' => 0.005,
                'lookup_line_type' => 0.01,
                'lookup_caller_name' => 0.01,
                'lookup_sms_pumping' => 0.01,
                'lookup_sim_swap' => 0.01,
                'sms_send' => 0.0079,
                'voice_call' => 0.0140,
            ],
            'clearbit' => ['enrichment' => 0.10],
            'hunter' => ['email_search' => 0.05, 'email_verify' => 0.01],
            'zerobounce' => ['email_verify' => 0.008],
            'google_places' => ['search' => 0.017, 'details' => 0.017],
            'google_geocoding' => ['geocode' => 0.005],
            'openai' => ['gpt-4' => 0.03, 'gpt-4o-mini' => 0.0015],
            'anthropic' => ['claude-3-5-sonnet' => 0.003, 'claude-3-haiku' => 0.00025],
            'google_ai' => ['gemini-flash' => 0.000075, 'gemini-pro' => 0.00125],
            'whitepages' => ['phone_lookup' => 0.05],
            'yelp' => ['search' => 0.0],
        ];

        $costPerUnit = $costs[$provider][$service] ?? 0.0;
        return $costPerUnit * $creditsUsed;
    }

    /**
     * Log an API call
     */
    public static function logApiCall(array $params): ?self
    {
        try {
            return self::create([
                'contact_id' => $params['contact_id'] ?? null,
                'provider' => $params['provider'],
                'service' => $params['service'],
                'endpoint' => $params['endpoint'] ?? null,
                'cost' => $params['cost'] ?? self::calculateCost($params['provider'], $params['service'], $params['credits_used'] ?? 1),
                'currency' => $params['currency'] ?? 'USD',
                'credits_used' => $params['credits_used'] ?? 1,
                'request_id' => $params['request_id'] ?? null,
                'status' => $params['status'] ?? null,
                'response_time_ms' => $params['response_time_ms'] ?? null,
                'http_status_code' => $params['http_status_code'] ?? null,
                'request_params' => $params['request_params'] ?? [],
                'response_data' => $params['response_data'] ?? [],
                'error_message' => $params['error_message'] ?? null,
                'requested_at' => $params['requested_at'] ?? now(),
            ]);
        } catch (\Exception $e) {
            \Log::error("Failed to log API usage: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Redact sensitive data from request/response
     */
    private function redactSensitiveData(): void
    {
        if (!empty($this->request_params)) {
            $this->request_params = $this->deepRedact($this->request_params);
        }

        if (!empty($this->response_data)) {
            $this->response_data = $this->deepRedact($this->response_data);
        }
    }

    /**
     * Recursively redact sensitive keys
     */
    private function deepRedact($data)
    {
        if (is_array($data)) {
            $result = [];
            foreach ($data as $key => $value) {
                $keyLower = strtolower((string)$key);
                $isSensitive = false;

                foreach (self::SENSITIVE_KEYS as $sensitiveKey) {
                    if (str_contains($keyLower, $sensitiveKey)) {
                        $isSensitive = true;
                        break;
                    }
                }

                $result[$key] = $isSensitive ? '[REDACTED]' : $this->deepRedact($value);
            }
            return $result;
        }

        return $data;
    }
}
