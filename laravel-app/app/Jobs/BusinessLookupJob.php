<?php

namespace App\Jobs;

use App\Models\ZipcodeLookup;
use App\Services\BusinessLookupService;
use App\Exceptions\ProviderError;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Exception;

class BusinessLookupJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $zipcodeLookupId;

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
    public $timeout = 300;

    /**
     * Create a new job instance.
     *
     * @param int $zipcodeLookupId
     */
    public function __construct(int $zipcodeLookupId)
    {
        $this->zipcodeLookupId = $zipcodeLookupId;
        $this->onQueue('default');
    }

    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        $zipcodeLookup = null;

        try {
            $zipcodeLookup = ZipcodeLookup::findOrFail($this->zipcodeLookupId);

            // Mark as processing
            $zipcodeLookup->markProcessing();

            Log::info("[BusinessLookupJob] Starting lookup for zipcode: {$zipcodeLookup->zipcode}");

            // Perform the lookup
            $service = new BusinessLookupService($zipcodeLookup->zipcode, $zipcodeLookup);
            $stats = $service->lookupBusinesses();

            // Mark as completed with stats
            $zipcodeLookup->markCompleted($stats);

            Log::info("[BusinessLookupJob] Completed lookup for zipcode: {$zipcodeLookup->zipcode} - " .
                "Found: {$stats['found']}, Imported: {$stats['imported']}, " .
                "Updated: {$stats['updated']}, Skipped: {$stats['skipped']}");

        } catch (ProviderError $e) {
            if ($zipcodeLookup) {
                Log::error("[BusinessLookupJob] Provider error for zipcode {$zipcodeLookup->zipcode}: {$e->getMessage()}");
                $zipcodeLookup->markFailed($e);
            } else {
                Log::error("[BusinessLookupJob] Provider error for missing zipcode_lookup_id {$this->zipcodeLookupId}: {$e->getMessage()}");
            }
            // Don't retry on provider errors
        } catch (Exception $e) {
            if ($zipcodeLookup) {
                Log::error("[BusinessLookupJob] Error processing zipcode {$zipcodeLookup->zipcode}: {$e->getMessage()}");
                Log::error($e->getTraceAsString());
                $zipcodeLookup->markFailed($e);
            } else {
                Log::error("[BusinessLookupJob] Error processing zipcode_lookup_id {$this->zipcodeLookupId}: {$e->getMessage()}");
                Log::error($e->getTraceAsString());
            }
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
        Log::error("[BusinessLookupJob] Failed for zipcode_lookup_id {$this->zipcodeLookupId}: {$exception->getMessage()}");
    }
}
