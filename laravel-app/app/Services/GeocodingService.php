<?php

namespace App\Services;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Models\ApiUsageLog;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * GeocodingService - Geocode addresses using Google Geocoding API
 *
 * This service provides:
 * - Address to coordinates conversion (geocoding)
 * - Coordinates to address conversion (reverse geocoding)
 * - Location metadata extraction
 * - Timezone detection
 * - Batch geocoding capabilities
 *
 * All API calls are protected by circuit breakers and cached to avoid duplicate requests.
 *
 * Usage:
 *   $service = new GeocodingService($contact);
 *   $result = $service->geocode();
 */
class GeocodingService
{
    private Contact $contact;
    private ?TwilioCredential $credentials;
    private Client $httpClient;

    /**
     * Google Geocoding API endpoint
     */
    private const GOOGLE_GEOCODING_API_URL = 'https://maps.googleapis.com/maps/api/geocode/json';

    /**
     * Cache TTL - 90 days (addresses don't change often)
     */
    private const CACHE_TTL = 60 * 60 * 24 * 90;

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
     * Geocode contact address to coordinates
     *
     * @return array Result with success, latitude, longitude, accuracy
     */
    public function geocode(): array
    {
        // Validate configuration
        if (!$this->credentials || !$this->credentials->enable_geocoding) {
            return ['success' => false, 'error' => 'Geocoding not enabled'];
        }

        if (empty($this->credentials->google_geocoding_api_key)) {
            return ['success' => false, 'error' => 'No Google Geocoding API key configured'];
        }

        if (!$this->hasGeocodableAddress()) {
            return ['success' => false, 'error' => 'No address to geocode'];
        }

        $startTime = microtime(true);

        try {
            $addressString = $this->buildAddressString();
            $cacheKey = "geocode:" . md5($addressString);

            // Check cache first
            $cachedResult = Cache::get($cacheKey);
            if ($cachedResult !== null) {
                Log::info("Geocoding cache hit for contact {$this->contact->id}");
                return $cachedResult;
            }

            $response = $this->callGoogleGeocodingApi($addressString);

            if ($response['status'] === 'OK' && !empty($response['results'])) {
                $result = $response['results'][0];
                $location = $result['geometry']['location'];
                $accuracy = $result['geometry']['location_type'];

                // Update contact with geocoded data
                $this->contact->update([
                    'latitude' => $location['lat'],
                    'longitude' => $location['lng'],
                    'geocoding_accuracy' => $this->mapAccuracy($accuracy),
                    'geocoding_provider' => 'google',
                    'geocoded_at' => now(),
                ]);

                // Log API usage
                $this->logApiUsage(
                    'geocode',
                    'success',
                    (int) ((microtime(true) - $startTime) * 1000),
                    200
                );

                $returnData = [
                    'success' => true,
                    'latitude' => $location['lat'],
                    'longitude' => $location['lng'],
                    'accuracy' => $this->mapAccuracy($accuracy),
                    'formatted_address' => $result['formatted_address'] ?? null,
                ];

                Cache::put($cacheKey, $returnData, self::CACHE_TTL);
                return $returnData;
            }

            $errorMsg = $response['error_message'] ?? $response['status'];
            $logStatus = $this->mapStatusToLogStatus($response['status']);

            $this->logApiUsage(
                'geocode',
                $logStatus,
                (int) ((microtime(true) - $startTime) * 1000),
                null,
                $errorMsg
            );

            return ['success' => false, 'error' => $errorMsg];
        } catch (\Exception $e) {
            Log::error("Geocoding error for contact {$this->contact->id}: {$e->getMessage()}");

            $this->logApiUsage(
                'geocode',
                'error',
                (int) ((microtime(true) - $startTime) * 1000),
                null,
                $e->getMessage()
            );

            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Reverse geocode coordinates to address
     *
     * @param float $lat Latitude
     * @param float $lng Longitude
     * @return array Result with success and address components
     */
    public function reverseGeocode(float $lat, float $lng): array
    {
        // Validate configuration
        if (!$this->credentials || !$this->credentials->enable_geocoding) {
            return ['success' => false, 'error' => 'Geocoding not enabled'];
        }

        if (empty($this->credentials->google_geocoding_api_key)) {
            return ['success' => false, 'error' => 'No Google Geocoding API key configured'];
        }

        $startTime = microtime(true);
        $cacheKey = "reverse_geocode:{$lat},{$lng}";

        // Check cache first
        $cachedResult = Cache::get($cacheKey);
        if ($cachedResult !== null) {
            return $cachedResult;
        }

        try {
            $result = CircuitBreakerService::call('google_geocoding', function () use ($lat, $lng) {
                return $this->httpClient->get(self::GOOGLE_GEOCODING_API_URL, [
                    'query' => [
                        'latlng' => "{$lat},{$lng}",
                        'key' => $this->credentials->google_geocoding_api_key,
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($result) && isset($result['circuit_open'])) {
                return ['success' => false, 'error' => 'Service temporarily unavailable'];
            }

            $response = json_decode($result->getBody()->getContents(), true);

            if ($response['status'] === 'OK' && !empty($response['results'])) {
                $result = $response['results'][0];
                $addressComponents = $this->parseAddressComponents($result['address_components'] ?? []);

                $this->logApiUsage(
                    'reverse_geocode',
                    'success',
                    (int) ((microtime(true) - $startTime) * 1000),
                    200
                );

                $returnData = array_merge([
                    'success' => true,
                    'formatted_address' => $result['formatted_address'] ?? null,
                ], $addressComponents);

                Cache::put($cacheKey, $returnData, self::CACHE_TTL);
                return $returnData;
            }

            $errorMsg = $response['error_message'] ?? $response['status'];

            $this->logApiUsage(
                'reverse_geocode',
                'failed',
                (int) ((microtime(true) - $startTime) * 1000),
                null,
                $errorMsg
            );

            return ['success' => false, 'error' => $errorMsg];
        } catch (GuzzleException $e) {
            Log::error("Reverse geocoding error: {$e->getMessage()}");

            $this->logApiUsage(
                'reverse_geocode',
                'error',
                (int) ((microtime(true) - $startTime) * 1000),
                null,
                $e->getMessage()
            );

            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Batch geocode contacts that need geocoding
     *
     * @param int $limit Maximum number of contacts to geocode
     * @return array Results summary
     */
    public static function batchGeocode(int $limit = 100): array
    {
        $contacts = Contact::whereNull('geocoded_at')
            ->whereNotNull('consumer_address')
            ->orWhereNotNull('business_address')
            ->limit($limit)
            ->get();

        $results = [
            'total' => $contacts->count(),
            'successful' => 0,
            'failed' => 0,
            'errors' => [],
        ];

        foreach ($contacts as $contact) {
            $service = new self($contact);
            $result = $service->geocode();

            if ($result['success']) {
                $results['successful']++;
            } else {
                $results['failed']++;
                $results['errors'][] = [
                    'contact_id' => $contact->id,
                    'error' => $result['error'],
                ];
            }

            // Rate limiting: Google allows ~50 requests/second
            // Sleep for 20ms between requests
            usleep(20000);
        }

        return $results;
    }

    /**
     * Check if contact has a geocodable address
     *
     * @return bool
     */
    private function hasGeocodableAddress(): bool
    {
        return !empty($this->contact->consumer_address) || !empty($this->contact->business_address);
    }

    /**
     * Build address string from contact data
     *
     * @return string Address string
     */
    private function buildAddressString(): string
    {
        if (!empty($this->contact->consumer_address)) {
            $parts = [
                $this->contact->consumer_address,
                $this->contact->consumer_city,
                $this->contact->consumer_state,
                $this->contact->consumer_postal_code,
                $this->contact->consumer_country ?? 'US',
            ];
        } else {
            $parts = [
                $this->contact->business_address,
                $this->contact->business_city,
                $this->contact->business_state,
                $this->contact->business_postal_code,
                $this->contact->business_country ?? 'US',
            ];
        }

        return implode(', ', array_filter($parts));
    }

    /**
     * Call Google Geocoding API with circuit breaker protection
     *
     * @param string $address Address to geocode
     * @return array API response
     */
    private function callGoogleGeocodingApi(string $address): array
    {
        try {
            $result = CircuitBreakerService::call('google_geocoding', function () use ($address) {
                return $this->httpClient->get(self::GOOGLE_GEOCODING_API_URL, [
                    'query' => [
                        'address' => $address,
                        'key' => $this->credentials->google_geocoding_api_key,
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($result) && isset($result['circuit_open'])) {
                return ['status' => 'CIRCUIT_OPEN', 'error_message' => 'Service temporarily unavailable'];
            }

            return json_decode($result->getBody()->getContents(), true);
        } catch (GuzzleException $e) {
            Log::warning("Google Geocoding API error: {$e->getMessage()}");
            return ['status' => 'ERROR', 'error_message' => $e->getMessage()];
        }
    }

    /**
     * Map Google accuracy to our internal format
     *
     * @param string $googleAccuracy Google's location_type
     * @return string Mapped accuracy
     */
    private function mapAccuracy(string $googleAccuracy): string
    {
        return match ($googleAccuracy) {
            'ROOFTOP' => 'rooftop',
            'RANGE_INTERPOLATED' => 'range_interpolated',
            'GEOMETRIC_CENTER' => 'geometric_center',
            'APPROXIMATE' => 'approximate',
            default => 'unknown',
        };
    }

    /**
     * Parse address components from Google response
     *
     * @param array $components Address components array
     * @return array Parsed address data
     */
    private function parseAddressComponents(array $components): array
    {
        $addressData = [];

        foreach ($components as $component) {
            $types = $component['types'] ?? [];

            if (in_array('street_number', $types)) {
                $addressData['street_number'] = $component['long_name'];
            } elseif (in_array('route', $types)) {
                $addressData['street'] = $component['long_name'];
            } elseif (in_array('locality', $types)) {
                $addressData['city'] = $component['long_name'];
            } elseif (in_array('administrative_area_level_1', $types)) {
                $addressData['state'] = $component['short_name'];
            } elseif (in_array('postal_code', $types)) {
                $addressData['postal_code'] = $component['long_name'];
            } elseif (in_array('country', $types)) {
                $addressData['country'] = $component['short_name'];
            }
        }

        return $addressData;
    }

    /**
     * Map API status to log status
     *
     * @param string $status API status
     * @return string Log status
     */
    private function mapStatusToLogStatus(string $status): string
    {
        return match ($status) {
            'TIMEOUT' => 'timeout',
            'CIRCUIT_OPEN' => 'error',
            default => 'failed',
        };
    }

    /**
     * Log API usage to database
     *
     * @param string $service Service name
     * @param string $status Request status
     * @param int $responseTimeMs Response time in milliseconds
     * @param int|null $httpStatusCode HTTP status code
     * @param string|null $errorMessage Error message if failed
     * @return void
     */
    private function logApiUsage(
        string $service,
        string $status,
        int $responseTimeMs,
        ?int $httpStatusCode = null,
        ?string $errorMessage = null
    ): void {
        ApiUsageLog::logApiCall(
            $this->contact->id,
            'google_geocoding',
            $service,
            self::GOOGLE_GEOCODING_API_URL,
            $status,
            $responseTimeMs,
            $httpStatusCode,
            $errorMessage,
            now()
        );
    }
}
