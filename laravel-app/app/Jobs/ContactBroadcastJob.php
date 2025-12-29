<?php

namespace App\Jobs;

use App\Models\Contact;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use App\Events\ContactUpdated;
use Exception;

/**
 * Broadcasts individual contact updates for live table refresh
 * This job renders the contact row data and sends it via broadcasting
 */
class ContactBroadcastJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $contactId;

    /**
     * The number of times the job may be attempted.
     *
     * @var int
     */
    public $tries = 1;

    /**
     * The maximum number of seconds the job can run before timing out.
     *
     * @var int
     */
    public $timeout = 10;

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
            $contact = Contact::find($this->contactId);
            if (!$contact) {
                return;
            }

            // Broadcast the updated contact data
            broadcast(new ContactUpdated([
                'action' => 'update',
                'contact_id' => $contact->id,
                'status' => $contact->status,
                'status_class' => $contact->status,
                'device_type' => $contact->device_type,
                'rpv_status' => $contact->rpv_status,
                'rpv_status_class' => $this->rpvStatusClass($contact->rpv_status),
                'carrier_name' => $contact->carrier_name,
                'risk_level' => $contact->sms_pumping_risk_level,
                'risk_class' => $this->riskClass($contact->sms_pumping_risk_level),
                'is_business' => $contact->is_business,
                'business_name' => $contact->business_name,
                'formatted_phone' => $contact->formatted_phone_number,
            ]));

        } catch (Exception $e) {
            Log::warning("Contact broadcast failed for {$this->contactId}: {$e->getMessage()}");
        }
    }

    /**
     * Get RPV status CSS class
     *
     * @param string|null $status
     * @return string|null
     */
    protected function rpvStatusClass($status)
    {
        if (!$status) {
            return null;
        }

        switch (strtolower($status)) {
            case 'connected':
                return 'ok';
            case 'disconnected':
                return 'error';
            default:
                return 'warning';
        }
    }

    /**
     * Get risk level CSS class
     *
     * @param string|null $level
     * @return string|null
     */
    protected function riskClass($level)
    {
        if (!$level) {
            return null;
        }

        switch ($level) {
            case 'high':
                return 'error';
            case 'medium':
                return 'warning';
            case 'low':
                return 'ok';
            default:
                return null;
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
        Log::warning("ContactBroadcastJob failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
