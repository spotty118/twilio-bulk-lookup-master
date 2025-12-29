<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\AddressEnrichmentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Exception;

class AddressEnrichmentJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $contactId;

    /**
     * The number of times the job may be attempted.
     *
     * @var int
     */
    public $tries = 3;

    /**
     * The number of seconds to wait before retrying.
     *
     * @var int
     */
    public $backoff = [10, 30, 90];

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

            // Skip if address enrichment disabled
            $credentials = TwilioCredential::current();
            if (!$credentials || !$credentials->enable_address_enrichment) {
                Log::info("[AddressEnrichmentJob] Address enrichment disabled in settings");
                return;
            }

            Log::info("[AddressEnrichmentJob] Starting address enrichment for contact {$contact->id}");

            $service = new AddressEnrichmentService($contact);
            $success = $service->enrich();

            if ($success) {
                Log::info("[AddressEnrichmentJob] Successfully enriched address for contact {$contact->id}");
            } else {
                Log::warning("[AddressEnrichmentJob] Address enrichment returned false for contact {$contact->id}");
            }

        } catch (Exception $e) {
            Log::error("[AddressEnrichmentJob] Error enriching contact {$this->contactId}: {$e->getMessage()}");
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
        Log::error("[AddressEnrichmentJob] Failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
