<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\CrmSync\SalesforceService;
use App\Services\CrmSync\HubspotService;
use App\Services\CrmSync\PipedriveService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Exception;

class CrmSyncJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $contactId;
    public $crmType;

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
    public $timeout = 120;

    /**
     * Create a new job instance.
     *
     * @param int $contactId
     * @param string|null $crmType
     */
    public function __construct(int $contactId, $crmType = null)
    {
        $this->contactId = $contactId;
        $this->crmType = $crmType;
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

            // Guard: skip if no credentials or CRM sync disabled for contact
            if (!$credentials || !$contact->crm_sync_enabled) {
                return [];
            }

            $results = [];

            // Sync to Salesforce
            if ((is_null($this->crmType) || $this->crmType === 'salesforce') && $credentials->enable_salesforce_sync) {
                $service = new SalesforceService($contact);
                $results['salesforce'] = $service->syncToSalesforce();
            }

            // Sync to HubSpot
            if ((is_null($this->crmType) || $this->crmType === 'hubspot') && $credentials->enable_hubspot_sync) {
                $service = new HubspotService($contact);
                $results['hubspot'] = $service->syncToHubspot();
            }

            // Sync to Pipedrive
            if ((is_null($this->crmType) || $this->crmType === 'pipedrive') && $credentials->enable_pipedrive_sync) {
                $service = new PipedriveService($contact);
                $results['pipedrive'] = $service->syncToPipedrive();
            }

            Log::info("CRM sync completed for contact {$this->contactId}: " . json_encode($results));
            return $results;

        } catch (Exception $e) {
            Log::error("CRM sync job failed for contact {$this->contactId}: {$e->getMessage()}");
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
        Log::error("[CrmSyncJob] Failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
