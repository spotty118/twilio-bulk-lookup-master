<?php

namespace App\Services;

use GuzzleHttp\Client as GuzzleClient;
use GuzzleHttp\Exception\GuzzleException;
use GuzzleHttp\Exception\RequestException;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use App\Models\Contact;
use App\Models\TwilioCredential;
use Exception;

/**
 * EmailEnrichmentService - Enriches contacts with email addresses and verification
 *
 * This service attempts to find and verify email addresses for contacts using:
 * 1. Hunter.io Email Finder (primary - phone search + email finder)
 * 2. Domain pattern matching (educated guess based on name)
 * 3. Clearbit Email Finder (premium)
 * 4. ZeroBounce Email Verification (validation)
 *
 * All external API calls are protected by circuit breakers to prevent cascade failures.
 *
 * Features:
 * - Email discovery by phone number
 * - Email discovery by domain + name
 * - Pattern-based email guessing
 * - Email verification and deliverability scoring
 * - Professional contact discovery (LinkedIn, position, department)
 * - Email validation and normalization
 *
 * Usage:
 *   $result = EmailEnrichmentService::enrich($contact);
 */
class EmailEnrichmentService
{
    /** @var Contact */
    protected $contact;

    /** @var string|null */
    protected $phoneNumber;

    /** @var TwilioCredential|null */
    protected $credentials;

    /** @var GuzzleClient */
    protected $httpClient;

    public function __construct(Contact $contact)
    {
        $this->contact = $contact;
        $this->phoneNumber = $contact->formatted_phone_number ?? $contact->raw_phone_number;
        $this->credentials = TwilioCredential::current();
        $this->httpClient = new GuzzleClient([
            'timeout' => 10,
            'connect_timeout' => 5,
            'headers' => [
                'User-Agent' => 'TwilioBulkLookup/2.0 Laravel',
            ],
        ]);
    }

    /**
     * Static entry point for email enrichment
     */
    public static function enrich(Contact $contact): bool
    {
        return (new static($contact))->enrichEmail();
    }

    /**
     * Main enrichment logic
     */
    public function enrichEmail(): bool
    {
        // Skip if already enriched
        if ($this->contact->email_enriched) {
            return false;
        }

        // Skip if no business data to work with
        if (!$this->contact->business_enriched && empty($this->contact->business_email_domain)) {
            Log::info("[EmailEnrichmentService] No business context for email finding: contact {$this->contact->id}");
            return false;
        }

        try {
            // Try to find email
            $result = $this->tryHunterFind() ?? $this->tryDomainPattern() ?? $this->tryClearbitEmail();

            if ($result && !empty($result['email'])) {
                // Verify email if found
                $verifiedResult = $this->verifyEmail($result['email']);
                if ($verifiedResult) {
                    $result = array_merge($result, $verifiedResult);
                }

                $this->updateContactWithEmailData($result);
                Log::info("[EmailEnrichmentService] Successfully enriched contact #{$this->contact->id} with email via {$result['provider']}");
                return true;
            }

            Log::info("[EmailEnrichmentService] No email found for contact {$this->contact->id}");
            return false;
        } catch (Exception $e) {
            Log::error("[EmailEnrichmentService] Error enriching email for {$this->contact->id}: {$e->getMessage()}");
            ErrorTrackingService::captureException($e, [
                'contact_id' => $this->contact->id,
                'phone_number' => $this->phoneNumber,
            ]);
            return false;
        }
    }

    /**
     * Try Hunter.io email finder
     */
    protected function tryHunterFind(): ?array
    {
        $apiKey = env('HUNTER_API_KEY') ?? $this->credentials?->hunter_api_key;

        if (empty($apiKey)) {
            return null;
        }

        try {
            // First try: Find by phone number
            $result = $this->hunterPhoneSearch($apiKey);
            if ($result) {
                return $result;
            }

            // Second try: Find by domain + name
            if (!empty($this->contact->business_email_domain) && !empty($this->contact->full_name)) {
                $result = $this->hunterEmailFinder($apiKey);
                if ($result) {
                    return $result;
                }
            }

            return null;
        } catch (Exception $e) {
            Log::warning("[EmailEnrichmentService] Hunter.io error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Hunter.io phone search
     */
    protected function hunterPhoneSearch(string $apiKey): ?array
    {
        try {
            $response = CircuitBreakerService::call('hunter', function () use ($apiKey) {
                return $this->httpClient->get('https://api.hunter.io/v2/phone-search', [
                    'query' => [
                        'phone' => $this->phoneNumber,
                        'api_key' => $apiKey,
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return null;
            }

            if ($response->getStatusCode() !== 200) {
                return null;
            }

            $data = json_decode($response->getBody()->getContents(), true);

            if (!empty($data['data']['email'])) {
                return $this->parseHunterResponse($data['data']);
            }

            return null;
        } catch (Exception $e) {
            Log::warning("[EmailEnrichmentService] Hunter phone search error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Hunter.io email finder by domain + name
     */
    protected function hunterEmailFinder(string $apiKey): ?array
    {
        try {
            // Parse first and last name
            $nameParts = explode(' ', $this->contact->full_name ?? '');
            $firstName = $nameParts[0] ?? '';
            $lastName = count($nameParts) > 1 ? end($nameParts) : '';

            $response = CircuitBreakerService::call('hunter', function () use ($apiKey, $firstName, $lastName) {
                return $this->httpClient->get('https://api.hunter.io/v2/email-finder', [
                    'query' => [
                        'domain' => $this->contact->business_email_domain,
                        'first_name' => $firstName,
                        'last_name' => $lastName,
                        'api_key' => $apiKey,
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return null;
            }

            if ($response->getStatusCode() !== 200) {
                return null;
            }

            $data = json_decode($response->getBody()->getContents(), true);

            if (!empty($data['data']['email'])) {
                return $this->parseHunterResponse($data['data']);
            }

            return null;
        } catch (Exception $e) {
            Log::warning("[EmailEnrichmentService] Hunter email finder error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Parse Hunter.io response
     */
    protected function parseHunterResponse(array $data): array
    {
        return [
            'provider' => 'hunter',
            'email' => $data['email'] ?? null,
            'email_score' => $data['score'] ?? null,
            'email_verified' => isset($data['verification']) && ($data['verification']['status'] ?? '') === 'valid',
            'email_status' => $data['verification']['status'] ?? 'unknown',
            'first_name' => $data['first_name'] ?? null,
            'last_name' => $data['last_name'] ?? null,
            'full_name' => trim(implode(' ', array_filter([
                $data['first_name'] ?? null,
                $data['last_name'] ?? null,
            ]))),
            'position' => $data['position'] ?? null,
            'department' => $data['department'] ?? null,
            'seniority' => $data['seniority'] ?? null,
            'linkedin_url' => $data['linkedin'] ?? null,
            'twitter_url' => $data['twitter'] ?? null,
        ];
    }

    /**
     * Try domain pattern matching (educated guess)
     */
    protected function tryDomainPattern(): ?array
    {
        if (empty($this->contact->business_email_domain)) {
            return null;
        }

        $name = $this->contact->full_name ?? $this->contact->caller_name;
        if (empty($name)) {
            return null;
        }

        $nameParts = array_filter(explode(' ', strtolower($name)));

        if (empty($nameParts)) {
            return null;
        }

        // Handle single-name contacts (e.g., "Madonna", "Prince")
        if (count($nameParts) < 2) {
            $first = $nameParts[0];
            $patterns = [
                "{$first}@{$this->contact->business_email_domain}",
                "info@{$this->contact->business_email_domain}",
                "contact@{$this->contact->business_email_domain}",
            ];

            return [
                'provider' => 'pattern_guess',
                'email' => $patterns[0],
                'email_score' => 20, // Lower confidence for single name
                'email_verified' => false,
                'email_status' => 'unverified',
                'first_name' => ucfirst($nameParts[0]),
                'last_name' => null,
                'full_name' => $name,
            ];
        }

        $first = $nameParts[0];
        $last = end($nameParts);

        // Common patterns for multi-part names
        $patterns = [
            "{$first}.{$last}@{$this->contact->business_email_domain}",
            "{$first}{$last}@{$this->contact->business_email_domain}",
            substr($first, 0, 1) . "{$last}@{$this->contact->business_email_domain}",
            "{$first}@{$this->contact->business_email_domain}",
        ];

        // Return first pattern as guess
        return [
            'provider' => 'pattern_guess',
            'email' => $patterns[0],
            'email_score' => 30, // Low confidence
            'email_verified' => false,
            'email_status' => 'unverified',
            'first_name' => ucfirst($nameParts[0]),
            'last_name' => ucfirst($last),
            'full_name' => $name,
        ];
    }

    /**
     * Try Clearbit email finder (premium)
     */
    protected function tryClearbitEmail(): ?array
    {
        $apiKey = env('CLEARBIT_API_KEY') ?? $this->credentials?->clearbit_api_key;

        if (empty($apiKey) || empty($this->contact->business_email_domain) || empty($this->contact->full_name)) {
            return null;
        }

        try {
            $nameParts = array_filter(explode(' ', $this->contact->full_name));
            $firstName = $nameParts[0] ?? '';
            $lastName = count($nameParts) > 1 ? end($nameParts) : '';

            $response = CircuitBreakerService::call('clearbit', function () use ($apiKey, $firstName, $lastName, $nameParts) {
                return $this->httpClient->get('https://person.clearbit.com/v2/combined/find', [
                    'query' => [
                        'email' => "{$nameParts[0]}@{$this->contact->business_email_domain}",
                        'given_name' => $firstName,
                        'family_name' => $lastName,
                    ],
                    'headers' => [
                        'Authorization' => "Bearer {$apiKey}",
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return null;
            }

            if ($response->getStatusCode() !== 200) {
                return null;
            }

            $data = json_decode($response->getBody()->getContents(), true);

            if (!empty($data['email'])) {
                return $this->parseClearbitEmailResponse($data);
            }

            return null;
        } catch (Exception $e) {
            Log::warning("[EmailEnrichmentService] Clearbit email finder error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Parse Clearbit email response
     */
    protected function parseClearbitEmailResponse(array $data): array
    {
        return [
            'provider' => 'clearbit',
            'email' => $data['email'] ?? null,
            'email_score' => 85,
            'email_verified' => true,
            'email_status' => 'valid',
            'first_name' => $data['givenName'] ?? null,
            'last_name' => $data['familyName'] ?? null,
            'full_name' => $data['name'] ?? null,
            'position' => $data['employment']['title'] ?? null,
            'linkedin_url' => isset($data['linkedin']['handle'])
                ? "https://linkedin.com/in/{$data['linkedin']['handle']}"
                : null,
            'twitter_url' => isset($data['twitter']['handle'])
                ? "https://twitter.com/{$data['twitter']['handle']}"
                : null,
            'facebook_url' => isset($data['facebook']['handle'])
                ? "https://facebook.com/{$data['facebook']['handle']}"
                : null,
        ];
    }

    /**
     * Verify email with ZeroBounce or Hunter
     */
    protected function verifyEmail(string $email): ?array
    {
        // Try ZeroBounce first (best verification)
        $result = $this->verifyWithZerobounce($email);
        if ($result) {
            return $result;
        }

        // Try Hunter verification
        $result = $this->verifyWithHunter($email);
        if ($result) {
            return $result;
        }

        return null;
    }

    /**
     * Verify email with ZeroBounce
     */
    protected function verifyWithZerobounce(string $email): ?array
    {
        $apiKey = env('ZEROBOUNCE_API_KEY') ?? $this->credentials?->zerobounce_api_key;

        if (empty($apiKey)) {
            return null;
        }

        try {
            $response = CircuitBreakerService::call('zerobounce', function () use ($apiKey, $email) {
                return $this->httpClient->get('https://api.zerobounce.net/v2/validate', [
                    'query' => [
                        'api_key' => $apiKey,
                        'email' => $email,
                        'ip_address' => '',
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return null;
            }

            if ($response->getStatusCode() !== 200) {
                return null;
            }

            $data = json_decode($response->getBody()->getContents(), true);

            return [
                'email_verified' => ($data['status'] ?? '') === 'valid',
                'email_status' => $data['status'] ?? 'unknown',
                'email_score' => $this->scoreFromStatus($data['status'] ?? ''),
                'email_type' => $data['sub_status'] ?? null,
            ];
        } catch (Exception $e) {
            Log::warning("[EmailEnrichmentService] ZeroBounce verification error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Verify email with Hunter
     */
    protected function verifyWithHunter(string $email): ?array
    {
        $apiKey = env('HUNTER_API_KEY') ?? $this->credentials?->hunter_api_key;

        if (empty($apiKey)) {
            return null;
        }

        try {
            $response = CircuitBreakerService::call('hunter', function () use ($apiKey, $email) {
                return $this->httpClient->get('https://api.hunter.io/v2/email-verifier', [
                    'query' => [
                        'email' => $email,
                        'api_key' => $apiKey,
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return null;
            }

            if ($response->getStatusCode() !== 200) {
                return null;
            }

            $data = json_decode($response->getBody()->getContents(), true);
            $verification = $data['data'] ?? [];

            return [
                'email_verified' => ($verification['status'] ?? '') === 'valid',
                'email_status' => $verification['status'] ?? 'unknown',
                'email_score' => $verification['score'] ?? null,
                'email_type' => $verification['result'] ?? null,
            ];
        } catch (Exception $e) {
            Log::warning("[EmailEnrichmentService] Hunter verification error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Convert verification status to numeric score
     */
    protected function scoreFromStatus(string $status): int
    {
        return match ($status) {
            'valid' => 100,
            'catch-all' => 70,
            'unknown' => 50,
            'spamtrap' => 10,
            'abuse' => 5,
            'do_not_mail' => 0,
            default => 50,
        };
    }

    /**
     * Update contact with email data
     */
    protected function updateContactWithEmailData(array $data): void
    {
        $updates = array_filter([
            'email' => $data['email'] ?? null,
            'email_verified' => $data['email_verified'] ?? null,
            'email_score' => $data['email_score'] ?? null,
            'email_status' => $data['email_status'] ?? null,
            'email_type' => $data['email_type'] ?? null,
            'email_enriched' => true,
            'email_enrichment_provider' => $data['provider'] ?? null,
            'email_enriched_at' => now(),
            'first_name' => $data['first_name'] ?? $this->contact->first_name,
            'last_name' => $data['last_name'] ?? $this->contact->last_name,
            'full_name' => $data['full_name'] ?? $this->contact->full_name,
            'position' => $data['position'] ?? $this->contact->position,
            'department' => $data['department'] ?? $this->contact->department,
            'seniority' => $data['seniority'] ?? $this->contact->seniority,
            'linkedin_url' => $data['linkedin_url'] ?? $this->contact->linkedin_url,
            'twitter_url' => $data['twitter_url'] ?? $this->contact->twitter_url,
            'facebook_url' => $data['facebook_url'] ?? $this->contact->facebook_url,
        ], function ($value) {
            return $value !== null;
        });

        $this->contact->update($updates);
    }
}
