<?php

namespace App\Services;

use Twilio\Rest\Client as TwilioClient;
use Twilio\Exceptions\TwilioException;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Models\ApiUsageLog;

class MessagingService
{
    /** @var Contact */
    protected $contact;

    /** @var TwilioCredential */
    protected $credentials;

    /** @var TwilioClient */
    protected $client;

    public function __construct(Contact $contact)
    {
        $this->contact = $contact;
        $this->credentials = TwilioCredential::current();
        $this->client = $this->initializeTwilioClient();
    }

    /**
     * Send SMS message
     */
    public function sendSms(string $messageBody, array $options = []): array
    {
        if (!$this->credentials || !$this->credentials->enable_sms_messaging) {
            return ['success' => false, 'error' => 'SMS messaging not enabled'];
        }

        if (!$this->credentials->twilio_phone_number) {
            return ['success' => false, 'error' => 'No Twilio phone number configured'];
        }

        if ($this->contact->sms_opt_out) {
            return ['success' => false, 'error' => 'Contact has opted out of SMS'];
        }

        if (!$this->contact->formatted_phone_number) {
            return ['success' => false, 'error' => 'Invalid phone number'];
        }

        // Check rate limits (atomic check-and-increment)
        $rateLimitCheck = $this->checkAndConsumeSmsRateLimit();
        if (!$rateLimitCheck['success']) {
            return $rateLimitCheck;
        }

        $startTime = now();

        try {
            $message = $this->client->messages->create(
                $this->contact->formatted_phone_number,
                [
                    'from' => $this->credentials->twilio_phone_number,
                    'body' => $messageBody,
                    'statusCallback' => $options['status_callback'] ?? $this->buildStatusCallbackUrl('sms'),
                ]
            );

            // Update contact
            $this->contact->increment('sms_sent_count');
            $this->contact->update([
                'sms_last_sent_at' => now(),
                'last_engagement_at' => now(),
            ]);

            // Log API usage
            $this->logApiUsage([
                'service' => 'sms_send',
                'status' => 'success',
                'response_time_ms' => (int) (now()->diffInMilliseconds($startTime)),
                'request_params' => ['to' => $this->contact->formatted_phone_number, 'body' => $messageBody],
                'response_data' => ['message_sid' => $message->sid, 'status' => $message->status],
            ]);

            return [
                'success' => true,
                'message_sid' => $message->sid,
                'status' => $message->status,
                'to' => $message->to,
                'from' => $message->from,
            ];
        } catch (TwilioException $e) {
            Log::error("SMS send error for contact {$this->contact->id}: {$e->getMessage()}");

            $this->contact->increment('sms_failed_count');

            $this->logApiUsage([
                'service' => 'sms_send',
                'status' => 'failed',
                'error_message' => $e->getMessage(),
                'response_time_ms' => (int) (now()->diffInMilliseconds($startTime)),
            ]);

            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Send SMS using template
     */
    public function sendSmsFromTemplate(string $templateType = 'intro', array $options = []): array
    {
        if (!$this->credentials) {
            return ['success' => false, 'error' => 'No credentials configured'];
        }

        $template = match ($templateType) {
            'intro' => $this->credentials->sms_intro_template,
            'follow_up' => $this->credentials->sms_follow_up_template,
            default => null,
        };

        if (!$template) {
            return ['success' => false, 'error' => "No template found for type: {$templateType}"];
        }

        // Replace variables in template
        $messageBody = $this->interpolateTemplate($template);

        return $this->sendSms($messageBody, $options);
    }

    /**
     * Send SMS with AI-generated content
     */
    public function sendAiGeneratedSms(string $messageType = 'intro', array $options = []): array
    {
        $llmService = new MultiLlmService();
        $result = $llmService->generateOutreachMessage($this->contact, array_merge($options, ['message_type' => $messageType]));

        if ($result['success']) {
            return $this->sendSms($result['response'], $options);
        }

        return $result;
    }

    /**
     * Batch SMS sending
     */
    public static function sendBulkSms($contacts, string $messageBody, array $options = []): array
    {
        $results = [
            'total' => count($contacts),
            'sent' => 0,
            'failed' => 0,
            'rate_limited' => 0,
            'errors' => [],
        ];

        foreach ($contacts as $contact) {
            $service = new self($contact);
            $result = $service->sendSms($messageBody, $options);

            if ($result['success']) {
                $results['sent']++;
            } elseif (isset($result['error']) && str_contains($result['error'], 'rate limit')) {
                $results['rate_limited']++;
                $results['errors'][] = ['contact_id' => $contact->id, 'error' => $result['error']];
                break; // Stop if rate limited
            } else {
                $results['failed']++;
                $results['errors'][] = ['contact_id' => $contact->id, 'error' => $result['error']];
            }

            usleep(100000); // Small delay between messages (0.1s)
        }

        return $results;
    }

    /**
     * Handle opt-out request
     */
    public function optOutSms(): array
    {
        $this->contact->update([
            'sms_opt_out' => true,
            'sms_opt_out_at' => now(),
        ]);

        Log::info("Contact {$this->contact->id} opted out of SMS");
        return ['success' => true, 'message' => 'Contact opted out of SMS'];
    }

    /**
     * Initialize Twilio client
     */
    private function initializeTwilioClient(): ?TwilioClient
    {
        if (!$this->credentials) {
            return null;
        }

        return new TwilioClient($this->credentials->account_sid, $this->credentials->auth_token);
    }

    /**
     * Check and consume SMS rate limit
     */
    private function checkAndConsumeSmsRateLimit(): array
    {
        $maxPerHour = $this->credentials->max_sms_per_hour ?? 100;
        $cacheKey = 'sms_rate_limit:' . now()->format('Y-m-d-H');

        // Atomic increment
        $currentCount = Cache::increment($cacheKey, 1);
        if (!$currentCount) {
            Cache::put($cacheKey, 1, now()->addHour());
            $currentCount = 1;
        }

        if ($currentCount > $maxPerHour) {
            return ['success' => false, 'error' => "Rate limit exceeded: {$currentCount}/{$maxPerHour} SMS attempts in the last hour"];
        }

        return ['success' => true];
    }

    /**
     * Build status callback URL
     */
    private function buildStatusCallbackUrl(string $type): ?string
    {
        $host = config('app.url') ?? $this->credentials?->webhook_base_url ?? env('APP_HOST');

        if (!$host) {
            return null;
        }

        return match ($type) {
            'sms' => "{$host}/webhooks/twilio/sms_status",
            'voice' => "{$host}/webhooks/twilio/voice_status",
            default => null,
        };
    }

    /**
     * Interpolate template variables
     */
    private function interpolateTemplate(string $template): string
    {
        // Allowlist of safe fields
        $safeFields = [
            'first_name', 'last_name', 'full_name', 'email', 'formatted_phone_number',
            'business_name', 'business_industry', 'business_city', 'business_state',
            'position', 'department', 'caller_name',
        ];

        return preg_replace_callback('/\{\{(\w+)\}\}/', function ($matches) use ($safeFields) {
            $field = $matches[1];
            if (in_array($field, $safeFields)) {
                return $this->contact->$field ?? '';
            }

            Log::warning("Attempted to interpolate unsafe field in template: {$field}");
            return "{{$field}}";
        }, $template);
    }

    /**
     * Log API usage
     */
    private function logApiUsage(array $params): void
    {
        ApiUsageLog::logApiCall([
            'contact_id' => $this->contact->id,
            'provider' => 'twilio',
            'service' => $params['service'],
            'status' => $params['status'],
            'response_time_ms' => $params['response_time_ms'],
            'request_params' => $params['request_params'] ?? null,
            'response_data' => $params['response_data'] ?? null,
            'error_message' => $params['error_message'] ?? null,
            'requested_at' => now(),
        ]);
    }
}
