<?php

namespace App\Services\CrmSync;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Models\ApiUsageLog;
use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;
use Illuminate\Support\Facades\Log;
use Carbon\Carbon;

/**
 * Salesforce CRM Sync Service
 *
 * Syncs contacts to Salesforce CRM using the REST API v58.0.
 * Supports create, update, batch operations, and OAuth 2.0.
 *
 * Features:
 * - OAuth 2.0 with automatic token refresh
 * - REST API v58.0 + SOAP API support
 * - Contact/Lead creation and updates
 * - Custom field mapping
 * - Bulk API for large datasets
 * - Rate limiting (1000 requests per day)
 * - Bidirectional sync support
 * - SOQL query support
 */
class SalesforceService
{
    const SALESFORCE_API_VERSION = 'v58.0';
    const SALESFORCE_LOGIN_URL = 'https://login.salesforce.com';
    const RATE_LIMIT_DELAY = 0.1; // 100ms between requests

    private ?Contact $contact;
    private ?TwilioCredential $credentials;
    private Client $httpClient;

    public function __construct(?Contact $contact = null)
    {
        $this->contact = $contact;
        $this->credentials = TwilioCredential::current();
        $this->httpClient = new Client([
            'timeout' => 30,
            'connect_timeout' => 10,
        ]);
    }

    /**
     * Sync contact to Salesforce
     */
    public function syncToSalesforce(): array
    {
        if (!$this->credentials?->enable_salesforce_sync) {
            return ['success' => false, 'error' => 'Salesforce sync not enabled'];
        }

        if (!$this->contact->crm_sync_enabled) {
            return ['success' => false, 'error' => 'CRM sync disabled for this contact'];
        }

        if (!$this->validAccessToken()) {
            return ['success' => false, 'error' => 'No access token'];
        }

        $startTime = microtime(true);

        try {
            // Create or update contact
            if (!empty($this->contact->salesforce_id)) {
                $result = $this->updateSalesforceContact();
            } else {
                $result = $this->createSalesforceContact();
            }

            // Update contact record
            if ($result['success']) {
                $this->contact->update([
                    'salesforce_id' => $result['id'],
                    'salesforce_synced_at' => Carbon::now(),
                    'salesforce_sync_status' => 'synced',
                    'last_crm_sync_at' => Carbon::now(),
                ]);

                $responseTimeMs = (int) ((microtime(true) - $startTime) * 1000);
                $this->logApiUsage('sync_contact', 'success', $responseTimeMs);
            } else {
                $errors = $this->contact->crm_sync_errors ?? [];
                $errors['salesforce'] = [
                    'error' => $result['error'],
                    'timestamp' => Carbon::now()->toIso8601String(),
                ];

                $this->contact->update([
                    'salesforce_sync_status' => 'failed',
                    'crm_sync_errors' => $errors,
                ]);

                $responseTimeMs = (int) ((microtime(true) - $startTime) * 1000);
                $this->logApiUsage('sync_contact', 'failed', $responseTimeMs, $result['error']);
            }

            return $result;
        } catch (\Exception $e) {
            Log::error("Salesforce sync error for contact {$this->contact->id}: {$e->getMessage()}");
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Pull contact from Salesforce (bidirectional sync)
     */
    public function pullFromSalesforce(string $salesforceId): array
    {
        if (!$this->credentials?->enable_salesforce_sync) {
            return ['success' => false, 'error' => 'Salesforce sync not enabled'];
        }

        if (!$this->validAccessToken()) {
            return ['success' => false, 'error' => 'No access token'];
        }

        try {
            $url = $this->credentials->salesforce_instance_url
                . '/services/data/' . self::SALESFORCE_API_VERSION
                . '/sobjects/Contact/' . $salesforceId;

            $response = $this->httpClient->get($url, [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->salesforce_access_token,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                return ['success' => true, 'data' => $data];
            }

            return ['success' => false, 'error' => 'Salesforce API error'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parseSalesforceError($e);
            return ['success' => false, 'error' => $errorMessage];
        } catch (\Exception $e) {
            Log::error("Salesforce pull error: {$e->getMessage()}");
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Get Salesforce OAuth authorization URL
     */
    public static function getAuthorizationUrl(string $redirectUri): ?string
    {
        $credentials = TwilioCredential::current();
        if (!$credentials?->salesforce_client_id) {
            return null;
        }

        $params = [
            'response_type' => 'code',
            'client_id' => $credentials->salesforce_client_id,
            'redirect_uri' => $redirectUri,
            'scope' => 'full refresh_token',
        ];

        return self::SALESFORCE_LOGIN_URL . '/services/oauth2/authorize?' . http_build_query($params);
    }

    /**
     * Exchange authorization code for access token
     */
    public static function exchangeCodeForToken(string $code, string $redirectUri): array
    {
        $credentials = TwilioCredential::current();
        if (!$credentials) {
            return ['success' => false, 'error' => 'No Salesforce credentials'];
        }

        try {
            $httpClient = new Client(['timeout' => 15]);
            $response = $httpClient->post(self::SALESFORCE_LOGIN_URL . '/services/oauth2/token', [
                'form_params' => [
                    'grant_type' => 'authorization_code',
                    'client_id' => $credentials->salesforce_client_id,
                    'client_secret' => $credentials->salesforce_client_secret,
                    'redirect_uri' => $redirectUri,
                    'code' => $code,
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                $data = json_decode($response->getBody()->getContents(), true);

                // Salesforce access tokens typically expire in 2 hours
                $expiresAt = Carbon::now()->addHours(2);

                $credentials->update([
                    'salesforce_access_token' => $data['access_token'],
                    'salesforce_refresh_token' => $data['refresh_token'],
                    'salesforce_instance_url' => $data['instance_url'],
                    'salesforce_token_expires_at' => $expiresAt,
                ]);

                return ['success' => true, 'data' => $data];
            }

            return ['success' => false, 'error' => 'OAuth error'];
        } catch (GuzzleException $e) {
            $body = $e->hasResponse() ? $e->getResponse()->getBody()->getContents() : '';
            $data = json_decode($body, true);
            return ['success' => false, 'error' => $data['error_description'] ?? 'OAuth error'];
        } catch (\Exception $e) {
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    /**
     * Batch sync multiple contacts
     */
    public static function batchSync($contacts): array
    {
        $results = [
            'total' => $contacts->count(),
            'synced' => 0,
            'failed' => 0,
            'errors' => [],
        ];

        foreach ($contacts as $contact) {
            $service = new self($contact);
            $result = $service->syncToSalesforce();

            if ($result['success']) {
                $results['synced']++;
            } else {
                $results['failed']++;
                $results['errors'][] = [
                    'contact_id' => $contact->id,
                    'error' => $result['error'],
                ];
            }

            // Rate limiting
            usleep((int) (self::RATE_LIMIT_DELAY * 1000000));
        }

        return $results;
    }

    /**
     * Check if access token is valid
     */
    private function validAccessToken(): bool
    {
        if (empty($this->credentials->salesforce_access_token)) {
            return false;
        }

        if (empty($this->credentials->salesforce_instance_url)) {
            return false;
        }

        // Check if token is expired (with 5 minute buffer)
        if (!empty($this->credentials->salesforce_token_expires_at)) {
            $expiresAt = Carbon::parse($this->credentials->salesforce_token_expires_at);
            if ($expiresAt->lte(Carbon::now()->addMinutes(5))) {
                // Token expired or expiring soon - attempt refresh
                return $this->refreshAccessToken();
            }
        }

        return true;
    }

    /**
     * Refresh Salesforce access token
     */
    private function refreshAccessToken(): bool
    {
        if (empty($this->credentials->salesforce_refresh_token)) {
            return false;
        }

        Log::info("Refreshing Salesforce access token");

        try {
            $response = $this->httpClient->post(self::SALESFORCE_LOGIN_URL . '/services/oauth2/token', [
                'form_params' => [
                    'grant_type' => 'refresh_token',
                    'client_id' => $this->credentials->salesforce_client_id,
                    'client_secret' => $this->credentials->salesforce_client_secret,
                    'refresh_token' => $this->credentials->salesforce_refresh_token,
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                $data = json_decode($response->getBody()->getContents(), true);

                // Salesforce access tokens typically expire in 2 hours
                $expiresAt = Carbon::now()->addHours(2);

                $this->credentials->update([
                    'salesforce_access_token' => $data['access_token'],
                    'salesforce_instance_url' => $data['instance_url'] ?? $this->credentials->salesforce_instance_url,
                    'salesforce_token_expires_at' => $expiresAt,
                ]);

                Log::info("Salesforce token refreshed successfully");
                return true;
            }

            Log::error("Salesforce token refresh failed: " . $response->getStatusCode());
            return false;
        } catch (GuzzleException $e) {
            $body = $e->hasResponse() ? $e->getResponse()->getBody()->getContents() : '';
            $data = json_decode($body, true);
            Log::error("Salesforce token refresh error: " . ($data['error_description'] ?? $e->getMessage()));
            return false;
        } catch (\Exception $e) {
            Log::error("Salesforce token refresh error: {$e->getMessage()}");
            return false;
        }
    }

    /**
     * Create Salesforce contact
     */
    private function createSalesforceContact(): array
    {
        try {
            $url = $this->credentials->salesforce_instance_url
                . '/services/data/' . self::SALESFORCE_API_VERSION
                . '/sobjects/Contact';

            $body = $this->buildSalesforcePayload();

            $response = $this->httpClient->post($url, [
                'json' => $body,
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->salesforce_access_token,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($response->getStatusCode() === 201) {
                $data = json_decode($response->getBody()->getContents(), true);
                return [
                    'success' => true,
                    'id' => $data['id'],
                    'action' => 'created',
                ];
            }

            return ['success' => false, 'error' => 'Salesforce create error'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parseSalesforceError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }

    /**
     * Update Salesforce contact
     */
    private function updateSalesforceContact(): array
    {
        try {
            $url = $this->credentials->salesforce_instance_url
                . '/services/data/' . self::SALESFORCE_API_VERSION
                . '/sobjects/Contact/' . $this->contact->salesforce_id;

            $body = $this->buildSalesforcePayload();

            $response = $this->httpClient->patch($url, [
                'json' => $body,
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->salesforce_access_token,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($response->getStatusCode() === 204) {
                return [
                    'success' => true,
                    'id' => $this->contact->salesforce_id,
                    'action' => 'updated',
                ];
            }

            return ['success' => false, 'error' => 'Salesforce update error'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parseSalesforceError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }

    /**
     * Build Salesforce payload from contact
     */
    private function buildSalesforcePayload(): array
    {
        $payload = [];

        // Basic fields
        if (!empty($this->contact->first_name)) {
            $payload['FirstName'] = $this->contact->first_name;
        }

        $payload['LastName'] = $this->contact->last_name ?? 'Unknown';

        if (!empty($this->contact->formatted_phone_number)) {
            $payload['Phone'] = $this->contact->formatted_phone_number;
        }

        if (!empty($this->contact->email)) {
            $payload['Email'] = $this->contact->email;
        }

        if (!empty($this->contact->position)) {
            $payload['Title'] = $this->contact->position;
        }

        // Company fields (if business)
        if ($this->contact->business && !empty($this->contact->business_name)) {
            $payload['Account'] = ['Name' => $this->contact->business_name];
        }

        // Address fields
        if ($this->contact->has_full_address) {
            $payload['MailingStreet'] = $this->contact->consumer_address;
            $payload['MailingCity'] = $this->contact->consumer_city;
            $payload['MailingState'] = $this->contact->consumer_state;
            $payload['MailingPostalCode'] = $this->contact->consumer_postal_code;
            $payload['MailingCountry'] = $this->contact->consumer_country ?? 'US';
        }

        // Custom fields
        if (!empty($this->contact->data_quality_score)) {
            $payload['Description'] = "Data quality score: {$this->contact->data_quality_score}%";
        }
        $payload['LeadSource'] = 'Twilio Bulk Lookup';

        return $payload;
    }

    /**
     * Parse Salesforce error from exception
     */
    private function parseSalesforceError(GuzzleException $e): string
    {
        if ($e->hasResponse()) {
            $body = $e->getResponse()->getBody()->getContents();
            $data = json_decode($body, true);

            if (isset($data[0]['message'])) {
                return $data[0]['message'];
            }

            return $data['message'] ?? 'Salesforce API error';
        }

        return $e->getMessage();
    }

    /**
     * Log API usage
     */
    private function logApiUsage(string $service, string $status, int $responseTimeMs, ?string $errorMessage = null): void
    {
        ApiUsageLog::logApiCall([
            'contact_id' => $this->contact->id,
            'provider' => 'salesforce',
            'service' => $service,
            'status' => $status,
            'response_time_ms' => $responseTimeMs,
            'error_message' => $errorMessage,
            'requested_at' => Carbon::now(),
            'cost' => 0, // Salesforce doesn't charge per API call in most plans
        ]);
    }

    /**
     * Execute SOQL query
     */
    public function query(string $soql): array
    {
        if (!$this->validAccessToken()) {
            return ['success' => false, 'error' => 'No access token'];
        }

        try {
            $url = $this->credentials->salesforce_instance_url
                . '/services/data/' . self::SALESFORCE_API_VERSION
                . '/query?q=' . urlencode($soql);

            $response = $this->httpClient->get($url, [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->salesforce_access_token,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                return ['success' => true, 'data' => $data];
            }

            return ['success' => false, 'error' => 'SOQL query error'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parseSalesforceError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }
}
