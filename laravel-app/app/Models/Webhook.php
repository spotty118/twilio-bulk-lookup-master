<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;

class Webhook extends Model
{
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<string>
     */
    protected $fillable = [
        'contact_id',
        'source',
        'event_type',
        'external_id',
        'payload',
        'headers',
        'status',
        'processed_at',
        'processing_error',
        'retry_count',
        'received_at',
        'idempotency_key',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'payload' => 'array',
        'headers' => 'array',
        'processed_at' => 'datetime',
        'received_at' => 'datetime',
    ];

    /**
     * Boot method for model events
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($webhook) {
            if (empty($webhook->idempotency_key)) {
                $webhook->generateIdempotencyKey();
            }
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
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    public function scopeProcessing($query)
    {
        return $query->where('status', 'processing');
    }

    public function scopeProcessed($query)
    {
        return $query->where('status', 'processed');
    }

    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    public function scopeUnprocessed($query)
    {
        return $query->whereIn('status', ['pending', 'failed']);
    }

    public function scopeRecent($query)
    {
        return $query->where('received_at', '>=', now()->subDay());
    }

    public function scopeTrustHub($query)
    {
        return $query->where('source', 'twilio_trust_hub');
    }

    public function scopeSmsStatus($query)
    {
        return $query->where('source', 'twilio_sms');
    }

    public function scopeVoiceStatus($query)
    {
        return $query->where('source', 'twilio_voice');
    }

    /**
     * Generate idempotency key from source + external_id
     */
    private function generateIdempotencyKey(): void
    {
        if (!empty($this->external_id)) {
            $this->idempotency_key = "{$this->source}:{$this->external_id}";
        } else {
            // Fallback: Use hash of payload if external_id is missing
            $payloadHash = substr(hash('sha256', json_encode($this->payload ?? [])), 0, 32);
            $this->idempotency_key = "{$this->source}:hash:{$payloadHash}";
            \Log::warning('Webhook created without external_id, using payload hash for idempotency');
        }
    }

    /**
     * Process this webhook
     */
    public function process(): void
    {
        DB::transaction(function () {
            // Lock row to prevent concurrent processing
            $this->lockForUpdate();

            if ($this->status === 'processed') {
                return;
            }

            $this->update(['status' => 'processing']);

            try {
                switch ($this->source) {
                    case 'twilio_trust_hub':
                        $this->processTrustHubWebhook();
                        break;
                    case 'twilio_sms':
                        $this->processSmsWebhook();
                        break;
                    case 'twilio_voice':
                        $this->processVoiceWebhook();
                        break;
                    default:
                        throw new \Exception("Unknown webhook source: {$this->source}");
                }

                $this->update([
                    'status' => 'processed',
                    'processed_at' => now(),
                ]);
            } catch (\Exception $e) {
                $this->update([
                    'status' => 'failed',
                    'processing_error' => $e->getMessage(),
                    'retry_count' => ($this->retry_count ?? 0) + 1,
                ]);
                \Log::error("Webhook processing failed: {$e->getMessage()}");
                throw $e;
            }
        });
    }

    /**
     * Process Trust Hub webhook
     */
    private function processTrustHubWebhook(): void
    {
        $trustHubSid = $this->payload['customer_profile_sid'] ?? 
                       $this->payload['CustomerProfileSid'] ?? 
                       $this->external_id;
        $status = $this->payload['status'] ?? $this->payload['Status'];

        if (empty($trustHubSid)) {
            return;
        }

        $contact = Contact::where('trust_hub_customer_profile_sid', $trustHubSid)->first();

        if ($contact) {
            $contact->update([
                'trust_hub_status' => $status,
                'trust_hub_verified' => in_array($status, ['twilio-approved', 'compliant']),
                'trust_hub_verification_score' => $this->calculateTrustHubScore($status),
                'trust_hub_enriched_at' => now(),
            ]);

            $this->update(['contact_id' => $contact->id]);

            \Log::info("Trust Hub webhook processed for contact {$contact->id}: {$status}");
        } else {
            \Log::warning("No contact found for Trust Hub SID: {$trustHubSid}");
        }
    }

    /**
     * Process SMS webhook
     */
    private function processSmsWebhook(): void
    {
        $toNumber = $this->payload['To'] ?? null;

        if (empty($toNumber)) {
            return;
        }

        $contact = Contact::where('formatted_phone_number', $toNumber)
                         ->orWhere('raw_phone_number', $toNumber)
                         ->first();

        if (!$contact) {
            return;
        }

        $messageStatus = $this->payload['MessageStatus'] ?? null;

        // Update SMS tracking using atomic operations
        switch ($messageStatus) {
            case 'delivered':
                $contact->increment('sms_delivered_count');
                break;
            case 'failed':
            case 'undelivered':
                $contact->increment('sms_failed_count');
                break;
        }

        $contact->update(['last_engagement_at' => now()]);
        $this->update(['contact_id' => $contact->id]);

        \Log::info("SMS webhook processed for contact {$contact->id}: {$messageStatus}");
    }

    /**
     * Process voice webhook
     */
    private function processVoiceWebhook(): void
    {
        $toNumber = $this->payload['To'] ?? null;

        if (empty($toNumber)) {
            return;
        }

        $contact = Contact::where('formatted_phone_number', $toNumber)
                         ->orWhere('raw_phone_number', $toNumber)
                         ->first();

        if (!$contact) {
            return;
        }

        $callStatus = $this->payload['CallStatus'] ?? null;

        // Update voice tracking using atomic operations
        if ($callStatus === 'completed') {
            if (($this->payload['AnsweredBy'] ?? null) === 'human') {
                $contact->increment('voice_answered_count');
            } else {
                $contact->increment('voice_voicemail_count');
            }
        }

        $contact->update([
            'voice_last_called_at' => now(),
            'last_engagement_at' => now(),
        ]);
        $this->update(['contact_id' => $contact->id]);

        \Log::info("Voice webhook processed for contact {$contact->id}: {$callStatus}");
    }

    /**
     * Calculate Trust Hub score based on status
     */
    private function calculateTrustHubScore(string $status): int
    {
        return match ($status) {
            'draft' => 10,
            'pending-review' => 50,
            'in-review' => 60,
            'twilio-rejected', 'rejected' => 0,
            'twilio-approved' => 100,
            'compliant' => 95,
            default => 0,
        };
    }

    /**
     * Retry failed webhooks (static method)
     */
    public static function retryFailed(): void
    {
        self::failed()
            ->where('retry_count', '<', 3)
            ->each(function ($webhook) {
                try {
                    $webhook->process();
                } catch (\Exception $e) {
                    \Log::error("Failed to retry webhook {$webhook->id}: {$e->getMessage()}");
                }
            });
    }

    /**
     * Process pending webhooks (static method)
     */
    public static function processPending(): void
    {
        self::pending()
            ->orderBy('received_at')
            ->limit(100)
            ->each(function ($webhook) {
                try {
                    $webhook->process();
                } catch (\Exception $e) {
                    \Log::error("Failed to process webhook {$webhook->id}: {$e->getMessage()}");
                }
            });
    }
}
