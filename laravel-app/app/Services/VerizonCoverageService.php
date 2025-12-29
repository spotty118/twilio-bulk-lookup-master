<?php

namespace App\Services;

use App\Models\Contact;
use App\Models\TwilioCredential;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * VerizonCoverageService - Check 5G/LTE Home Internet availability
 *
 * Enhanced service using Guzzle HTTP client with multiple fallback strategies:
 * 1. Verizon FWA API (if credentials available)
 * 2. FCC broadband data API
 * 3. Location-based estimation using geocoding
 *
 * Provides coverage data for:
 * - Verizon 5G Home Internet
 * - Verizon LTE Home Internet
 * - Verizon Fios
 * - Speed estimates
 *
 * Usage:
 *   $service = new VerizonCoverageService($contact);
 *   $service->checkCoverage();
 */
class VerizonCoverageService
{
    private Contact $contact;
    private ?TwilioCredential $credentials;
    private Client $httpClient;
    private array $coverageData = [];

    /**
     * API Endpoints
     */
    private const VERIZON_FWA_API_URL = 'https://api.verizonwireless.com';
    private const FCC_BROADBAND_API_URL = 'https://broadbandmap.fcc.gov/api/public/map/basic/search';

    /**
     * Cache TTL - 30 days (coverage doesn't change often)
     */
    private const CACHE_TTL = 60 * 60 * 24 * 30;

    /**
     * Recheck interval - 30 days
     */
    private const RECHECK_INTERVAL_DAYS = 30;

    public function __construct(Contact $contact)
    {
        $this->contact = $contact;
        $this->credentials = TwilioCredential::current();
        $this->httpClient = new Client([
            'timeout' => 10,
            'connect_timeout' => 5,
        ]);
    }

    /**
     * Main entry point - check coverage using best available method
     *
     * @return bool Success status
     */
    public function checkCoverage(): bool
    {
        // Skip if already checked recently (within 30 days)
        if ($this->recentlyChecked()) {
            return false;
        }

        // Skip if no valid address
        if (!$this->hasValidAddress()) {
            Log::info("Skipping Verizon coverage check for contact {$this->contact->id}: no valid address");
            return false;
        }

        try {
            // Try different data sources in order of reliability
            $this->coverageData = $this->fetchCoverageData();

            if (!empty($this->coverageData)) {
                $this->updateContactCoverage($this->coverageData);
                $this->markCoverageChecked();
                return true;
            }

            Log::warning("No Verizon coverage data found for contact {$this->contact->id}");
            $this->markCoverageChecked(); // Mark as checked even if no data found
            return false;
        } catch (\Exception $e) {
            Log::error("Verizon coverage check failed for contact {$this->contact->id}: {$e->getMessage()}");
            return false;
        }
    }

    /**
     * Fetch coverage data using multiple fallback strategies
     *
     * @return array|null Coverage data or null
     */
    private function fetchCoverageData(): ?array
    {
        // Try Verizon FWA API first (most accurate)
        if ($this->hasVerizonApiCredentials()) {
            $data = $this->tryVerizonFwaApi();
            if ($data) {
                return $data;
            }
        }

        // Fallback to FCC broadband data
        $data = $this->tryFccBroadbandData();
        if ($data) {
            return $data;
        }

        // Last resort: estimate based on location
        return $this->estimateCoverageByLocation();
    }

    /**
     * Check if Verizon API credentials are configured
     *
     * @return bool
     */
    private function hasVerizonApiCredentials(): bool
    {
        return !empty($this->credentials->verizon_api_key)
            && !empty($this->credentials->verizon_api_secret);
    }

    /**
     * Try Verizon FWA (Fixed Wireless Access) API
     *
     * @return array|null Coverage data or null
     */
    private function tryVerizonFwaApi(): ?array
    {
        try {
            // Get OAuth token
            $authToken = $this->getVerizonAuthToken();
            if (!$authToken) {
                return null;
            }

            $addressKey = $this->buildAddressCacheKey();
            $cacheKey = "verizon_fwa:{$addressKey}";

            // Check cache first
            $cached = Cache::get($cacheKey);
            if ($cached !== null) {
                return $cached ?: null;
            }

            // Make API request
            $response = $this->httpClient->post(self::VERIZON_FWA_API_URL . '/fwa/v1/serviceability', [
                'headers' => [
                    'Authorization' => "Bearer {$authToken}",
                    'Content-Type' => 'application/json',
                ],
                'json' => [
                    'address' => [
                        'street' => $this->contact->business_address ?? $this->contact->consumer_address,
                        'city' => $this->contact->business_city ?? $this->contact->consumer_city,
                        'state' => $this->contact->business_state ?? $this->contact->consumer_state,
                        'zipCode' => $this->contact->business_postal_code ?? $this->contact->consumer_postal_code,
                    ],
                ],
            ]);

            $data = json_decode($response->getBody()->getContents(), true);
            $parsedData = $this->parseFwaResponse($data);

            Cache::put($cacheKey, $parsedData, self::CACHE_TTL);
            return $parsedData;
        } catch (GuzzleException $e) {
            Log::error("Verizon FWA API request failed: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Get OAuth token for Verizon API
     *
     * @return string|null Access token or null
     */
    private function getVerizonAuthToken(): ?string
    {
        $cacheKey = 'verizon_oauth_token';

        // Check cache first
        $cached = Cache::get($cacheKey);
        if ($cached) {
            return $cached;
        }

        try {
            $response = $this->httpClient->post(self::VERIZON_FWA_API_URL . '/oauth/v1/token', [
                'auth' => [
                    $this->credentials->verizon_api_key,
                    $this->credentials->verizon_api_secret,
                ],
                'form_params' => [
                    'grant_type' => 'client_credentials',
                ],
            ]);

            $data = json_decode($response->getBody()->getContents(), true);
            $accessToken = $data['access_token'] ?? null;

            if ($accessToken) {
                // Cache token for 50 minutes (expires in 1 hour typically)
                Cache::put($cacheKey, $accessToken, 3000);
            }

            return $accessToken;
        } catch (GuzzleException $e) {
            Log::error("Verizon OAuth failed: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Parse Verizon FWA API response
     *
     * @param array|null $data API response data
     * @return array|null Parsed coverage data
     */
    private function parseFwaResponse(?array $data): ?array
    {
        if (!is_array($data)) {
            return null;
        }

        return [
            'verizon_5g_home_available' => $data['products']['5G_HOME']['available'] ?? false,
            'verizon_lte_home_available' => $data['products']['LTE_HOME']['available'] ?? false,
            'verizon_fios_available' => $data['products']['FIOS']['available'] ?? false,
            'estimated_download_speed' => $data['products']['5G_HOME']['maxDownloadSpeed']
                ?? $data['products']['LTE_HOME']['maxDownloadSpeed']
                ?? null,
            'estimated_upload_speed' => $data['products']['5G_HOME']['maxUploadSpeed']
                ?? $data['products']['LTE_HOME']['maxUploadSpeed']
                ?? null,
            'source' => 'verizon_fwa_api',
        ];
    }

    /**
     * Try FCC Broadband Data API
     *
     * @return array|null Coverage data or null
     */
    private function tryFccBroadbandData(): ?array
    {
        $lat = $this->contact->latitude;
        $lon = $this->contact->longitude;

        if (!$lat || !$lon) {
            return null;
        }

        $cacheKey = "fcc_broadband:{$lat},{$lon}";

        // Check cache first
        $cached = Cache::get($cacheKey);
        if ($cached !== null) {
            return $cached ?: null;
        }

        try {
            // Use circuit breaker for FCC API
            $result = CircuitBreakerService::call('fcc_broadband', function () use ($lat, $lon) {
                return $this->httpClient->get(self::FCC_BROADBAND_API_URL, [
                    'query' => [
                        'latitude' => $lat,
                        'longitude' => $lon,
                        'technology' => 'wireless',
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($result) && isset($result['circuit_open'])) {
                return null;
            }

            $data = json_decode($result->getBody()->getContents(), true);
            $parsedData = $this->parseFccData($data);

            Cache::put($cacheKey, $parsedData, self::CACHE_TTL);
            return $parsedData;
        } catch (GuzzleException $e) {
            Log::error("FCC API request failed: {$e->getMessage()}");
            Cache::put($cacheKey, false, 3600); // Cache failures for 1 hour
            return null;
        }
    }

    /**
     * Parse FCC broadband data
     *
     * @param array|null $data FCC API response
     * @return array|null Parsed coverage data
     */
    private function parseFccData(?array $data): ?array
    {
        if (!is_array($data) || empty($data['results'])) {
            return null;
        }

        // Look for Verizon providers
        $verizonProviders = array_filter($data['results'], function ($provider) {
            return isset($provider['provider_name'])
                && stripos($provider['provider_name'], 'verizon') !== false;
        });

        if (empty($verizonProviders)) {
            return null;
        }

        // Estimate availability based on FCC data
        $hasWireless = false;
        foreach ($verizonProviders as $provider) {
            if (($provider['technology'] ?? null) === 'Wireless') {
                $hasWireless = true;
                break;
            }
        }

        return [
            'verizon_5g_home_available' => $hasWireless,
            'verizon_lte_home_available' => $hasWireless,
            'verizon_fios_available' => false,
            'estimated_download_speed' => null,
            'estimated_upload_speed' => null,
            'source' => 'fcc_broadband_data',
        ];
    }

    /**
     * Estimate coverage based on location (zip code + major markets)
     *
     * @return array|null Coverage data or null
     */
    private function estimateCoverageByLocation(): ?array
    {
        $zip = $this->contact->business_postal_code ?? $this->contact->consumer_postal_code;
        $city = $this->contact->business_city ?? $this->contact->consumer_city;
        $state = $this->contact->business_state ?? $this->contact->consumer_state;

        if (!$zip && !($city && $state)) {
            return null;
        }

        // Check if in major 5G market
        $locationKey = $city && $state ? strtolower("{$city}, {$state}") : null;
        $in5gMarket = $locationKey && $this->isInMarketList($locationKey, $this->major5gMarkets());
        $inLteMarket = $locationKey && $this->isInMarketList($locationKey, $this->majorLteMarkets());

        return [
            'verizon_5g_home_available' => $in5gMarket,
            'verizon_lte_home_available' => $inLteMarket || $in5gMarket,
            'verizon_fios_available' => false,
            'estimated_download_speed' => $in5gMarket ? '300-1000 Mbps' : ($inLteMarket ? '25-50 Mbps' : null),
            'estimated_upload_speed' => $in5gMarket ? '50-100 Mbps' : ($inLteMarket ? '3-10 Mbps' : null),
            'source' => 'location_estimation',
        ];
    }

    /**
     * Check if location is in market list
     *
     * @param string $location Location string
     * @param array $markets Array of market strings
     * @return bool
     */
    private function isInMarketList(string $location, array $markets): bool
    {
        foreach ($markets as $market) {
            if (str_contains($location, strtolower($market))) {
                return true;
            }
        }
        return false;
    }

    /**
     * Major 5G Home Internet markets (as of 2024)
     *
     * @return array
     */
    private function major5gMarkets(): array
    {
        return [
            'Los Angeles, CA',
            'Houston, TX',
            'Phoenix, AZ',
            'Sacramento, CA',
            'Chicago, IL',
            'Dallas, TX',
            'Indianapolis, IN',
            'Columbus, OH',
            'San Diego, CA',
            'Denver, CO',
            'Atlanta, GA',
            'Miami, FL',
            'Tampa, FL',
            'Detroit, MI',
            'Philadelphia, PA',
            'Minneapolis, MN',
            'Cleveland, OH',
            'Cincinnati, OH',
            'Orlando, FL',
            'Las Vegas, NV',
        ];
    }

    /**
     * Major LTE Home Internet markets (broader coverage)
     *
     * @return array
     */
    private function majorLteMarkets(): array
    {
        return array_merge($this->major5gMarkets(), [
            'Seattle, WA',
            'Boston, MA',
            'Austin, TX',
            'San Antonio, TX',
            'Charlotte, NC',
            'Raleigh, NC',
        ]);
    }

    /**
     * Update contact with coverage data
     *
     * @param array $coverageData Coverage data to save
     * @return void
     */
    private function updateContactCoverage(array $coverageData): void
    {
        $this->contact->update([
            'verizon_5g_home_available' => $coverageData['verizon_5g_home_available'] ?? false,
            'verizon_lte_home_available' => $coverageData['verizon_lte_home_available'] ?? false,
            'verizon_fios_available' => $coverageData['verizon_fios_available'] ?? false,
            'estimated_download_speed' => $coverageData['estimated_download_speed'] ?? null,
            'estimated_upload_speed' => $coverageData['estimated_upload_speed'] ?? null,
            'verizon_coverage_data' => array_merge($coverageData, ['checked_at' => now()]),
        ]);

        Log::info(
            "Verizon coverage updated for contact {$this->contact->id}: " .
            "5G={$coverageData['verizon_5g_home_available']}, " .
            "LTE={$coverageData['verizon_lte_home_available']} " .
            "(source: {$coverageData['source']})"
        );
    }

    /**
     * Mark contact as coverage checked
     *
     * @return void
     */
    private function markCoverageChecked(): void
    {
        $this->contact->update([
            'verizon_coverage_checked' => true,
            'verizon_coverage_checked_at' => now(),
        ]);
    }

    /**
     * Check if contact has valid address for checking
     *
     * @return bool
     */
    private function hasValidAddress(): bool
    {
        return (!empty($this->contact->business_address)
                && !empty($this->contact->business_city)
                && !empty($this->contact->business_state))
            || (!empty($this->contact->consumer_address)
                && !empty($this->contact->consumer_city)
                && !empty($this->contact->consumer_state))
            || !empty($this->contact->business_postal_code)
            || !empty($this->contact->consumer_postal_code);
    }

    /**
     * Check if coverage was recently checked (within 30 days)
     *
     * @return bool
     */
    private function recentlyChecked(): bool
    {
        return $this->contact->verizon_coverage_checked
            && $this->contact->verizon_coverage_checked_at
            && $this->contact->verizon_coverage_checked_at > now()->subDays(self::RECHECK_INTERVAL_DAYS);
    }

    /**
     * Build cache key from address
     *
     * @return string
     */
    private function buildAddressCacheKey(): string
    {
        $parts = [
            $this->contact->business_address ?? $this->contact->consumer_address,
            $this->contact->business_city ?? $this->contact->consumer_city,
            $this->contact->business_state ?? $this->contact->consumer_state,
            $this->contact->business_postal_code ?? $this->contact->consumer_postal_code,
        ];

        return md5(implode('|', array_filter($parts)));
    }
}
