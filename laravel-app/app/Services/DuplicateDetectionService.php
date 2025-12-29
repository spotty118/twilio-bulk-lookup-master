<?php

namespace App\Services;

use App\Models\Contact;
use App\Models\TwilioCredential;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Exception;

/**
 * DuplicateDetectionService - Finds and merges duplicate contacts
 *
 * This service implements sophisticated duplicate detection using:
 * - Phone number normalization (E.164 format)
 * - Fuzzy matching for business names (Levenshtein distance)
 * - Email domain matching
 * - Address similarity scoring
 * - Phonetic matching (Soundex/Metaphone)
 * - Duplicate fingerprint generation
 * - Confidence scoring (0-100)
 *
 * Usage:
 *   // Find duplicates
 *   $duplicates = DuplicateDetectionService::findDuplicates($contact);
 *
 *   // Merge contacts
 *   DuplicateDetectionService::merge($primaryContact, $duplicateContact);
 */
class DuplicateDetectionService
{
    /** @var Contact */
    private $contact;

    /**
     * Find all duplicates for a contact
     *
     * @param Contact $contact Contact to check for duplicates
     * @return array Array of duplicate candidates with confidence scores
     */
    public static function findDuplicates(Contact $contact): array
    {
        return (new self($contact))->find();
    }

    /**
     * Merge two contacts
     *
     * @param Contact $primaryContact Primary contact (will be kept)
     * @param Contact $duplicateContact Duplicate contact (will be marked as duplicate)
     * @return bool Success status
     */
    public static function merge(Contact $primaryContact, Contact $duplicateContact): bool
    {
        return (new self($primaryContact))->mergeWith($duplicateContact);
    }

    /**
     * Constructor
     *
     * @param Contact $contact Contact instance
     */
    public function __construct(Contact $contact)
    {
        $this->contact = $contact;
    }

    /**
     * Find all duplicate candidates for the contact
     *
     * @return array Scored and ranked duplicate candidates
     */
    public function find(): array
    {
        // Don't search for duplicates if this contact is already marked as duplicate
        if ($this->contact->is_duplicate) {
            return [];
        }

        $candidates = [];

        // Phone number exact match
        if (!empty($this->contact->formatted_phone_number)) {
            $candidates = array_merge($candidates, $this->findByPhoneExact());
        }

        // Phone number fuzzy match (fingerprint-based)
        if (!empty($this->contact->raw_phone_number)) {
            $candidates = array_merge($candidates, $this->findByPhoneFuzzy());
        }

        // Email exact match
        if (!empty($this->contact->email)) {
            $candidates = array_merge($candidates, $this->findByEmail());
        }

        // Business name + location match
        if ($this->contact->is_business) {
            $candidates = array_merge($candidates, $this->findByBusinessIdentity());
        }

        // Name match (for consumer contacts)
        if (!empty($this->contact->full_name)) {
            $candidates = array_merge($candidates, $this->findByName());
        }

        // Remove duplicates and score candidates
        $uniqueCandidates = collect($candidates)
            ->unique('id')
            ->map(function ($candidate) {
                $confidence = $this->calculateMatchConfidence($this->contact, $candidate);
                $reason = $this->determineMatchReason($this->contact, $candidate);

                return [
                    'contact' => $candidate,
                    'confidence' => $confidence,
                    'reason' => $reason,
                ];
            })
            ->filter(function ($item) {
                // Filter by confidence threshold
                $threshold = TwilioCredential::current()?->duplicate_confidence_threshold ?? 80;
                return $item['confidence'] >= $threshold;
            })
            ->sortByDesc('confidence')
            ->values()
            ->all();

        return $uniqueCandidates;
    }

    /**
     * Merge duplicate contact into primary contact
     *
     * @param Contact $duplicateContact Contact to merge (will be marked as duplicate)
     * @return bool Success status
     */
    public function mergeWith(Contact $duplicateContact): bool
    {
        // Can't merge contact with itself
        if ($this->contact->id === $duplicateContact->id) {
            return false;
        }

        try {
            return DB::transaction(function () use ($duplicateContact) {
                // Lock both contacts to prevent concurrent modifications
                $ids = [$this->contact->id, $duplicateContact->id];
                sort($ids);

                $locked = Contact::lockForUpdate()
                    ->whereIn('id', $ids)
                    ->orderBy('id')
                    ->get()
                    ->keyBy('id');

                $primary = $locked->get($this->contact->id);
                $duplicate = $locked->get($duplicateContact->id);

                if (!$primary || !$duplicate) {
                    return false;
                }

                // Double-check neither is already a duplicate after acquiring lock
                if ($primary->is_duplicate || $duplicate->is_duplicate) {
                    return false;
                }

                // Merge all data, preferring primary contact's data
                $mergedData = $this->mergeData($primary, $duplicate);
                $mergedData['duplicate_checked_at'] = now();

                // Update primary contact with merged data
                $primary->update($mergedData);

                // Record merge history
                $mergeRecord = [
                    'merged_at' => now()->toIso8601String(),
                    'duplicate_id' => $duplicate->id,
                    'duplicate_data' => collect($duplicate->getAttributes())
                        ->except(['id', 'created_at', 'updated_at'])
                        ->all(),
                ];

                // Update merge history
                $mergeHistory = $primary->merge_history ?? [];
                $mergeHistory[] = $mergeRecord;
                $primary->merge_history = $mergeHistory;
                $primary->save();

                // Mark duplicate as merged
                $duplicate->update([
                    'is_duplicate' => true,
                    'duplicate_of_id' => $primary->id,
                    'duplicate_confidence' => 100,
                    'duplicate_checked_at' => now(),
                ]);

                // Update fingerprints and quality scores
                if (method_exists($primary, 'updateFingerprints')) {
                    $primary->updateFingerprints();
                }
                if (method_exists($primary, 'calculateQualityScore')) {
                    $primary->calculateQualityScore();
                }

                // Reload the contact instance
                $this->contact->refresh();

                return true;
            });
        } catch (Exception $e) {
            Log::error("Merge failed: {$e->getMessage()}");
            return false;
        }
    }

    /**
     * Find contacts with exact phone number match
     *
     * @return array Matching contacts
     */
    private function findByPhoneExact(): array
    {
        if (empty($this->contact->formatted_phone_number)) {
            return [];
        }

        return Contact::where('formatted_phone_number', $this->contact->formatted_phone_number)
            ->where('id', '!=', $this->contact->id)
            ->where('is_duplicate', false)
            ->get()
            ->all();
    }

    /**
     * Find contacts with fuzzy phone number match (using fingerprint)
     *
     * @return array Matching contacts
     */
    private function findByPhoneFuzzy(): array
    {
        if (empty($this->contact->phone_fingerprint)) {
            return [];
        }

        return Contact::where('phone_fingerprint', $this->contact->phone_fingerprint)
            ->where('id', '!=', $this->contact->id)
            ->where('is_duplicate', false)
            ->get()
            ->all();
    }

    /**
     * Find contacts with matching email
     *
     * @return array Matching contacts
     */
    private function findByEmail(): array
    {
        if (empty($this->contact->email)) {
            return [];
        }

        if (!empty($this->contact->email_fingerprint)) {
            return Contact::where('email_fingerprint', $this->contact->email_fingerprint)
                ->where('id', '!=', $this->contact->id)
                ->where('is_duplicate', false)
                ->get()
                ->all();
        }

        return Contact::where('email', $this->contact->email)
            ->where('id', '!=', $this->contact->id)
            ->where('is_duplicate', false)
            ->get()
            ->all();
    }

    /**
     * Find contacts with matching business identity (name + location)
     *
     * @return array Matching contacts
     */
    private function findByBusinessIdentity(): array
    {
        if (empty($this->contact->business_name)) {
            return [];
        }

        $query = Contact::where('is_business', true)
            ->where('id', '!=', $this->contact->id)
            ->where('is_duplicate', false);

        // Match on business name fingerprint or exact name
        if (!empty($this->contact->name_fingerprint)) {
            $query->where('name_fingerprint', $this->contact->name_fingerprint);
        } else {
            $query->where('business_name', $this->contact->business_name);
        }

        // Further filter by location if available
        if (!empty($this->contact->business_city)) {
            $query->where('business_city', $this->contact->business_city);
        }

        return $query->get()->all();
    }

    /**
     * Find contacts with matching name (for consumer contacts)
     *
     * @return array Matching contacts
     */
    private function findByName(): array
    {
        if (empty($this->contact->name_fingerprint)) {
            return [];
        }

        return Contact::where('name_fingerprint', $this->contact->name_fingerprint)
            ->where('id', '!=', $this->contact->id)
            ->where('is_duplicate', false)
            ->get()
            ->all();
    }

    /**
     * Calculate match confidence score (0-100)
     *
     * Weighted scoring:
     * - Phone number: 40 points (highest weight)
     * - Email: 30 points
     * - Name/Business name: 20 points
     * - Location: 10 points
     *
     * @param Contact $contact1 First contact
     * @param Contact $contact2 Second contact
     * @return int Confidence score (0-100)
     */
    private function calculateMatchConfidence(Contact $contact1, Contact $contact2): int
    {
        // Skip empty contacts - no meaningful data to compare
        if ($this->isEmptyContact($contact1) || $this->isEmptyContact($contact2)) {
            return 0;
        }

        $score = 0;
        $maxScore = 0;

        // Phone number match (highest weight: 40 points)
        $maxScore += 40;
        if (!empty($contact1->formatted_phone_number) && !empty($contact2->formatted_phone_number)) {
            if ($contact1->formatted_phone_number === $contact2->formatted_phone_number) {
                $score += 40;
            } elseif ($this->phoneSimilarity($contact1->raw_phone_number, $contact2->raw_phone_number) > 0.8) {
                $score += 30;
            }
        }

        // Email match (30 points)
        $maxScore += 30;
        if (!empty($contact1->email) && !empty($contact2->email)) {
            if (strtolower($contact1->email) === strtolower($contact2->email)) {
                $score += 30;
            } elseif ($this->emailDomainMatch($contact1->email, $contact2->email)) {
                $score += 15;
            }
        }

        // Name match (20 points - for businesses or people)
        $maxScore += 20;
        if ($contact1->is_business) {
            if (!empty($contact1->business_name) && !empty($contact2->business_name)) {
                $similarity = $this->stringSimilarity($contact1->business_name, $contact2->business_name);
                $score += (int) ($similarity * 20);
            }
        } elseif (!empty($contact1->full_name) && !empty($contact2->full_name)) {
            $similarity = $this->stringSimilarity($contact1->full_name, $contact2->full_name);
            $score += (int) ($similarity * 20);
        }

        // Location match (10 points - for businesses)
        $maxScore += 10;
        if (!empty($contact1->business_city) && !empty($contact2->business_city)) {
            if (strtolower($contact1->business_city) === strtolower($contact2->business_city)) {
                $score += 10;
            }
        }

        // Return percentage confidence
        return $maxScore > 0 ? (int) round(($score / $maxScore) * 100) : 0;
    }

    /**
     * Check if contact has no meaningful data
     *
     * @param Contact $contact Contact to check
     * @return bool True if contact is empty
     */
    private function isEmptyContact(Contact $contact): bool
    {
        return empty($contact->formatted_phone_number)
            && empty($contact->email)
            && empty($contact->full_name)
            && empty($contact->business_name);
    }

    /**
     * Calculate phone number similarity (0.0-1.0)
     *
     * Uses Levenshtein distance on last 10 digits
     *
     * @param string|null $phone1 First phone number
     * @param string|null $phone2 Second phone number
     * @return float Similarity score (0.0-1.0)
     */
    private function phoneSimilarity(?string $phone1, ?string $phone2): float
    {
        if (empty($phone1) || empty($phone2)) {
            return 0.0;
        }

        // Remove all non-digits
        $p1 = preg_replace('/\D/', '', $phone1);
        $p2 = preg_replace('/\D/', '', $phone2);

        // Check last 10 digits (for international numbers)
        $p1Last10 = strlen($p1) > 10 ? substr($p1, -10) : $p1;
        $p2Last10 = strlen($p2) > 10 ? substr($p2, -10) : $p2;

        if ($p1Last10 === $p2Last10) {
            return 1.0;
        }

        // Levenshtein distance
        $distance = $this->levenshteinDistance($p1Last10, $p2Last10);
        $maxLength = max(strlen($p1Last10), strlen($p2Last10));

        if ($maxLength === 0) {
            return 0.0;
        }

        return 1.0 - ($distance / $maxLength);
    }

    /**
     * Check if two emails have the same domain
     *
     * @param string|null $email1 First email
     * @param string|null $email2 Second email
     * @return bool True if domains match
     */
    private function emailDomainMatch(?string $email1, ?string $email2): bool
    {
        if (empty($email1) || empty($email2)) {
            return false;
        }

        if (!str_contains($email1, '@') || !str_contains($email2, '@')) {
            return false;
        }

        $domain1 = strtolower(substr(strrchr($email1, '@'), 1));
        $domain2 = strtolower(substr(strrchr($email2, '@'), 1));

        return $domain1 === $domain2;
    }

    /**
     * Determine the reason for match between two contacts
     *
     * @param Contact $contact1 First contact
     * @param Contact $contact2 Second contact
     * @return string Human-readable match reason
     */
    private function determineMatchReason(Contact $contact1, Contact $contact2): string
    {
        $reasons = [];

        // Check phone match
        if (!empty($contact1->formatted_phone_number) && !empty($contact2->formatted_phone_number)) {
            if ($contact1->formatted_phone_number === $contact2->formatted_phone_number) {
                $reasons[] = 'Exact phone match';
            } elseif ($this->phoneSimilarity($contact1->raw_phone_number, $contact2->raw_phone_number) > 0.8) {
                $reasons[] = 'Similar phone number';
            }
        }

        // Check email match
        if (!empty($contact1->email) && !empty($contact2->email)) {
            if (strtolower($contact1->email) === strtolower($contact2->email)) {
                $reasons[] = 'Exact email match';
            } elseif ($this->emailDomainMatch($contact1->email, $contact2->email)) {
                $reasons[] = 'Same email domain';
            }
        }

        // Check business name match
        if ($contact1->is_business && !empty($contact1->business_name) && !empty($contact2->business_name)) {
            $similarity = $this->stringSimilarity($contact1->business_name, $contact2->business_name);
            if ($similarity > 0.7) {
                $reasons[] = sprintf('Similar business name (%d%%)', (int) round($similarity * 100));
            }
        }

        // Check person name match
        if (!$contact1->is_business && !empty($contact1->full_name) && !empty($contact2->full_name)) {
            $similarity = $this->stringSimilarity($contact1->full_name, $contact2->full_name);
            if ($similarity > 0.7) {
                $reasons[] = sprintf('Similar name (%d%%)', (int) round($similarity * 100));
            }
        }

        // Check location match
        if (!empty($contact1->business_city) && !empty($contact2->business_city)) {
            if (strtolower($contact1->business_city) === strtolower($contact2->business_city)) {
                $reasons[] = 'Same city';
            }
        }

        return !empty($reasons) ? implode(', ', $reasons) : 'Multiple field similarities';
    }

    /**
     * Calculate string similarity using Levenshtein distance (0.0-1.0)
     *
     * @param string|null $str1 First string
     * @param string|null $str2 Second string
     * @return float Similarity score (0.0-1.0)
     */
    private function stringSimilarity(?string $str1, ?string $str2): float
    {
        if (empty($str1) || empty($str2)) {
            return 0.0;
        }

        $s1 = strtolower(trim($str1));
        $s2 = strtolower(trim($str2));

        if ($s1 === $s2) {
            return 1.0;
        }

        // Levenshtein distance
        $distance = $this->levenshteinDistance($s1, $s2);
        $maxLength = max(strlen($s1), strlen($s2));

        if ($maxLength === 0) {
            return 0.0;
        }

        return 1.0 - ($distance / $maxLength);
    }

    /**
     * Calculate Levenshtein distance between two strings
     *
     * Measures the minimum number of single-character edits (insertions,
     * deletions, or substitutions) required to change one string into another.
     *
     * @param string $s1 First string
     * @param string $s2 Second string
     * @return int Edit distance
     */
    private function levenshteinDistance(string $s1, string $s2): int
    {
        if (empty($s1)) {
            return strlen($s2);
        }
        if (empty($s2)) {
            return strlen($s1);
        }

        $len1 = strlen($s1);
        $len2 = strlen($s2);

        // Initialize matrix
        $matrix = array_fill(0, $len1 + 1, array_fill(0, $len2 + 1, 0));

        // Fill first column and row
        for ($i = 0; $i <= $len1; $i++) {
            $matrix[$i][0] = $i;
        }
        for ($j = 0; $j <= $len2; $j++) {
            $matrix[0][$j] = $j;
        }

        // Calculate distances
        for ($i = 1; $i <= $len1; $i++) {
            for ($j = 1; $j <= $len2; $j++) {
                $cost = $s1[$i - 1] === $s2[$j - 1] ? 0 : 1;
                $matrix[$i][$j] = min(
                    $matrix[$i - 1][$j] + 1,      // deletion
                    $matrix[$i][$j - 1] + 1,      // insertion
                    $matrix[$i - 1][$j - 1] + $cost // substitution
                );
            }
        }

        return $matrix[$len1][$len2];
    }

    /**
     * Merge data from two contacts, preferring primary contact's data
     *
     * @param Contact $primary Primary contact
     * @param Contact $duplicate Duplicate contact
     * @return array Merged data array
     */
    private function mergeData(Contact $primary, Contact $duplicate): array
    {
        $merged = [];

        // Phone data - prefer non-null value from primary
        $merged['formatted_phone_number'] = $this->bestValue(
            $primary->formatted_phone_number,
            $duplicate->formatted_phone_number
        );

        // Email data - prefer verified email
        if ($primary->email_verified || !$duplicate->email_verified) {
            $merged['email'] = $primary->email ?? $duplicate->email;
            $merged['email_verified'] = $primary->email_verified || $duplicate->email_verified;
            $merged['email_score'] = max(
                $primary->email_score ?? 0,
                $duplicate->email_score ?? 0
            );
        } else {
            $merged['email'] = $duplicate->email;
            $merged['email_verified'] = $duplicate->email_verified;
            $merged['email_score'] = $duplicate->email_score;
        }

        // Name data
        $merged['full_name'] = $this->bestValue($primary->full_name, $duplicate->full_name);
        $merged['first_name'] = $this->bestValue($primary->first_name, $duplicate->first_name);
        $merged['last_name'] = $this->bestValue($primary->last_name, $duplicate->last_name);

        // Business data - prefer enriched data
        $primaryEnriched = !empty($primary->business_enriched_at);
        $duplicateEnriched = !empty($duplicate->business_enriched_at);

        if ($primaryEnriched || !$duplicateEnriched) {
            $merged['business_name'] = $this->bestValue($primary->business_name, $duplicate->business_name);
            $merged['business_employee_count'] = $this->bestValue(
                $primary->business_employee_count,
                $duplicate->business_employee_count
            );
            $merged['business_annual_revenue'] = $this->bestValue(
                $primary->business_annual_revenue,
                $duplicate->business_annual_revenue
            );
            $merged['business_website'] = $this->bestValue($primary->business_website, $duplicate->business_website);
        } else {
            $merged['business_name'] = $duplicate->business_name ?? $primary->business_name;
            $merged['business_employee_count'] = $duplicate->business_employee_count ?? $primary->business_employee_count;
            $merged['business_annual_revenue'] = $duplicate->business_annual_revenue ?? $primary->business_annual_revenue;
            $merged['business_website'] = $duplicate->business_website ?? $primary->business_website;
        }

        // Collect additional emails (merge unique emails)
        $allEmails = array_merge(
            [$primary->email],
            [$duplicate->email],
            $primary->additional_emails ?? [],
            $duplicate->additional_emails ?? []
        );
        $allEmails = array_filter($allEmails); // Remove nulls
        $allEmails = array_unique($allEmails);
        $merged['additional_emails'] = array_values(
            array_diff($allEmails, [$merged['email']])
        );

        return $merged;
    }

    /**
     * Return the best value between primary and duplicate
     *
     * @param mixed $primaryValue Primary contact's value
     * @param mixed $duplicateValue Duplicate contact's value
     * @return mixed Best value
     */
    private function bestValue($primaryValue, $duplicateValue)
    {
        return !empty($primaryValue) ? $primaryValue : $duplicateValue;
    }
}
