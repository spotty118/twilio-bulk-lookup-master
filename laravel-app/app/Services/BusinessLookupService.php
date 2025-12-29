<?php

namespace App\Services;

use GuzzleHttp\Client as GuzzleClient;
use GuzzleHttp\Exception\GuzzleException;
use GuzzleHttp\Exception\RequestException;
use GuzzleHttp\Promise\Utils;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;
use App\Models\Contact;
use App\Models\TwilioCredential;
use Exception;

/**
 * BusinessLookupService - Lookup businesses by zipcode using multiple providers
 *
 * This service integrates with:
 * 1. Yelp Fusion API (primary - can fetch up to 240 results)
 * 2. Google Places API (supplementary - max 60 results)
 *
 * Features:
 * - Multi-provider failover and aggregation
 * - Duplicate detection and prevention
 * - Circuit breaker protection
 * - Rate limiting
 * - Concurrent API requests for better performance
 *
 * Usage:
 *   $service = new BusinessLookupService('90210');
 *   $stats = $service->lookupBusinesses(50);
 */
class BusinessLookupService
{
    /** @var string */
    protected $zipcode;

    /** @var TwilioCredential|null */
    protected $credentials;

    /** @var GuzzleClient */
    protected $httpClient;

    /** @var array */
    protected $stats = [
        'found' => 0,
        'imported' => 0,
        'updated' => 0,
        'skipped' => 0,
        'duplicates_prevented' => 0,
    ];

    /** @var object|null */
    protected $zipcodeEntry;

    public function __construct(string $zipcode, $zipcodeEntry = null)
    {
        $this->zipcode = trim($zipcode);
        $this->zipcodeEntry = $zipcodeEntry;
        $this->credentials = TwilioCredential::current();
        $this->httpClient = new GuzzleClient([
            'timeout' => 30,
            'connect_timeout' => 10,
            'headers' => [
                'User-Agent' => 'TwilioBulkLookup/2.0 Laravel',
            ],
        ]);
    }

    /**
     * Main entry point - lookup businesses from multiple providers
     */
    public function lookupBusinesses(int $limit = null): array
    {
        $limit = $limit ?? $this->credentials?->results_per_zipcode ?? 20;

        try {
            $businesses = $this->fetchBusinessesFromProviders($limit);
            $this->stats['found'] = count($businesses);

            Log::info("[BusinessLookupService] Found {$this->stats['found']} businesses in zipcode {$this->zipcode}");

            foreach ($businesses as $businessData) {
                $this->processBusiness($businessData);
            }

            return $this->stats;
        } catch (Exception $e) {
            Log::error("[BusinessLookupService] Error looking up businesses: {$e->getMessage()}");
            ErrorTrackingService::captureException($e, [
                'zipcode' => $this->zipcode,
                'limit' => $limit,
            ]);
            throw $e;
        }
    }

    /**
     * Fetch businesses from all available providers
     */
    protected function fetchBusinessesFromProviders(int $limit): array
    {
        $businesses = [];
        $providerErrors = [];
        $providersUsed = [];

        // Yelp can fetch up to 240 - use it as primary source for large requests
        if ($this->credentials?->yelp_api_key) {
            try {
                $yelpResults = $this->tryYelp($limit);
                $providersUsed[] = 'yelp';
                Log::info("[BusinessLookupService] Yelp returned " . count($yelpResults) . " businesses");
                $businesses = array_merge($businesses, $yelpResults);
            } catch (Exception $e) {
                $providerErrors[] = "Yelp: {$e->getMessage()}";
                Log::warning("[BusinessLookupService] Yelp failed: {$e->getMessage()}");
            }
        }

        // Supplement with Google Places if we need more results (Google caps at 60)
        $remainingNeeded = $limit - count($businesses);
        if ($remainingNeeded > 0 && $this->credentials?->google_places_api_key) {
            try {
                $googleLimit = min($remainingNeeded, 60);
                $googleResults = $this->tryGooglePlaces($googleLimit);
                $providersUsed[] = 'google_places';
                Log::info("[BusinessLookupService] Google returned " . count($googleResults) . " businesses");

                // Dedupe by phone number before combining
                $existingPhones = collect($businesses)->pluck('phone')->filter()->toArray();
                foreach ($googleResults as $biz) {
                    if (!empty($biz['phone']) && in_array($biz['phone'], $existingPhones)) {
                        continue;
                    }

                    $businesses[] = $biz;
                    if (!empty($biz['phone'])) {
                        $existingPhones[] = $biz['phone'];
                    }
                }
            } catch (Exception $e) {
                $providerErrors[] = "Google Places: {$e->getMessage()}";
                Log::warning("[BusinessLookupService] Google Places failed: {$e->getMessage()}");
            }
        }

        // Update provider tracking
        if (!empty($providersUsed)) {
            // Update zipcode lookup if available
            return array_slice($businesses, 0, $limit);
        }

        if (!empty($providerErrors)) {
            throw new Exception(implode(' | ', $providerErrors));
        }

        Log::warning('[BusinessLookupService] No business directory API configured');
        throw new Exception('No business directory API configured. Configure Google Places or Yelp in Twilio Settings.');
    }

    /**
     * Try Google Places API (with fallback to new API)
     */
    protected function tryGooglePlaces(int $limit): array
    {
        try {
            return $this->tryGooglePlacesLegacy($limit);
        } catch (Exception $e) {
            Log::info("[BusinessLookupService] Legacy Places API failed, trying new API");
            try {
                return $this->tryGooglePlacesNew($limit);
            } catch (Exception $newError) {
                throw new Exception("{$e->getMessage()} | Places API (New): {$newError->getMessage()}");
            }
        }
    }

    /**
     * Google Places API - Legacy Text Search
     */
    protected function tryGooglePlacesLegacy(int $limit): array
    {
        $apiKey = $this->credentials->google_places_api_key;
        $allResults = [];
        $nextPageToken = null;

        // Google Places returns 20 results per page, use pagination to get more
        $attempts = 0;
        $maxAttempts = ceil($limit / 20);

        while ($attempts < $maxAttempts) {
            $params = [
                'query' => "businesses in {$this->zipcode}",
                'key' => $apiKey,
            ];

            if ($nextPageToken) {
                $params['pagetoken'] = $nextPageToken;
            }

            $response = CircuitBreakerService::call('google_places', function () use ($params) {
                return $this->httpClient->get('https://maps.googleapis.com/maps/api/place/textsearch/json', [
                    'query' => $params,
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                throw new Exception($response['error']);
            }

            if ($response->getStatusCode() !== 200) {
                throw new Exception("HTTP {$response->getStatusCode()}");
            }

            $data = json_decode($response->getBody()->getContents(), true);
            $status = $data['status'] ?? '';

            // Handle pagination delay - Google requires ~2 second wait between page requests
            if ($status === 'INVALID_REQUEST' && $nextPageToken) {
                sleep(2);
                $response = CircuitBreakerService::call('google_places', function () use ($params) {
                    return $this->httpClient->get('https://maps.googleapis.com/maps/api/place/textsearch/json', [
                        'query' => $params,
                    ]);
                });

                if (is_array($response) && isset($response['circuit_open'])) {
                    throw new Exception($response['error']);
                }

                $data = json_decode($response->getBody()->getContents(), true);
                $status = $data['status'] ?? '';
            }

            if ($status !== 'OK') {
                if ($status === 'ZERO_RESULTS') {
                    break;
                }

                $errorMsg = $data['error_message'] ?? $status;
                throw new Exception("{$status} - {$errorMsg}. Check that Places API is enabled, billing is active, and API key restrictions allow server requests.");
            }

            $allResults = array_merge($allResults, $data['results'] ?? []);

            // Check if we have enough results or no more pages
            if (count($allResults) >= $limit) {
                break;
            }

            if (empty($data['next_page_token'])) {
                break;
            }

            $nextPageToken = $data['next_page_token'];
            $attempts++;
            // Google requires a short delay before using next_page_token
            sleep(2);
        }

        $results = array_slice($allResults, 0, $limit);

        // Batch fetch place details
        $placeIds = array_column($results, 'place_id');
        $placeIds = array_filter($placeIds);
        $detailsCache = $this->batchFetchPlaceDetails($placeIds);

        $businesses = [];
        foreach ($results as $place) {
            $businesses[] = $this->parseGooglePlace($place, $detailsCache);
        }

        return array_filter($businesses);
    }

    /**
     * Google Places API - New API (v1)
     */
    protected function tryGooglePlacesNew(int $limit): array
    {
        $apiKey = $this->credentials->google_places_api_key;

        $body = [
            'textQuery' => "businesses in {$this->zipcode}",
            'maxResultCount' => min($limit, 20), // New API limits to 20
            'languageCode' => 'en',
            'regionCode' => 'US',
        ];

        $fieldMask = 'places.id,places.displayName,places.formattedAddress,places.location,places.types,places.rating,places.websiteUri,places.nationalPhoneNumber,places.internationalPhoneNumber';

        $response = CircuitBreakerService::call('google_places', function () use ($body, $apiKey, $fieldMask) {
            return $this->httpClient->post('https://places.googleapis.com/v1/places:searchText', [
                'json' => $body,
                'headers' => [
                    'X-Goog-Api-Key' => $apiKey,
                    'X-Goog-FieldMask' => $fieldMask,
                ],
            ]);
        });

        // Handle circuit breaker fallback
        if (is_array($response) && isset($response['circuit_open'])) {
            throw new Exception($response['error']);
        }

        if ($response->getStatusCode() !== 200) {
            $data = json_decode($response->getBody()->getContents(), true);
            $errorStatus = $data['error']['status'] ?? '';
            $errorMessage = $data['error']['message'] ?? '';
            $message = "HTTP {$response->getStatusCode()}";
            if ($errorStatus || $errorMessage) {
                $message = ($errorStatus ?: $message) . " - " . ($errorMessage ?: $message);
            }
            throw new Exception($message);
        }

        $data = json_decode($response->getBody()->getContents(), true);
        $places = $data['places'] ?? [];

        $businesses = [];
        foreach (array_slice($places, 0, $limit) as $place) {
            $name = $place['displayName']['text'] ?? $place['displayName'] ?? null;
            $phone = $place['internationalPhoneNumber'] ?? $place['nationalPhoneNumber'] ?? null;

            $businesses[] = [
                'name' => $name,
                'address' => $place['formattedAddress'] ?? null,
                'phone' => $phone,
                'website' => $place['websiteUri'] ?? null,
                'business_type' => $place['types'][0] ?? null,
                'rating' => $place['rating'] ?? null,
                'latitude' => $place['location']['latitude'] ?? null,
                'longitude' => $place['location']['longitude'] ?? null,
                'place_id' => $place['id'] ?? null,
                'source' => 'google_places',
            ];
        }

        return array_filter($businesses);
    }

    /**
     * Parse Google Place result
     */
    protected function parseGooglePlace(array $place, array $detailsCache = []): array
    {
        $placeId = $place['place_id'] ?? null;
        $details = null;

        if ($placeId && isset($detailsCache[$placeId])) {
            $details = $detailsCache[$placeId];
        } elseif ($placeId) {
            $details = $this->fetchGooglePlaceDetails($placeId);
        }

        return [
            'name' => $place['name'] ?? null,
            'address' => $place['formatted_address'] ?? null,
            'phone' => $details['formatted_phone_number'] ?? null,
            'website' => $details['website'] ?? null,
            'business_type' => $place['types'][0] ?? null,
            'rating' => $place['rating'] ?? null,
            'latitude' => $place['geometry']['location']['lat'] ?? null,
            'longitude' => $place['geometry']['location']['lng'] ?? null,
            'place_id' => $placeId,
            'source' => 'google_places',
        ];
    }

    /**
     * Batch fetch place details using concurrent requests
     */
    protected function batchFetchPlaceDetails(array $placeIds): array
    {
        if (empty($placeIds)) {
            return [];
        }

        $detailsCache = [];
        $promises = [];

        // Create promises for concurrent requests (max 5 concurrent)
        $chunks = array_chunk($placeIds, 5);

        foreach ($chunks as $chunk) {
            $chunkPromises = [];
            foreach ($chunk as $placeId) {
                $chunkPromises[$placeId] = $this->httpClient->getAsync(
                    'https://maps.googleapis.com/maps/api/place/details/json',
                    [
                        'query' => [
                            'place_id' => $placeId,
                            'fields' => 'formatted_phone_number,website,name',
                            'key' => $this->credentials->google_places_api_key,
                        ],
                    ]
                );
            }

            // Wait for this chunk to complete
            $results = Utils::settle($chunkPromises)->wait();

            foreach ($results as $placeId => $result) {
                if ($result['state'] === 'fulfilled') {
                    try {
                        $data = json_decode($result['value']->getBody()->getContents(), true);
                        if (($data['status'] ?? '') === 'OK') {
                            $detailsCache[$placeId] = $data['result'];
                        }
                    } catch (Exception $e) {
                        Log::warning("[BusinessLookupService] Error parsing place details for {$placeId}: {$e->getMessage()}");
                    }
                }
            }
        }

        return $detailsCache;
    }

    /**
     * Fetch Google Place details individually
     */
    protected function fetchGooglePlaceDetails(string $placeId): ?array
    {
        try {
            $response = CircuitBreakerService::call('google_places', function () use ($placeId) {
                return $this->httpClient->get('https://maps.googleapis.com/maps/api/place/details/json', [
                    'query' => [
                        'place_id' => $placeId,
                        'fields' => 'formatted_phone_number,website,name',
                        'key' => $this->credentials->google_places_api_key,
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
            $status = $data['status'] ?? '';

            if ($status === 'OK') {
                return $data['result'];
            }

            return null;
        } catch (Exception $e) {
            Log::warning("[BusinessLookupService] Google Place details error: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Try Yelp Fusion API
     */
    protected function tryYelp(int $limit): array
    {
        $apiKey = $this->credentials->yelp_api_key;
        $allBusinesses = [];
        $offset = 0;
        $pageSize = 50; // Yelp max per request

        // Yelp Fusion API constraint: limit + offset must be <= 240
        $maxYelpResults = 240;

        while (true) {
            // Calculate actual page size ensuring offset + limit <= 240
            $actualPageSize = min($pageSize, $maxYelpResults - $offset);
            if ($actualPageSize <= 0) {
                break;
            }

            $response = CircuitBreakerService::call('yelp', function () use ($offset, $actualPageSize, $apiKey) {
                return $this->httpClient->get('https://api.yelp.com/v3/businesses/search', [
                    'query' => [
                        'location' => $this->zipcode,
                        'limit' => $actualPageSize,
                        'offset' => $offset,
                    ],
                    'headers' => [
                        'Authorization' => "Bearer {$apiKey}",
                    ],
                ]);
            });

            // Handle circuit breaker fallback
            if (is_array($response) && isset($response['circuit_open'])) {
                throw new Exception($response['error']);
            }

            if ($response->getStatusCode() !== 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                $errorDesc = $data['error']['description'] ?? $data['error']['code'] ?? null;
                $message = "HTTP {$response->getStatusCode()}";
                if ($errorDesc) {
                    $message .= " - {$errorDesc}";
                }
                throw new Exception($message);
            }

            $data = json_decode($response->getBody()->getContents(), true);
            $businesses = $data['businesses'] ?? [];
            $totalAvailable = $data['total'] ?? 0;

            $allBusinesses = array_merge($allBusinesses, $businesses);

            // Check if we have enough results or no more pages
            if (count($allBusinesses) >= $limit) {
                break;
            }

            if (empty($businesses)) {
                break;
            }

            if ($offset + $actualPageSize >= $totalAvailable) {
                break;
            }

            if ($offset + $actualPageSize >= $maxYelpResults) {
                break;
            }

            $offset += $actualPageSize;
        }

        $results = array_slice($allBusinesses, 0, $limit);

        $businesses = [];
        foreach ($results as $biz) {
            $businesses[] = $this->parseYelpBusiness($biz);
        }

        return array_filter($businesses);
    }

    /**
     * Parse Yelp business result
     */
    protected function parseYelpBusiness(array $biz): array
    {
        $addressParts = array_filter([
            $biz['location']['address1'] ?? null,
            $biz['location']['city'] ?? null,
            $biz['location']['state'] ?? null,
            $biz['location']['zip_code'] ?? null,
        ]);

        return [
            'name' => $biz['name'] ?? null,
            'address' => implode(', ', $addressParts),
            'phone' => $biz['phone'] ?? null,
            'website' => $biz['url'] ?? null,
            'business_type' => $biz['categories'][0]['title'] ?? null,
            'rating' => $biz['rating'] ?? null,
            'review_count' => $biz['review_count'] ?? null,
            'latitude' => $biz['coordinates']['latitude'] ?? null,
            'longitude' => $biz['coordinates']['longitude'] ?? null,
            'yelp_id' => $biz['id'] ?? null,
            'source' => 'yelp',
        ];
    }

    /**
     * Process individual business (create or update contact)
     */
    protected function processBusiness(array $businessData): void
    {
        try {
            // Check for existing contact by phone or business name + address
            $existingContact = $this->findExistingContact($businessData);

            if ($existingContact) {
                // Update existing contact
                if ($this->updateContact($existingContact, $businessData)) {
                    $this->stats['updated']++;
                    Log::info("[BusinessLookupService] Updated contact #{$existingContact->id}: {$businessData['name']}");
                } else {
                    $this->stats['skipped']++;
                    Log::info("[BusinessLookupService] Skipped contact #{$existingContact->id}: No changes needed");
                }
            } else {
                // Create new contact
                $contact = $this->createContact($businessData);
                if ($contact && $contact->exists) {
                    $this->stats['imported']++;
                    Log::info("[BusinessLookupService] Imported new contact #{$contact->id}: {$businessData['name']}");

                    // Trigger enrichment pipeline if enabled
                    if ($this->credentials?->auto_enrich_zipcode_results) {
                        $this->triggerEnrichment($contact);
                    }
                } else {
                    $this->stats['skipped']++;
                    Log::warning("[BusinessLookupService] Failed to import: {$businessData['name']}");
                }
            }
        } catch (Exception $e) {
            Log::error("[BusinessLookupService] Error processing business {$businessData['name']}: {$e->getMessage()}");
            $this->stats['skipped']++;
        }
    }

    /**
     * Find existing contact by phone or name fingerprint
     */
    protected function findExistingContact(array $businessData): ?Contact
    {
        // First try by phone (most reliable)
        if (!empty($businessData['phone'])) {
            $normalizedPhone = $this->normalizePhone($businessData['phone']);
            $contact = Contact::where('raw_phone_number', $normalizedPhone)->first();
            if ($contact) {
                return $contact;
            }
        }

        // Try by business name + zipcode (good match)
        if (empty($businessData['name'])) {
            return null;
        }

        // Use fingerprinting for better matching
        $nameFingerprint = $this->createNameFingerprint($businessData['name']);

        return Contact::where('name_fingerprint', $nameFingerprint)
            ->where('business_postal_code', $this->zipcode)
            ->first();
    }

    /**
     * Create new contact from business data
     */
    protected function createContact(array $businessData): ?Contact
    {
        $addressData = $this->parseAddress($businessData['address'] ?? '');

        $contact = new Contact([
            'raw_phone_number' => $this->normalizePhone($businessData['phone'] ?? ''),
            'status' => 'pending',
            'is_business' => true,
            'caller_type' => 'business',
            'business_name' => $businessData['name'],
            'business_type' => $businessData['business_type'],
            'business_address' => $businessData['address'],
            'business_city' => $addressData['city'] ?? null,
            'business_state' => $addressData['state'] ?? null,
            'business_postal_code' => $addressData['zipcode'] ?? $this->zipcode,
            'business_country' => 'USA',
            'business_website' => $this->extractDomain($businessData['website'] ?? ''),
            'business_enriched' => true,
            'business_enrichment_provider' => $businessData['source'],
            'business_enriched_at' => now(),
            'business_confidence_score' => 100, // Direct lookup = high confidence
        ]);

        $contact->save();

        // Update fingerprints and quality score
        if (method_exists($contact, 'updateFingerprints')) {
            $contact->updateFingerprints();
        }

        if (method_exists($contact, 'calculateQualityScore')) {
            $contact->calculateQualityScore();
        }

        return $contact;
    }

    /**
     * Update existing contact with business data
     */
    protected function updateContact(Contact $contact, array $businessData): bool
    {
        $updates = [];

        // Update business fields if they're empty or we have better data
        if (!empty($businessData['name']) && empty($contact->business_name)) {
            $updates['business_name'] = $businessData['name'];
        }

        if (!empty($businessData['business_type']) && empty($contact->business_type)) {
            $updates['business_type'] = $businessData['business_type'];
        }

        if (!empty($businessData['address']) && empty($contact->business_address)) {
            $updates['business_address'] = $businessData['address'];
        }

        $addressData = $this->parseAddress($businessData['address'] ?? '');
        if (!empty($addressData['city']) && empty($contact->business_city)) {
            $updates['business_city'] = $addressData['city'];
        }

        if (!empty($addressData['state']) && empty($contact->business_state)) {
            $updates['business_state'] = $addressData['state'];
        }

        if (empty($contact->business_postal_code)) {
            $updates['business_postal_code'] = $addressData['zipcode'] ?? $this->zipcode;
        }

        if (!empty($businessData['website']) && empty($contact->business_website)) {
            $updates['business_website'] = $this->extractDomain($businessData['website']);
        }

        if (!empty($businessData['phone']) && empty($contact->raw_phone_number)) {
            $updates['raw_phone_number'] = $this->normalizePhone($businessData['phone']);
        }

        // Mark as business if not already
        if (!$contact->is_business) {
            $updates['is_business'] = true;
        }

        if ($contact->caller_type !== 'business') {
            $updates['caller_type'] = 'business';
        }

        // Update enrichment tracking
        $updates['business_enriched'] = true;
        $updates['business_enrichment_provider'] = $businessData['source'];
        $updates['business_enriched_at'] = now();

        if (!empty($updates)) {
            $contact->update($updates);

            if (method_exists($contact, 'updateFingerprints')) {
                $contact->updateFingerprints();
            }

            if (method_exists($contact, 'calculateQualityScore')) {
                $contact->calculateQualityScore();
            }

            return true;
        }

        return false;
    }

    /**
     * Trigger enrichment jobs for contact
     */
    protected function triggerEnrichment(Contact $contact): void
    {
        // Queue enrichment jobs if needed (implement based on Laravel job system)
        // This would dispatch jobs like:
        // - LookupRequestJob::dispatch($contact->id)
        // - EmailEnrichmentJob::dispatch($contact->id)
    }

    /**
     * Normalize phone number to E.164 format
     */
    protected function normalizePhone(?string $phone): ?string
    {
        if (empty($phone)) {
            return null;
        }

        // Remove all non-digit characters
        $digits = preg_replace('/\D/', '', $phone);

        // Add +1 if it's a 10-digit US number
        if (strlen($digits) === 10) {
            $digits = "1{$digits}";
        }

        // Return with + prefix for E.164 format
        return "+{$digits}";
    }

    /**
     * Create name fingerprint for matching
     */
    protected function createNameFingerprint(?string $name): ?string
    {
        if (empty($name)) {
            return null;
        }

        // Same logic as Contact model
        $normalized = strtolower($name);
        $normalized = preg_replace('/[^a-z0-9\s]/', '', $normalized);
        $parts = explode(' ', $normalized);
        $parts = array_filter($parts);
        sort($parts);

        return implode(' ', $parts);
    }

    /**
     * Parse address into components
     */
    protected function parseAddress(?string $address): array
    {
        if (empty($address)) {
            return [];
        }

        $data = [];

        // Try to extract zipcode
        if (preg_match('/\b(\d{5})\b/', $address, $match)) {
            $data['zipcode'] = $match[1];
        }

        // Try to extract state (2-letter code)
        if (preg_match('/\b([A-Z]{2})\b/', $address, $match)) {
            $data['state'] = $match[1];
        }

        // Try to extract city (word before state)
        if (preg_match('/,\s*([^,]+),\s*[A-Z]{2}/', $address, $match)) {
            $data['city'] = trim($match[1]);
        }

        return $data;
    }

    /**
     * Extract domain from URL
     */
    protected function extractDomain(?string $url): ?string
    {
        if (empty($url)) {
            return null;
        }

        try {
            $parsed = parse_url($url);
            return $parsed['host'] ?? null;
        } catch (Exception $e) {
            return null;
        }
    }

    /**
     * Get statistics from last lookup operation
     */
    public function getStats(): array
    {
        return $this->stats;
    }
}
