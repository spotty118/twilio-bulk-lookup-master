<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\BusinessEnrichmentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Exception;

class BusinessEnrichmentJob implements ShouldQueue
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
            if ($contact->business_enriched) {
                Log::info("Skipping contact {$contact->id}: already enriched");
                return;
            }

            // Skip if not completed lookup yet
            if (!$contact->lookup_completed) {
                Log::info("Skipping contact {$contact->id}: lookup not completed");
                return;
            }

            // Check if business enrichment is enabled
            $credentials = TwilioCredential::current();
            if (!$credentials || !$credentials->enable_business_enrichment) {
                Log::info("Business enrichment disabled in settings");
                return;
            }

            // Perform enrichment
            Log::info("Enriching business data for contact {$contact->id}");

            $service = new BusinessEnrichmentService();
            $success = $service->enrich($contact);

            if ($success) {
                Log::info("Successfully enriched contact {$contact->id} with business data");
            } else {
                Log::info("No business data found for contact {$contact->id}");
            }

        } catch (Exception $e) {
            Log::error("Unexpected error enriching contact {$this->contactId}: " . get_class($e) . " - {$e->getMessage()}");
            Log::error($e->getTraceAsString());
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
        Log::warning("Business enrichment failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
