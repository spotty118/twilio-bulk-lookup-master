<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\EmailEnrichmentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Exception;

class EmailEnrichmentJob implements ShouldQueue
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
    public $timeout = 60;

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

            // Skip if already enriched
            if ($contact->email_enriched) {
                Log::info("Skipping contact {$contact->id}: email already enriched");
                return;
            }

            // Skip if email enrichment disabled
            $credentials = TwilioCredential::current();
            if (!$credentials || !$credentials->enable_email_enrichment) {
                Log::info("Email enrichment disabled in settings");
                return;
            }

            // Perform enrichment
            Log::info("Enriching email data for contact {$contact->id}");

            $service = new EmailEnrichmentService();
            $success = $service->enrich($contact);

            if ($success) {
                Log::info("Successfully enriched contact {$contact->id} with email data");

                // Queue duplicate detection after email enrichment
                if ($credentials->enable_duplicate_detection) {
                    DuplicateDetectionJob::dispatch($this->contactId);
                }
            } else {
                Log::info("No email data found for contact {$contact->id}");
            }

        } catch (Exception $e) {
            Log::error("Unexpected error enriching email for contact {$this->contactId}: " . get_class($e) . " - {$e->getMessage()}");
            throw $e;
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
        Log::warning("Email enrichment failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
