<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\TrustHubService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Twilio\Exceptions\TwilioException;
use Twilio\Exceptions\RestException as TwilioRestException;
use Exception;

class TrustHubEnrichmentJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $contactId;

    /**
     * The number of times the job may be attempted.
     *
     * @var int
     */
    public $tries = 2;

    /**
     * The number of seconds to wait before retrying.
     *
     * @var int
     */
    public $backoff = [10, 30];

    /**
     * The maximum number of seconds the job can run before timing out.
     *
     * @var int
     */
    public $timeout = 90;

    /**
     * Create a new job instance.
     *
     * @param int $contactId
     */
    public function __construct(int $contactId)
    {
        $this->contactId = $contactId;
        $this->onQueue('default');
    }

    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        try {
            $contact = Contact::findOrFail($this->contactId);

            // Skip if already enriched and verified
            if ($contact->trust_hub_enriched && $contact->trust_hub_verified && !$this->needsReverification($contact)) {
                Log::info("Skipping contact {$contact->id}: already Trust Hub verified");
                return;
            }

            // Skip if not a business
            if (!$contact->is_business) {
                Log::info("Skipping contact {$contact->id}: not identified as business");
                return;
            }

            // Skip if business enrichment not completed yet
            if (!$contact->business_enriched) {
                Log::info("Skipping contact {$contact->id}: business enrichment not completed");
                return;
            }

            // Check if Trust Hub enrichment is enabled
            $credentials = TwilioCredential::current();
            if (!$credentials || !$credentials->enable_trust_hub) {
                Log::info("Trust Hub enrichment disabled in settings");
                return;
            }

            // Perform enrichment
            Log::info("Enriching Trust Hub data for contact {$contact->id}");

            $service = new TrustHubService();
            $success = $service->enrich($contact);

            if ($success) {
                Log::info("Successfully enriched contact {$contact->id} with Trust Hub data");
                $this->logVerificationStatus($contact);
            } else {
                Log::info("No Trust Hub data found for contact {$contact->id}");
            }

        } catch (TwilioRestException $e) {
            Log::error("Twilio REST error enriching contact {$this->contactId}: {$e->getMessage()}");
            $contact = Contact::find($this->contactId);
            if ($contact) {
                $contact->update([
                    'trust_hub_error' => $e->getMessage(),
                    'trust_hub_enriched' => true,
                    'trust_hub_enriched_at' => now(),
                ]);
            }
            // Don't re-throw - discard on Twilio errors
        } catch (Exception $e) {
            Log::error("Unexpected error enriching contact {$this->contactId}: " . get_class($e) . " - {$e->getMessage()}");
            Log::error($e->getTraceAsString());
            throw $e;
        }
    }

    /**
     * Check if contact needs re-verification
     */
    protected function needsReverification($contact): bool
    {
        // Re-verify if status is pending/rejected or if enriched more than 90 days ago
        if (in_array($contact->trust_hub_status, ['pending-review', 'twilio-rejected', 'draft'])) {
            return true;
        }

        if (!$contact->trust_hub_enriched_at) {
            return false;
        }

        return $contact->trust_hub_enriched_at->lt(now()->subDays(90));
    }

    /**
     * Log verification status
     */
    protected function logVerificationStatus($contact)
    {
        $status = $contact->trust_hub_status;
        $score = $contact->trust_hub_verification_score;

        switch ($status) {
            case 'twilio-approved':
            case 'compliant':
                Log::info("Contact {$contact->id} is Trust Hub verified (score: {$score})");
                break;
            case 'pending-review':
            case 'in-review':
                Log::info("Contact {$contact->id} Trust Hub verification pending (score: {$score})");
                break;
            case 'twilio-rejected':
            case 'rejected':
                Log::warning("Contact {$contact->id} Trust Hub verification rejected (score: {$score})");
                break;
            case 'draft':
                Log::info("Contact {$contact->id} Trust Hub profile created as draft (score: {$score})");
                break;
            default:
                Log::info("Contact {$contact->id} Trust Hub status: {$status} (score: {$score})");
        }
    }

    /**
     * Handle a job failure.
     *
     * @param  \Throwable  $exception
     * @return void
     */
    public function failed(\Throwable $exception)
    {
        Log::warning("Trust Hub enrichment failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
