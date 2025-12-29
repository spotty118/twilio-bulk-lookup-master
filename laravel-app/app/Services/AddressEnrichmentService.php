<?php

namespace App\Services;

use App\Models\Contact;
use App\Models\TwilioCredential;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * AddressEnrichmentService - Enriches consumer contacts with address data
 *
 * This service attempts to find physical addresses for consumer contacts using:
 * 1. Whitepages Pro (best for US addresses)
 * 2. TrueCaller (good for mobile numbers)
 * 3. Existing data fallback (country/state level)
 *
 * All external API calls are protected by circuit breakers to prevent cascade failures.
 *
 * Usage:
 *   $service = new AddressEnrichmentService($contact);
 *   $service->enrich();
 */
class AddressEnrichmentService
{
    private Contact $contact;
    private ?TwilioCredential $credentials;
    private Client $httpClient;

    /**
     * API Endpoints
     */
    private const WHITEPAGES_API_URL = 'https://proapi.whitepages.com/3.0/phone';
    private const TRUECALLER_API_URL = 'https://api4.truecaller.com/v1/search';

    /**
     * Cache TTL - 30 days
     */
    private const CACHE_TTL = 60 * 60 * 24 * 30;

    public function __construct(Contact $contact)
    {
        $this->contact = $contact;
        $this->credentials = TwilioCredential::current();
        $this->httpClient = new Client([
            'timeout' => 10,
            'headers' => [
                'User-Agent' => 'TwilioBulkLookup/1.0',
            ],
        ]);
    }

    /**
     * Main entry point - enrich contact with address data
     *
     * @return bool Success status
     */
    public function enrich(): bool
    {
        // Only enrich consumers (not businesses)
        if (!$this->contact->isConsumer()) {
            Log::info("[AddressEnrichmentService] Skipping {$this->contact->id}: Not a consumer contact");
            return false;
        }

        // Skip if already enriched
        if ($this->contact->address_enriched) {
            Log::info("[AddressEnrichmentService] Skipping {$this->contact->id}: Already enriched");
            return false;
        }

        // Must have a phone number
        if (empty($this->contact->raw_phone_number)) {
            Log::warning("[AddressEnrichmentService] Skipping {$this->contact->id}: No phone number");
            return false;
        }

        Log::info("[AddressEnrichmentService] Starting address enrichment for contact {$this->contact->id}");

        try {
            $addressData = $this->findAddress();

            if ($addressData) {
                $this->updateContactAddress($addressData);
                Log::info("[AddressEnrichmentService] Successfully enriched address for contact {$this->contact->id}");
                return true;
            }

            Log::warning("[AddressEnrichmentService] No address found for contact {$this->contact->id}");
            return false;
        } catch (\Exception $e) {
            Log::error("[AddressEnrichmentService] Error enriching {$this->contact->id}: {$e->getMessage()}");
            return false;
        }
    }

    /**
     * Find address using multiple data sources
     *
     * @return array|null Address data or null if not found
     */
    private function findAddress(): ?array
    {
        // Try providers in order of data quality

        // 1. Try Whitepages Pro (best for US addresses)
        if (!empty($this->credentials->whitepages_api_key)) {
            $addressData = $this->tryWhitepages();
            if ($addressData) {
                return $addressData;
            }
        }

        // 2. Try TrueCaller (good for mobile)
        if (!empty($this->credentials->truecaller_api_key)) {
            $addressData = $this->tryTruecaller();
            if ($addressData) {
                return $addressData;
            }
        }

        // 3. Fallback: Extract from existing data
        return $this->extractFromExistingData();
    }

    /**
     * Try Whitepages Pro API
     *
     * @return array|null Address data or null
     */
    private function tryWhitepages(): ?array
    {
        $phone = $this->normalizePhone($this->contact->raw_phone_number);
        $cacheKey = "whitepages_address:{$phone}";

        // Check cache first
        $cached = Cache::get($cacheKey);
        if ($cached !== null) {
            return $cached ?: null;
        }

        try {
            // Use circuit breaker for Whitepages API
            $result = CircuitBreakerService::call('whitepages', function () use ($phone) {
                return $this->httpClient->get(self::WHITEPAGES_API_URL, [
                    'query' => [
                        'phone' => $phone,
                        'api_key' => $this->credentials->whitepages_api_key,
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($result) && isset($result['circuit_open'])) {
                return null;
            }

            $data = json_decode($result->getBody()->getContents(), true);

            // Extract address from belongs_to -> current_addresses
            $belongsTo = $data['belongs_to'][0] ?? null;
            if (!$belongsTo) {
                Cache::put($cacheKey, false, self::CACHE_TTL);
                return null;
            }

            $currentAddress = $belongsTo['current_addresses'][0] ?? null;
            if (!$currentAddress) {
                Cache::put($cacheKey, false, self::CACHE_TTL);
                return null;
            }

            $addressData = $this->parseWhitepagesAddress($currentAddress, $belongsTo);
            Cache::put($cacheKey, $addressData, self::CACHE_TTL);
            return $addressData;
        } catch (GuzzleException $e) {
            Log::error("[AddressEnrichmentService] Whitepages error: {$e->getMessage()}");
            Cache::put($cacheKey, false, 3600); // Cache failures for 1 hour
            return null;
        } catch (\Exception $e) {
            Log::error("[AddressEnrichmentService] Whitepages parsing error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Parse Whitepages API response
     *
     * @param array $addressData Address data from API
     * @param array $personData Person data from API
     * @return array Normalized address data
     */
    private function parseWhitepagesAddress(array $addressData, array $personData): array
    {
        return [
            'address' => $addressData['street_line_1'] ?? null,
            'city' => $addressData['city'] ?? null,
            'state' => $addressData['state_code'] ?? null,
            'postal_code' => $addressData['postal_code'] ?? null,
            'country' => $addressData['country_code'] ?? 'US',
            'address_type' => $addressData['location_type'] ?? null,
            'verified' => ($addressData['is_valid'] ?? false) === true,
            'confidence_score' => $this->calculateConfidence($addressData),
            'provider' => 'whitepages',
            'first_name' => $personData['names'][0]['first_name'] ?? null,
            'last_name' => $personData['names'][0]['last_name'] ?? null,
        ];
    }

    /**
     * Try TrueCaller API
     *
     * @return array|null Address data or null
     */
    private function tryTruecaller(): ?array
    {
        $phone = $this->normalizePhone($this->contact->raw_phone_number);
        $cacheKey = "truecaller_address:{$phone}";

        // Check cache first
        $cached = Cache::get($cacheKey);
        if ($cached !== null) {
            return $cached ?: null;
        }

        try {
            // Use circuit breaker for TrueCaller API
            $result = CircuitBreakerService::call('truecaller', function () use ($phone) {
                return $this->httpClient->get(self::TRUECALLER_API_URL, [
                    'query' => [
                        'q' => $phone,
                        'countryCode' => 'US',
                        'type' => 'phone',
                    ],
                    'headers' => [
                        'Authorization' => "Bearer {$this->credentials->truecaller_api_key}",
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($result) && isset($result['circuit_open'])) {
                return null;
            }

            $data = json_decode($result->getBody()->getContents(), true);
            $addressData = $data['data'][0]['addresses'][0] ?? null;

            if (!$addressData) {
                Cache::put($cacheKey, false, self::CACHE_TTL);
                return null;
            }

            $nameData = $data['data'][0]['name'] ?? [];
            $parsedData = [
                'address' => $addressData['street'] ?? null,
                'city' => $addressData['city'] ?? null,
                'state' => $addressData['state'] ?? null,
                'postal_code' => $addressData['zipCode'] ?? null,
                'country' => $addressData['countryCode'] ?? 'US',
                'address_type' => $addressData['type'] ?? null,
                'verified' => true,
                'confidence_score' => 80,
                'provider' => 'truecaller',
                'first_name' => $nameData['first'] ?? null,
                'last_name' => $nameData['last'] ?? null,
            ];

            Cache::put($cacheKey, $parsedData, self::CACHE_TTL);
            return $parsedData;
        } catch (GuzzleException $e) {
            Log::error("[AddressEnrichmentService] TrueCaller error: {$e->getMessage()}");
            Cache::put($cacheKey, false, 3600); // Cache failures for 1 hour
            return null;
        } catch (\Exception $e) {
            Log::error("[AddressEnrichmentService] TrueCaller parsing error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Extract address from existing contact data
     *
     * @return array|null Basic address data or null
     */
    private function extractFromExistingData(): ?array
    {
        // If we have caller name data with location info from Twilio
        // Or if NumVerify gave us location data
        if (empty($this->contact->country_code)) {
            return null;
        }

        // Very basic fallback - just country/state level
        return [
            'city' => null,
            'state' => null,
            'postal_code' => null,
            'country' => $this->contact->country_code,
            'address_type' => 'unknown',
            'verified' => false,
            'confidence_score' => 20,
            'provider' => 'twilio_basic',
        ];
    }

    /**
     * Update contact with address data
     *
     * @param array $addressData Address data to save
     * @return void
     */
    private function updateContactAddress(array $addressData): void
    {
        $updates = [
            'consumer_address' => $addressData['address'] ?? null,
            'consumer_city' => $addressData['city'] ?? null,
            'consumer_state' => $addressData['state'] ?? null,
            'consumer_postal_code' => $addressData['postal_code'] ?? null,
            'consumer_country' => $addressData['country'] ?? 'USA',
            'address_type' => $addressData['address_type'] ?? null,
            'address_verified' => $addressData['verified'] ?? false,
            'address_enriched' => true,
            'address_enrichment_provider' => $addressData['provider'] ?? null,
            'address_enriched_at' => now(),
            'address_confidence_score' => $addressData['confidence_score'] ?? 0,
        ];

        // Also update name fields if we got them and they're empty
        if (!empty($addressData['first_name']) && empty($this->contact->first_name)) {
            $updates['first_name'] = $addressData['first_name'];
        }

        if (!empty($addressData['last_name']) && empty($this->contact->last_name)) {
            $updates['last_name'] = $addressData['last_name'];
        }

        $this->contact->update($updates);
        $this->contact->calculateQualityScore();

        // Trigger Verizon coverage check if address is good enough
        if ($this->shouldCheckVerizonCoverage()) {
            // Queue job for Verizon coverage check
            dispatch(new \App\Jobs\VerizonCoverageCheckJob($this->contact->id));
        }
    }

    /**
     * Check if we should trigger Verizon coverage check
     *
     * @return bool
     */
    private function shouldCheckVerizonCoverage(): bool
    {
        // Only check if we have a full address with confidence >= 60
        return !empty($this->contact->consumer_address)
            && !empty($this->contact->consumer_city)
            && !empty($this->contact->consumer_state)
            && !empty($this->contact->consumer_postal_code)
            && ($this->contact->address_confidence_score ?? 0) >= 60
            && ($this->credentials->enable_verizon_coverage_check ?? false);
    }

    /**
     * Normalize phone number for API calls
     *
     * @param string|null $phone Raw phone number
     * @return string|null Normalized phone number
     */
    private function normalizePhone(?string $phone): ?string
    {
        if (empty($phone)) {
            return null;
        }

        // Remove non-digits
        $digits = preg_replace('/\D/', '', $phone);

        // Only remove leading 1 if it's an 11-digit number (US country code)
        if (strlen($digits) === 11 && $digits[0] === '1') {
            return substr($digits, 1);
        }

        return $digits;
    }

    /**
     * Calculate confidence score based on data completeness
     *
     * @param array $addressData Address data from API
     * @return int Confidence score (0-100)
     */
    private function calculateConfidence(array $addressData): int
    {
        $score = 0;

        if (!empty($addressData['street_line_1'])) {
            $score += 20;
        }
        if (!empty($addressData['city'])) {
            $score += 20;
        }
        if (!empty($addressData['state_code'])) {
            $score += 20;
        }
        if (!empty($addressData['postal_code'])) {
            $score += 20;
        }
        if (($addressData['is_valid'] ?? false) === true) {
            $score += 20;
        }

        return $score;
    }
}
