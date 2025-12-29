<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\GeocodingService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Exception;

class GeocodingJob implements ShouldQueue
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
     * @return array
     */
    public function handle()
    {
        try {
            $contact = Contact::findOrFail($this->contactId);
            $credentials = TwilioCredential::current();

            if (!$credentials || !$credentials->enable_geocoding) {
                return ['success' => false, 'error' => 'Geocoding disabled'];
            }

            $service = new GeocodingService($contact);
            $result = $service->geocode();

            if ($result['success']) {
                Log::info("Successfully geocoded contact {$this->contactId}: {$result['latitude']}, {$result['longitude']}");
            } else {
                Log::warning("Geocoding failed for contact {$this->contactId}: {$result['error']}");
            }

            return $result;

        } catch (Exception $e) {
            Log::error("Geocoding job failed for contact {$this->contactId}: {$e->getMessage()}");
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
        Log::error("[GeocodingJob] Failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
