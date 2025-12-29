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
 * Pipedrive CRM Sync Service
 *
 * Syncs contacts to Pipedrive CRM using the Persons API.
 * Supports create, update, and batch operations.
 *
 * Features:
 * - Pipedrive Persons API integration
 * - Contact creation and updates
 * - Phone number normalization
 * - Custom fields mapping
 * - Organization linking
 * - Activity tracking
 * - API token authentication
 * - Batch operations
 * - Rate limiting
 */
class PipedriveService
{
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
     * Sync contact to Pipedrive
     */
    public function syncToPipedrive(): array
    {
        if (!$this->credentials?->enable_pipedrive_sync) {
            return ['success' => false, 'error' => 'Pipedrive sync not enabled'];
        }

        if (!$this->contact->crm_sync_enabled) {
            return ['success' => false, 'error' => 'CRM sync disabled for this contact'];
        }

        if (empty($this->credentials->pipedrive_api_key)) {
            return ['success' => false, 'error' => 'No Pipedrive API key'];
        }

        if (empty($this->credentials->pipedrive_company_domain)) {
            return ['success' => false, 'error' => 'No Pipedrive company domain configured'];
        }

        $startTime = microtime(true);

        try {
            // Create or update person
            if (!empty($this->contact->pipedrive_id)) {
                $result = $this->updatePipedrivePerson();
            } else {
                $result = $this->createPipedrivePerson();
            }

            // Update contact record
            if ($result['success']) {
                $this->contact->update([
                    'pipedrive_id' => $result['id'],
                    'pipedrive_synced_at' => Carbon::now(),
                    'pipedrive_sync_status' => 'synced',
                    'last_crm_sync_at' => Carbon::now(),
                ]);

                $responseTimeMs = (int) ((microtime(true) - $startTime) * 1000);
                $this->logApiUsage('sync_contact', 'success', $responseTimeMs);
            } else {
                $errors = $this->contact->crm_sync_errors ?? [];
                $errors['pipedrive'] = [
                    'error' => $result['error'],
                    'timestamp' => Carbon::now()->toIso8601String(),
                ];

                $this->contact->update([
                    'pipedrive_sync_status' => 'failed',
                    'crm_sync_errors' => $errors,
                ]);

                $responseTimeMs = (int) ((microtime(true) - $startTime) * 1000);
                $this->logApiUsage('sync_contact', 'failed', $responseTimeMs, $result['error']);
            }

            return $result;
        } catch (\Exception $e) {
            Log::error("Pipedrive sync error for contact {$this->contact->id}: {$e->getMessage()}");
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
            $result = $service->syncToPipedrive();

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
     * Get base API URL
     */
    private function baseUrl(): ?string
    {
        $companyDomain = $this->credentials?->pipedrive_company_domain;
        if (empty($companyDomain)) {
            return null;
        }

        return "https://{$companyDomain}.pipedrive.com/api/v1";
    }

    /**
     * Create Pipedrive person
     */
    private function createPipedrivePerson(): array
    {
        try {
            $url = $this->baseUrl() . '/persons';
            $body = $this->buildPipedrivePayload();

            $response = $this->httpClient->post($url, [
                'json' => $body,
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($response->getStatusCode() === 201) {
                $data = json_decode($response->getBody()->getContents(), true);
                return [
                    'success' => true,
                    'id' => (string) ($data['data']['id'] ?? ''),
                    'action' => 'created',
                ];
            }

            return ['success' => false, 'error' => 'Pipedrive create error'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parsePipedriveError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }

    /**
     * Update Pipedrive person
     */
    private function updatePipedrivePerson(): array
    {
        try {
            $url = $this->baseUrl() . '/persons/' . $this->contact->pipedrive_id;
            $body = $this->buildPipedrivePayload();

            $response = $this->httpClient->put($url, [
                'json' => $body,
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                return [
                    'success' => true,
                    'id' => $this->contact->pipedrive_id,
                    'action' => 'updated',
                ];
            }

            return ['success' => false, 'error' => 'Pipedrive update error'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parsePipedriveError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }

    /**
     * Build Pipedrive payload from contact
     */
    private function buildPipedrivePayload(): array
    {
        $payload = [];

        // Name (required field)
        $name = $this->contact->full_name ?? $this->contact->business_name ?? 'Unknown';
        $payload['name'] = $name;

        // Email (array format)
        if (!empty($this->contact->email)) {
            $payload['email'] = [
                ['value' => $this->contact->email, 'primary' => true],
            ];
        }

        // Phone (array format)
        if (!empty($this->contact->formatted_phone_number)) {
            $payload['phone'] = [
                ['value' => $this->contact->formatted_phone_number, 'primary' => true],
            ];
        }

        // Organization linking
        if (!empty($this->contact->business_name)) {
            $orgId = $this->findOrCreateOrganization();
            if ($orgId) {
                $payload['org_id'] = $orgId;
            }
        }

        return $payload;
    }

    /**
     * Find or create organization in Pipedrive
     */
    private function findOrCreateOrganization(): ?int
    {
        if (empty($this->contact->business_name)) {
            return null;
        }

        try {
            // First, search for existing organization
            $searchUrl = $this->baseUrl() . '/organizations/search';
            $searchResponse = $this->httpClient->get($searchUrl, [
                'query' => [
                    'term' => $this->contact->business_name,
                    'exact_match' => true,
                ],
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                ],
            ]);

            if ($searchResponse->getStatusCode() === 200) {
                $searchData = json_decode($searchResponse->getBody()->getContents(), true);
                if (!empty($searchData['data']['items'][0]['item']['id'])) {
                    return $searchData['data']['items'][0]['item']['id'];
                }
            }

            // If not found, create new organization
            $createUrl = $this->baseUrl() . '/organizations';
            $createResponse = $this->httpClient->post($createUrl, [
                'json' => ['name' => $this->contact->business_name],
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($createResponse->getStatusCode() === 201) {
                $createData = json_decode($createResponse->getBody()->getContents(), true);
                return $createData['data']['id'] ?? null;
            }

            return null;
        } catch (\Exception $e) {
            Log::warning("Pipedrive organization creation failed: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Create activity for a person
     */
    public function createActivity(string $subject, string $type = 'call', ?string $note = null): array
    {
        if (empty($this->contact->pipedrive_id)) {
            return ['success' => false, 'error' => 'Contact not synced to Pipedrive'];
        }

        try {
            $url = $this->baseUrl() . '/activities';
            $body = [
                'subject' => $subject,
                'type' => $type,
                'person_id' => (int) $this->contact->pipedrive_id,
                'done' => 0,
            ];

            if ($note) {
                $body['note'] = $note;
            }

            $response = $this->httpClient->post($url, [
                'json' => $body,
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                    'Content-Type' => 'application/json',
                ],
            ]);

            if ($response->getStatusCode() === 201) {
                $data = json_decode($response->getBody()->getContents(), true);
                return [
                    'success' => true,
                    'id' => $data['data']['id'] ?? null,
                ];
            }

            return ['success' => false, 'error' => 'Failed to create activity'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parsePipedriveError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }

    /**
     * Search persons in Pipedrive
     */
    public function searchPersons(string $term): array
    {
        try {
            $url = $this->baseUrl() . '/persons/search';

            $response = $this->httpClient->get($url, [
                'query' => ['term' => $term],
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                return ['success' => true, 'data' => $data['data']['items'] ?? []];
            }

            return ['success' => false, 'error' => 'Search failed'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parsePipedriveError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }

    /**
     * Get person details from Pipedrive
     */
    public function getPerson(string $personId): array
    {
        try {
            $url = $this->baseUrl() . '/persons/' . $personId;

            $response = $this->httpClient->get($url, [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                return ['success' => true, 'data' => $data['data'] ?? null];
            }

            return ['success' => false, 'error' => 'Person not found'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parsePipedriveError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }

    /**
     * Parse Pipedrive error from exception
     */
    private function parsePipedriveError(GuzzleException $e): string
    {
        if ($e->hasResponse()) {
            $body = $e->getResponse()->getBody()->getContents();
            $data = json_decode($body, true);
            return $data['error'] ?? $data['error_info'] ?? 'Pipedrive API error';
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
            'provider' => 'pipedrive',
            'service' => $service,
            'status' => $status,
            'response_time_ms' => $responseTimeMs,
            'error_message' => $errorMessage,
            'requested_at' => Carbon::now(),
            'cost' => 0,
        ]);
    }

    /**
     * Normalize phone number for Pipedrive
     */
    private function normalizePhoneNumber(?string $phone): ?string
    {
        if (empty($phone)) {
            return null;
        }

        // Remove all non-numeric characters except +
        $normalized = preg_replace('/[^0-9+]/', '', $phone);

        // Ensure it starts with +
        if (!str_starts_with($normalized, '+')) {
            // Assume US number if no country code
            if (strlen($normalized) === 10) {
                $normalized = '+1' . $normalized;
            }
        }

        return $normalized;
    }

    /**
     * Get custom fields from Pipedrive
     */
    public function getCustomFields(): array
    {
        try {
            $url = $this->baseUrl() . '/personFields';

            $response = $this->httpClient->get($url, [
                'headers' => [
                    'Authorization' => 'Bearer ' . $this->credentials->pipedrive_api_key,
                ],
            ]);

            if ($response->getStatusCode() === 200) {
                $data = json_decode($response->getBody()->getContents(), true);
                return ['success' => true, 'data' => $data['data'] ?? []];
            }

            return ['success' => false, 'error' => 'Failed to fetch custom fields'];
        } catch (GuzzleException $e) {
            $errorMessage = $this->parsePipedriveError($e);
            return ['success' => false, 'error' => $errorMessage];
        }
    }
}
