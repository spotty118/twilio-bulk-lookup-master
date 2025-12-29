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
 * BusinessEnrichmentService - Enriches contacts with business intelligence data
 *
 * This service attempts to enrich contact records with business information
 * from multiple providers in order of preference:
 * 1. Clearbit Company API (most comprehensive)
 * 2. NumVerify Phone Intelligence (basic business data)
 * 3. Twilio CNAM (fallback using existing caller ID)
 *
 * All external API calls are protected by circuit breakers to prevent cascade failures.
 *
 * Features:
 * - Multi-provider fallback strategy
 * - Industry classification
 * - Employee count estimation
 * - Revenue range determination
 * - Website discovery
 * - Social media profile discovery
 *
 * Usage:
 *   $result = BusinessEnrichmentService::enrich($contact);
 */
class BusinessEnrichmentService
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
     * Static entry point for enriching contact with business data
     */
    public static function enrich(Contact $contact): bool
    {
        return (new static($contact))->enrichContact();
    }

    /**
     * Main enrichment logic
     */
    public function enrichContact(): bool
    {
        // Only enrich if identified as business by Twilio
        if (!$this->shouldEnrich()) {
            return false;
        }

        try {
            // Try different providers in order of preference
            $result = $this->tryClearbit() ?? $this->tryNumverify() ?? $this->tryTwilioCnam();

            if ($result) {
                $this->updateContactWithBusinessData($result);
                Log::info("[BusinessEnrichmentService] Successfully enriched contact #{$this->contact->id} via {$result['provider']}");
                return true;
            }

            Log::info("[BusinessEnrichmentService] No business data found for {$this->phoneNumber}");
            return false;
        } catch (Exception $e) {
            Log::error("[BusinessEnrichmentService] Error enriching {$this->phoneNumber}: {$e->getMessage()}");
            ErrorTrackingService::captureException($e, [
                'contact_id' => $this->contact->id,
                'phone_number' => $this->phoneNumber,
            ]);
            return false;
        }
    }

    /**
     * Determine if contact should be enriched
     */
    protected function shouldEnrich(): bool
    {
        // Enrich if Twilio identified as business or if we have caller name
        return $this->contact->caller_type === 'business' || !empty($this->contact->caller_name);
    }

    /**
     * Try Clearbit Company API
     */
    protected function tryClearbit(): ?array
    {
        $apiKey = env('CLEARBIT_API_KEY') ?? $this->credentials?->clearbit_api_key;

        if (empty($apiKey) || empty($this->phoneNumber)) {
            return null;
        }

        try {
            // First, try phone lookup
            $data = $this->clearbitPhoneLookup($apiKey);

            // If we have a domain from phone lookup or existing data, enrich company
            if ($data && isset($data['company']['domain'])) {
                $companyData = $this->clearbitCompanyLookup($apiKey, $data['company']['domain']);
                if ($companyData) {
                    $data['company'] = array_merge($data['company'], $companyData);
                }
            }

            return $data ? $this->parseClearbitResponse($data) : null;
        } catch (Exception $e) {
            Log::warning("[BusinessEnrichmentService] Clearbit error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Clearbit phone lookup
     */
    protected function clearbitPhoneLookup(string $apiKey): ?array
    {
        try {
            $response = CircuitBreakerService::call('clearbit', function () use ($apiKey) {
                return $this->httpClient->get('https://prospector.clearbit.com/v1/people/search', [
                    'query' => ['phone' => $this->phoneNumber],
                    'headers' => ['Authorization' => "Bearer {$apiKey}"],
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
            return $data['results'][0] ?? null;
        } catch (Exception $e) {
            Log::warning("[BusinessEnrichmentService] Clearbit phone lookup error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Clearbit company lookup by domain
     */
    protected function clearbitCompanyLookup(string $apiKey, string $domain): ?array
    {
        try {
            $response = CircuitBreakerService::call('clearbit', function () use ($apiKey, $domain) {
                return $this->httpClient->get('https://company.clearbit.com/v2/companies/find', [
                    'query' => ['domain' => $domain],
                    'headers' => ['Authorization' => "Bearer {$apiKey}"],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                return null;
            }

            if ($response->getStatusCode() !== 200) {
                return null;
            }

            return json_decode($response->getBody()->getContents(), true);
        } catch (Exception $e) {
            Log::warning("[BusinessEnrichmentService] Clearbit company lookup error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Parse Clearbit response into standardized format
     */
    protected function parseClearbitResponse(?array $data): ?array
    {
        if (empty($data) || empty($data['company'])) {
            return null;
        }

        $company = $data['company'];

        return [
            'provider' => 'clearbit',
            'is_business' => true,
            'business_name' => $company['name'] ?? null,
            'business_legal_name' => $company['legalName'] ?? null,
            'business_type' => $company['type'] ?? null,
            'business_category' => $company['category']['industry'] ?? null,
            'business_industry' => $company['category']['sector'] ?? null,
            'business_employee_count' => $company['metrics']['employees'] ?? null,
            'business_employee_range' => $this->employeeRangeFromCount($company['metrics']['employees'] ?? null),
            'business_annual_revenue' => $company['metrics']['annualRevenue'] ?? null,
            'business_revenue_range' => $this->revenueRangeFromAmount($company['metrics']['annualRevenue'] ?? null),
            'business_founded_year' => $company['foundedYear'] ?? null,
            'business_address' => trim(implode(' ', array_filter([
                $company['location']['streetNumber'] ?? null,
                $company['location']['street'] ?? null,
            ]))),
            'business_city' => $company['location']['city'] ?? null,
            'business_state' => $company['location']['state'] ?? null,
            'business_country' => $company['location']['country'] ?? null,
            'business_postal_code' => $company['location']['postalCode'] ?? null,
            'business_website' => $company['domain'] ?? null,
            'business_email_domain' => $company['domain'] ?? null,
            'business_linkedin_url' => isset($company['linkedin']['handle'])
                ? "https://linkedin.com/company/{$company['linkedin']['handle']}"
                : null,
            'business_twitter_handle' => $company['twitter']['handle'] ?? null,
            'business_description' => $company['description'] ?? null,
            'business_tags' => isset($company['tags']) ? (array) $company['tags'] : [],
            'business_tech_stack' => $company['tech'] ?? [],
            'business_confidence_score' => 85,
        ];
    }

    /**
     * Try NumVerify phone intelligence API
     */
    protected function tryNumverify(): ?array
    {
        $apiKey = env('NUMVERIFY_API_KEY') ?? $this->credentials?->numverify_api_key;

        if (empty($apiKey) || empty($this->phoneNumber)) {
            return null;
        }

        try {
            $phone = preg_replace('/\D/', '', $this->phoneNumber);

            $response = CircuitBreakerService::call('numverify', function () use ($apiKey, $phone) {
                return $this->httpClient->get('https://apilayer.net/api/validate', [
                    'query' => [
                        'access_key' => $apiKey,
                        'number' => $phone,
                        'format' => 1,
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

            if (!empty($data['valid'])) {
                return $this->parseNumverifyResponse($data);
            }

            return null;
        } catch (Exception $e) {
            Log::warning("[BusinessEnrichmentService] NumVerify error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Parse NumVerify response
     */
    protected function parseNumverifyResponse(array $data): ?array
    {
        // Usually landline indicates business
        if (($data['line_type'] ?? '') !== 'landline') {
            return null;
        }

        return [
            'provider' => 'numverify',
            'is_business' => true,
            'business_name' => $data['carrier'] ?? $this->contact->carrier_name,
            'business_type' => 'unknown',
            'business_country' => $data['country_name'] ?? null,
            'business_confidence_score' => 50,
        ];
    }

    /**
     * Try Twilio CNAM (caller ID) as fallback
     */
    protected function tryTwilioCnam(): ?array
    {
        // Only works for US numbers
        if ($this->contact->country_code !== 'US') {
            return null;
        }

        if (empty($this->contact->caller_name)) {
            return null;
        }

        // Use existing caller name from Twilio as business name
        return [
            'provider' => 'twilio_cnam',
            'is_business' => true,
            'business_name' => $this->contact->caller_name,
            'business_type' => $this->contact->caller_type ?? 'unknown',
            'business_confidence_score' => 70,
        ];
    }

    /**
     * Update contact with business data
     */
    protected function updateContactWithBusinessData(array $data): void
    {
        $updates = array_filter([
            'is_business' => $data['is_business'] ?? null,
            'business_name' => $data['business_name'] ?? null,
            'business_legal_name' => $data['business_legal_name'] ?? null,
            'business_type' => $data['business_type'] ?? null,
            'business_category' => $data['business_category'] ?? null,
            'business_industry' => $data['business_industry'] ?? null,
            'business_employee_count' => $data['business_employee_count'] ?? null,
            'business_employee_range' => $data['business_employee_range'] ?? null,
            'business_annual_revenue' => $data['business_annual_revenue'] ?? null,
            'business_revenue_range' => $data['business_revenue_range'] ?? null,
            'business_founded_year' => $data['business_founded_year'] ?? null,
            'business_address' => $data['business_address'] ?? null,
            'business_city' => $data['business_city'] ?? null,
            'business_state' => $data['business_state'] ?? null,
            'business_country' => $data['business_country'] ?? null,
            'business_postal_code' => $data['business_postal_code'] ?? null,
            'business_website' => $data['business_website'] ?? null,
            'business_email_domain' => $data['business_email_domain'] ?? null,
            'business_linkedin_url' => $data['business_linkedin_url'] ?? null,
            'business_twitter_handle' => $data['business_twitter_handle'] ?? null,
            'business_description' => $data['business_description'] ?? null,
            'business_enriched' => true,
            'business_enrichment_provider' => $data['provider'],
            'business_enriched_at' => now(),
            'business_confidence_score' => $data['business_confidence_score'] ?? null,
        ], function ($value) {
            return $value !== null;
        });

        // Handle array fields separately
        if (isset($data['business_tags'])) {
            $updates['business_tags'] = $data['business_tags'];
        }

        if (isset($data['business_tech_stack'])) {
            $updates['business_tech_stack'] = $data['business_tech_stack'];
        }

        $this->contact->update($updates);
    }

    /**
     * Map employee count to range
     */
    protected function employeeRangeFromCount(?int $count): ?string
    {
        if ($count === null) {
            return null;
        }

        return match (true) {
            $count <= 10 => '1-10',
            $count <= 50 => '11-50',
            $count <= 200 => '51-200',
            $count <= 500 => '201-500',
            $count <= 1000 => '501-1000',
            $count <= 5000 => '1001-5000',
            $count <= 10000 => '5001-10000',
            default => '10000+',
        };
    }

    /**
     * Map revenue amount to range
     */
    protected function revenueRangeFromAmount(?int $amount): ?string
    {
        if ($amount === null) {
            return null;
        }

        return match (true) {
            $amount <= 1_000_000 => '$0-$1M',
            $amount <= 10_000_000 => '$1M-$10M',
            $amount <= 50_000_000 => '$10M-$50M',
            $amount <= 100_000_000 => '$50M-$100M',
            $amount <= 500_000_000 => '$100M-$500M',
            $amount <= 1_000_000_000 => '$500M-$1B',
            default => '$1B+',
        };
    }
}
