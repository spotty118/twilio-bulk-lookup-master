<?php

namespace App\Jobs;

use App\Models\Contact;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\QueryException;
use Exception;

/**
 * RecalculateContactMetricsJob
 *
 * Background job to recalculate fingerprints and quality scores for contacts
 * after bulk imports that skipped callbacks.
 *
 * This job processes contacts in batches to prevent memory issues and
 * provides progress tracking for long-running operations.
 *
 * Usage:
 *   // After bulk import with callbacks skipped:
 *   RecalculateContactMetricsJob::dispatch($contactIds);
 *
 *   // Process all contacts (expensive - use only for maintenance):
 *   RecalculateContactMetricsJob::dispatch(Contact::pluck('id')->toArray());
 */
class RecalculateContactMetricsJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $contactIds;
    public $batchIndex;

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
    public $timeout = 600;

    /**
     * Process in batches to prevent memory issues
     */
    const BATCH_SIZE = 100;

    /**
     * Create a new job instance.
     *
     * @param array $contactIds
     * @param int $batchIndex
     */
    public function __construct(array $contactIds, int $batchIndex = 0)
    {
        $this->contactIds = $contactIds;
        $this->batchIndex = $batchIndex;
        $this->onQueue('low_priority');
    }

    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        if (empty($this->contactIds)) {
            return;
        }

        Log::info("RecalculateContactMetricsJob: Processing batch " . ($this->batchIndex + 1) . ", " .
            count($this->contactIds) . " contacts total");

        // Process this batch
        $currentBatch = array_slice($this->contactIds, 0, self::BATCH_SIZE);
        $remaining = array_slice($this->contactIds, self::BATCH_SIZE);

        $this->processBatch($currentBatch);

        // Enqueue next batch if there are more contacts
        if (count($remaining) > 0) {
            self::dispatch($remaining, $this->batchIndex + 1);
            Log::info("RecalculateContactMetricsJob: Enqueued batch " . ($this->batchIndex + 2) .
                " with " . count($remaining) . " remaining contacts");
        } else {
            Log::info("RecalculateContactMetricsJob: All batches completed " .
                "(" . ($this->batchIndex + 1) . " total batches)");
            // Ensure dashboard stats reflect recalculated metrics
            DashboardBroadcastJob::dispatch();
        }
    }

    /**
     * Process a batch of contacts
     *
     * @param array $contactIds
     * @return void
     */
    protected function processBatch(array $contactIds)
    {
        $startTime = now();
        $updatedCount = 0;

        foreach (Contact::whereIn('id', $contactIds)->cursor() as $contact) {
            try {
                // Update fingerprints for duplicate detection
                $contact->updateFingerprints();

                // Recalculate quality score
                $contact->calculateQualityScore();

                $updatedCount++;
            } catch (Exception $e) {
                // Log error but continue processing other contacts
                Log::error("RecalculateContactMetricsJob: Failed to update contact {$contact->id}: {$e->getMessage()}");
            }
        }

        $duration = now()->diffInSeconds($startTime);
        $avgTime = $updatedCount > 0 ? $duration / $updatedCount : 0;

        Log::info("RecalculateContactMetricsJob: Batch complete - " .
            "{$updatedCount}/" . count($contactIds) . " contacts updated in {$duration}s " .
            "(avg: " . round($avgTime, 3) . "s per contact)");
    }

    /**
     * Handle a job failure.
     *
     * @param  \Throwable  $exception
     * @return void
     */
    public function failed(\Throwable $exception)
    {
        Log::error("RecalculateContactMetricsJob failed for batch {$this->batchIndex}: {$exception->getMessage()}");
    }
}
