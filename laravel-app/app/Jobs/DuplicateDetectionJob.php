<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\DuplicateDetectionService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Exception;

class DuplicateDetectionJob implements ShouldQueue
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

            // Skip if already marked as duplicate
            if ($contact->is_duplicate) {
                return;
            }

            $credentials = TwilioCredential::current();
            if ($credentials && !$credentials->enable_duplicate_detection) {
                return;
            }

            Log::info("Checking for duplicates: contact {$contact->id}");

            // Find potential duplicates
            $service = new DuplicateDetectionService();
            $duplicates = $service->findDuplicates($contact);

            if (count($duplicates) > 0) {
                Log::info("Found " . count($duplicates) . " potential duplicates for contact {$contact->id}");

                // Store duplicate check timestamp
                $contact->update(['duplicate_checked_at' => now()]);

                // Auto-merge if enabled and high confidence
                if ($credentials && $credentials->auto_merge_duplicates) {
                    foreach ($duplicates as $dup) {
                        if ($dup['confidence'] >= 95) {
                            Log::info("Auto-merging contact {$dup['contact']->id} into {$contact->id} (confidence: {$dup['confidence']}%)");
                            $service->merge($contact, $dup['contact']);
                        }
                    }
                }
            } else {
                Log::info("No duplicates found for contact {$contact->id}");
                $contact->update(['duplicate_checked_at' => now()]);
            }

        } catch (Exception $e) {
            Log::error("Duplicate detection error for contact {$this->contactId}: {$e->getMessage()}");
            throw $e; // Re-raise to trigger retry logic
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
        Log::error("[DuplicateDetectionJob] Failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
