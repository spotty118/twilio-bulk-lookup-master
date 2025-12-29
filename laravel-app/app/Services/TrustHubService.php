<?php

namespace App\Services;

use App\Models\Contact;
use App\Models\TwilioCredential;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Twilio\Rest\Client as TwilioClient;
use Twilio\Exceptions\TwilioException;

/**
 * TrustHubService - Twilio Trust Hub regulatory compliance verification
 *
 * This service integrates with Twilio's Trust Hub API to:
 * - Verify business profiles
 * - Create regulatory compliance bundles
 * - Check compliance status
 * - Manage business verification SIDs
 * - Calculate verification scores
 *
 * Trust Hub is required for A2P (Application-to-Person) messaging compliance
 * and helps verify business legitimacy for telecommunications services.
 *
 * Usage:
 *   $result = TrustHubService::enrich($contact);
 */
class TrustHubService
{
    private Contact $contact;
    private ?string $phoneNumber;
    private ?TwilioCredential $credentials;
    private ?TwilioClient $twilioClient = null;

    /**
     * Cache TTL - 7 days (verification status may change)
     */
    private const CACHE_TTL = 60 * 60 * 24 * 7;

    /**
     * Reverification interval - 90 days
     */
    private const REVERIFY_INTERVAL_DAYS = 90;

    /**
     * Trust Hub policy SID for business profiles
     * This is Twilio's default business profile policy
     */
    private const DEFAULT_POLICY_SID = 'RNb0d4771c2c98518d0cbc1ae32c55c3e8';

    public function __construct(Contact $contact)
    {
        $this->contact = $contact;
        $this->phoneNumber = $contact->formatted_phone_number ?? $contact->raw_phone_number;
        $this->credentials = TwilioCredential::current();
    }

    /**
     * Main entry point for enriching contact with Trust Hub verification data
     *
     * @param Contact $contact Contact to enrich
     * @return bool Success status
     */
    public static function enrich(Contact $contact): bool
    {
        return (new self($contact))->enrichContact();
    }

    /**
     * Enrich contact with Trust Hub data
     *
     * @return bool Success status
     */
    public function enrichContact(): bool
    {
        // Only enrich if it's a business and Trust Hub is enabled
        if (!$this->shouldEnrich()) {
            return false;
        }

        if (!$this->trustHubEnabled()) {
            return false;
        }

        try {
            // Try to find or create Trust Hub verification
            $result = $this->lookupTrustHubVerification() ?? $this->createTrustHubVerification();

            if ($result) {
                $this->updateContactWithTrustHubData($result);
                return true;
            }

            $this->logNoDataFound();
            return false;
        } catch (\Exception $e) {
            $this->handleError($e);
            return false;
        }
    }

    /**
     * Check if contact should be enriched
     *
     * @return bool
     */
    private function shouldEnrich(): bool
    {
        // Only enrich businesses that haven't been enriched yet or need re-verification
        return $this->contact->is_business
            && (!$this->contact->trust_hub_enriched || $this->shouldReverify());
    }

    /**
     * Check if contact needs re-verification
     *
     * @return bool
     */
    private function shouldReverify(): bool
    {
        // Re-verify if status is pending or failed
        if (in_array($this->contact->trust_hub_status, ['pending-review', 'twilio-rejected', 'draft'])) {
            return true;
        }

        // Or if enriched more than 90 days ago
        if (!$this->contact->trust_hub_enriched_at) {
            return false;
        }

        return $this->contact->trust_hub_enriched_at < now()->subDays(self::REVERIFY_INTERVAL_DAYS);
    }

    /**
     * Check if Trust Hub is enabled
     *
     * @return bool
     */
    private function trustHubEnabled(): bool
    {
        return $this->credentials && ($this->credentials->enable_trust_hub ?? false);
    }

    /**
     * Get Twilio client instance
     *
     * @return TwilioClient
     */
    private function twilioClient(): TwilioClient
    {
        if (!$this->twilioClient) {
            $this->twilioClient = new TwilioClient(
                $this->credentials->account_sid,
                $this->credentials->auth_token
            );
        }

        return $this->twilioClient;
    }

    /**
     * Lookup existing Trust Hub customer profile by phone number/business name
     *
     * @return array|null Trust Hub data or null
     */
    private function lookupTrustHubVerification(): ?array
    {
        if (empty($this->contact->business_name)) {
            return null;
        }

        $cacheKey = "trust_hub:" . md5($this->contact->business_name);

        // Check cache first
        $cached = Cache::get($cacheKey);
        if ($cached !== null) {
            return $cached ?: null;
        }

        try {
            // Use circuit breaker for Trust Hub API
            $result = CircuitBreakerService::call('twilio_trust_hub', function () {
                return $this->twilioClient()
                    ->trusthub->v1->customerProfiles
                    ->read([], 20);
            });

            // Handle circuit breaker fallback
            if (is_array($result) && isset($result['circuit_open'])) {
                return null;
            }

            // Try to find a matching profile by business name
            $matchingProfile = null;
            foreach ($result as $profile) {
                if ($this->matchesProfile($profile)) {
                    $matchingProfile = $profile;
                    break;
                }
            }

            if (!$matchingProfile) {
                Cache::put($cacheKey, false, 3600); // Cache negative result for 1 hour
                return null;
            }

            // Get detailed profile information
            $profileData = $this->fetchProfileDetails($matchingProfile);
            Cache::put($cacheKey, $profileData, self::CACHE_TTL);
            return $profileData;
        } catch (TwilioException $e) {
            Log::warning("Trust Hub lookup error: {$e->getMessage()}");
            Cache::put($cacheKey, false, 3600);
            return null;
        }
    }

    /**
     * Check if profile matches contact
     *
     * @param object $profile Twilio customer profile object
     * @return bool
     */
    private function matchesProfile($profile): bool
    {
        if (empty($profile->friendlyName)) {
            return false;
        }

        $businessNameNormalized = $this->normalizeName($this->contact->business_name);
        $profileNameNormalized = $this->normalizeName($profile->friendlyName);

        return str_contains($profileNameNormalized, $businessNameNormalized)
            || str_contains($businessNameNormalized, $profileNameNormalized);
    }

    /**
     * Normalize name for comparison
     *
     * @param string|null $name Name to normalize
     * @return string Normalized name
     */
    private function normalizeName(?string $name): string
    {
        if (!$name) {
            return '';
        }

        return preg_replace('/[^a-z0-9]/', '', strtolower($name));
    }

    /**
     * Create new Trust Hub customer profile for verification
     *
     * @return array|null Trust Hub data or null
     */
    private function createTrustHubVerification(): ?array
    {
        if (!$this->canCreateProfile()) {
            return null;
        }

        try {
            // Use circuit breaker for Trust Hub API
            $profile = CircuitBreakerService::call('twilio_trust_hub', function () {
                return $this->twilioClient()
                    ->trusthub->v1->customerProfiles
                    ->create([
                        'friendlyName' => $this->contact->business_name,
                        'email' => $this->inferBusinessEmail(),
                        'policySid' => $this->getPolicySid(),
                        'statusCallback' => $this->getStatusCallbackUrl(),
                    ]);
            });

            // Handle circuit breaker fallback
            if (is_array($profile) && isset($profile['circuit_open'])) {
                return null;
            }

            // Add business information to the profile
            $this->addBusinessInformation($profile);

            return [
                'status' => 'draft',
                'customer_profile_sid' => $profile->sid,
                'business_name' => $this->contact->business_name,
                'verification_score' => 0,
                'verification_data' => [
                    'profile_sid' => $profile->sid,
                    'created' => true,
                    'requires_documents' => true,
                ],
            ];
        } catch (TwilioException $e) {
            Log::error("Trust Hub creation error: {$e->getMessage()}");
            $this->contact->update(['trust_hub_error' => $e->getMessage()]);
            return null;
        }
    }

    /**
     * Check if we can create a customer profile
     *
     * @return bool
     */
    private function canCreateProfile(): bool
    {
        // Need business name and some contact info to create profile
        return !empty($this->contact->business_name)
            && (!empty($this->contact->business_email_domain)
                || !empty($this->contact->business_address));
    }

    /**
     * Infer business email from domain
     *
     * @return string|null
     */
    private function inferBusinessEmail(): ?string
    {
        if (empty($this->contact->business_email_domain)) {
            return null;
        }

        return "info@{$this->contact->business_email_domain}";
    }

    /**
     * Get Trust Hub policy SID
     *
     * @return string
     */
    private function getPolicySid(): string
    {
        return $this->credentials->trust_hub_policy_sid ?? self::DEFAULT_POLICY_SID;
    }

    /**
     * Get status callback URL
     *
     * @return string|null
     */
    private function getStatusCallbackUrl(): ?string
    {
        return $this->credentials->trust_hub_webhook_url ?? null;
    }

    /**
     * Add business information to customer profile
     *
     * @param object $profile Twilio customer profile
     * @return void
     */
    private function addBusinessInformation($profile): void
    {
        try {
            // Create end user (business entity)
            $endUser = $this->twilioClient()
                ->trusthub->v1->endUsers
                ->create([
                    'friendlyName' => $this->contact->business_name,
                    'type' => 'business',
                    'attributes' => array_filter([
                        'business_name' => $this->contact->business_name,
                        'business_registration_number' => $this->contact->trust_hub_registration_number,
                        'business_type' => $this->mapBusinessType($this->contact->business_type),
                        'phone_number' => $this->phoneNumber,
                        'email' => $this->inferBusinessEmail(),
                    ]),
                ]);

            // Assign end user to customer profile
            $this->twilioClient()
                ->trusthub->v1
                ->customerProfiles($profile->sid)
                ->customerProfilesEntityAssignments
                ->create(['objectSid' => $endUser->sid]);
        } catch (TwilioException $e) {
            Log::warning("Could not add business info to Trust Hub profile: {$e->getMessage()}");
        }
    }

    /**
     * Map business type to Twilio's expected format
     *
     * @param string|null $type Business type
     * @return string Mapped business type
     */
    private function mapBusinessType(?string $type): string
    {
        $type = strtolower($type ?? '');

        return match (true) {
            in_array($type, ['corporation', 'corp', 'inc']) => 'corporation',
            in_array($type, ['llc', 'limited liability company']) => 'llc',
            $type === 'partnership' => 'partnership',
            in_array($type, ['sole proprietorship', 'individual']) => 'sole_proprietorship',
            in_array($type, ['non-profit', 'nonprofit']) => 'non_profit',
            default => 'other',
        };
    }

    /**
     * Fetch detailed information about a customer profile
     *
     * @param object $profile Twilio customer profile
     * @return array|null Profile data or null
     */
    private function fetchProfileDetails($profile): ?array
    {
        try {
            // Get the full profile with all assignments
            $fullProfile = $this->twilioClient()
                ->trusthub->v1
                ->customerProfiles($profile->sid)
                ->fetch();

            // Calculate verification score based on status and completeness
            $verificationScore = $this->calculateVerificationScore($fullProfile);

            // Get trust products associated with this profile (if any)
            $trustProducts = $this->getTrustProducts($profile->sid);

            return [
                'status' => $fullProfile->status,
                'customer_profile_sid' => $fullProfile->sid,
                'business_name' => $fullProfile->friendlyName,
                'business_type' => null, // Would need to query end_users
                'registration_number' => null, // Would need to query end_users
                'regulatory_status' => $fullProfile->status,
                'compliance_type' => $fullProfile->policySid,
                'verification_score' => $verificationScore,
                'verification_data' => [
                    'profile_sid' => $fullProfile->sid,
                    'policy_sid' => $fullProfile->policySid,
                    'status' => $fullProfile->status,
                    'valid_until' => $fullProfile->validUntil ?? null,
                    'trust_products' => $trustProducts,
                ],
                'checks_completed' => [],
                'checks_failed' => [],
                'verified_at' => $fullProfile->dateUpdated,
            ];
        } catch (TwilioException $e) {
            Log::error("Error fetching Trust Hub details: {$e->getMessage()}");
            return null;
        }
    }

    /**
     * Get trust products associated with customer profile
     *
     * @param string $customerProfileSid Customer profile SID
     * @return array Trust products
     */
    private function getTrustProducts(string $customerProfileSid): array
    {
        try {
            $products = $this->twilioClient()
                ->trusthub->v1
                ->trustProducts
                ->read([], 20);

            return collect($products)
                ->filter(fn($p) => $p->customerProfileSid === $customerProfileSid)
                ->map(fn($p) => [
                    'sid' => $p->sid,
                    'status' => $p->status,
                    'policy_sid' => $p->policySid,
                ])
                ->values()
                ->all();
        } catch (TwilioException $e) {
            Log::warning("Could not fetch trust products: {$e->getMessage()}");
            return [];
        }
    }

    /**
     * Calculate verification score based on profile status
     *
     * @param object $profile Twilio customer profile
     * @return int Score (0-100)
     */
    private function calculateVerificationScore($profile): int
    {
        return match ($profile->status) {
            'twilio-approved' => 100,
            'compliant' => 95,
            'pending-review' => 50,
            'in-review' => 60,
            'twilio-rejected', 'rejected' => 0,
            'draft' => 10,
            default => 25,
        };
    }

    /**
     * Update contact with Trust Hub data
     *
     * @param array $data Trust Hub data
     * @return void
     */
    private function updateContactWithTrustHubData(array $data): void
    {
        $this->contact->update([
            'trust_hub_verified' => in_array($data['status'], ['twilio-approved', 'compliant']),
            'trust_hub_status' => $data['status'],
            'trust_hub_customer_profile_sid' => $data['customer_profile_sid'] ?? null,
            'trust_hub_business_name' => $data['business_name'] ?? null,
            'trust_hub_business_type' => $data['business_type'] ?? null,
            'trust_hub_registration_number' => $data['registration_number'] ?? null,
            'trust_hub_regulatory_status' => $data['regulatory_status'] ?? null,
            'trust_hub_compliance_type' => $data['compliance_type'] ?? null,
            'trust_hub_verified_at' => $data['verified_at'] ?? now(),
            'trust_hub_verification_score' => $data['verification_score'] ?? 0,
            'trust_hub_verification_data' => $data['verification_data'] ?? null,
            'trust_hub_checks_completed' => $data['checks_completed'] ?? [],
            'trust_hub_checks_failed' => $data['checks_failed'] ?? [],
            'trust_hub_enriched' => true,
            'trust_hub_enriched_at' => now(),
            'trust_hub_error' => null,
        ]);
    }

    /**
     * Log when no data is found
     *
     * @return void
     */
    private function logNoDataFound(): void
    {
        Log::info("No Trust Hub data found for {$this->phoneNumber}");
    }

    /**
     * Handle errors during enrichment
     *
     * @param \Exception $error Exception that occurred
     * @return void
     */
    private function handleError(\Exception $error): void
    {
        $errorMessage = "Trust Hub enrichment error for {$this->phoneNumber}: {$error->getMessage()}";
        Log::error($errorMessage);

        $this->contact->update([
            'trust_hub_error' => $error->getMessage(),
            'trust_hub_enriched_at' => now(),
        ]);
    }
}
