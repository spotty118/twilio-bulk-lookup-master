<?php

namespace App\Jobs;

use App\Models\Contact;
use App\Models\TwilioCredential;
use App\Services\CircuitBreakerService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Twilio\Rest\Client as TwilioClient;
use Twilio\Exceptions\RestException as TwilioRestException;
use Exception;

class LookupRequestJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $contactId;

    /**
     * The number of times the job may be attempted.
     *
     * @var int
     */
    public $tries = 5;

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
     */
    public function __construct(int $contactId)
    {
        $this->contactId = $contactId;
        $this->onQueue('default');
    }

    /**
     * Calculate the number of seconds to wait before retrying the job.
     *
     * @return int
     */
    public function backoff()
    {
        $executions = $this->attempts();
        // Polynomial backoff: (executions^4) + 15 + rand(10)
        return pow($executions, 4) + 15 + rand(0, 10);
    }

    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        $contact = Contact::findOrFail($this->contactId);

        // Idempotency check: skip if already completed
        if ($contact->lookup_completed) {
            Log::info("Skipping contact {$contact->id}: already completed");
            return;
        }

        // Atomic status transition with pessimistic locking
        $updated = false;
        $contact = Contact::lockForUpdate()->find($this->contactId);

        if (in_array($contact->status, ['pending', 'failed'])) {
            $contact->markProcessing();
            $updated = true;
        }

        if (!$updated) {
            Log::info("Skipping contact {$contact->id}: already being processed (status: {$contact->status})");
            return;
        }

        try {
            // Get Twilio credentials
            $credentials = TwilioCredential::current();
            $appCreds = config('twilio');

            $accountSid = $appCreds['account_sid'] ?? null;
            $authToken = $appCreds['auth_token'] ?? null;

            if (empty($accountSid) || empty($authToken)) {
                $contact->markFailed('No Twilio credentials configured');
                return;
            }

            // Initialize Twilio client
            $client = new TwilioClient($accountSid, $authToken);

            // Build fields parameter from enabled packages
            $fields = $credentials ? $credentials->data_packages : null;

            // Perform Twilio Lookup API v2 with circuit breaker
            $lookupResult = CircuitBreakerService::call('twilio', function () use ($client, $contact, $fields) {
                if (!empty($fields)) {
                    return $client->lookups
                        ->v2
                        ->phoneNumbers($contact->raw_phone_number)
                        ->fetch(['fields' => $fields]);
                } else {
                    return $client->lookups
                        ->v2
                        ->phoneNumbers($contact->raw_phone_number)
                        ->fetch();
                }
            });

            // Check if circuit breaker returned a fallback error
            if (is_array($lookupResult) && isset($lookupResult['circuit_open'])) {
                $contact->markFailed('Twilio API temporarily unavailable (circuit open)');
                return;
            }

            // Extract and store lookup data
            $this->processLookupResult($contact, $lookupResult);

            // Mark as completed
            $contact->markCompleted();

            Log::info("Successfully processed contact {$contact->id}: {$contact->formatted_phone_number}");

            // Perform add-ons if enabled
            if ($credentials && $credentials->enable_real_phone_validation) {
                $this->performRealPhoneValidation($client, $contact, $credentials);
            }

            if ($credentials && $credentials->enable_icehook_scout) {
                $this->performIcehookScout($client, $contact);
            }

            // Enqueue enrichment coordinator
            EnrichmentCoordinatorJob::dispatch($contact->id);

        } catch (TwilioRestException $e) {
            $this->handleTwilioError($contact, $e);
        } catch (Exception $e) {
            Log::error("Unexpected error for contact {$contact->id}: " . get_class($e) . " - {$e->getMessage()}");
            Log::error($e->getTraceAsString());
            $contact->markFailed("Unexpected error: {$e->getMessage()}");
            throw $e;
        } finally {
            // Notify on batch completion
            $this->notifyBatchCompletionIfNeeded();
        }
    }

    /**
     * Process the Twilio lookup result and update contact
     */
    protected function processLookupResult($contact, $lookupResult)
    {
        // Extract basic validation data
        $phoneNumber = $lookupResult->phoneNumber ?? null;
        $valid = $lookupResult->valid ?? false;
        $validationErrors = $lookupResult->validationErrors ?? [];
        $countryCode = $lookupResult->countryCode ?? null;
        $callingCountryCode = $lookupResult->callingCountryCode ?? null;

        // Extract Line Type Intelligence data
        $lineTypeData = $lookupResult->lineTypeIntelligence ?? [];
        $lineType = $lineTypeData['type'] ?? null;
        $lineTypeConfidence = $lineTypeData['confidence'] ?? null;
        $carrierName = $lineTypeData['carrier_name'] ?? null;
        $mobileNetworkCode = $lineTypeData['mobile_network_code'] ?? null;
        $mobileCountryCode = $lineTypeData['mobile_country_code'] ?? null;

        // Extract Caller Name (CNAM) data
        $callerNameData = $lookupResult->callerName ?? [];
        $callerName = $callerNameData['caller_name'] ?? null;
        $callerType = $callerNameData['caller_type'] ?? null;

        // Extract SMS Pumping Risk data
        $smsRiskData = $lookupResult->smsPumpingRisk ?? [];
        $smsRiskScore = isset($smsRiskData['sms_pumping_risk_score'])
            ? (int)$smsRiskData['sms_pumping_risk_score']
            : null;

        // Determine risk level
        $smsRiskLevel = null;
        if ($smsRiskScore !== null) {
            if ($smsRiskScore <= 25) {
                $smsRiskLevel = 'low';
            } elseif ($smsRiskScore <= 74) {
                $smsRiskLevel = 'medium';
            } else {
                $smsRiskLevel = 'high';
            }
        }

        $smsCarrierRisk = $smsRiskData['carrier_risk_category'] ?? null;
        $smsNumberBlocked = $smsRiskData['number_blocked'] ?? null;

        // Extract SIM Swap data
        $simSwapData = $lookupResult->simSwap ?? [];
        $simSwapLastDate = $simSwapData['last_sim_swap']['timestamp'] ?? null;
        $simSwapSwappedPeriod = $simSwapData['last_sim_swap']['swapped_period'] ?? null;
        $simSwapSwappedInPeriod = $simSwapData['last_sim_swap']['swapped_in_period'] ?? null;

        // Extract Reassigned Number data
        $reassignedData = $lookupResult->reassignedNumber ?? [];
        $reassignedIsReassigned = $reassignedData['is_reassigned'] ?? null;
        $reassignedLastVerified = $reassignedData['last_verified_date'] ?? null;

        // Update contact
        $contact->update([
            'formatted_phone_number' => $phoneNumber,
            'phone_valid' => $valid,
            'validation_errors' => $validationErrors,
            'country_code' => $countryCode,
            'calling_country_code' => $callingCountryCode,
            'line_type' => $lineType,
            'line_type_confidence' => $lineTypeConfidence,
            'carrier_name' => $carrierName,
            'mobile_network_code' => $mobileNetworkCode,
            'mobile_country_code' => $mobileCountryCode,
            'device_type' => $lineType,
            'caller_name' => $callerName,
            'caller_type' => $callerType,
            'sms_pumping_risk_score' => $smsRiskScore,
            'sms_pumping_risk_level' => $smsRiskLevel,
            'sms_pumping_carrier_risk_category' => $smsCarrierRisk,
            'sms_pumping_number_blocked' => $smsNumberBlocked,
            'sim_swap_last_sim_swap_date' => $simSwapLastDate,
            'sim_swap_swapped_period' => $simSwapSwappedPeriod,
            'sim_swap_swapped_in_period' => $simSwapSwappedInPeriod,
            'reassigned_number_is_reassigned' => $reassignedIsReassigned,
            'reassigned_number_last_verified_date' => $reassignedLastVerified,
            'error_code' => null,
        ]);
    }

    /**
     * Perform Real Phone Validation add-on
     */
    protected function performRealPhoneValidation($client, $contact, $credentials)
    {
        try {
            $rpvUniqueName = $credentials->rpv_unique_name ?: 'real_phone_validation_rpv_turbo';
            Log::info("Starting RPV for contact {$contact->id} using add-on: {$rpvUniqueName}");

            $rpvResult = CircuitBreakerService::call('twilio', function () use ($client, $contact, $rpvUniqueName) {
                return $client->lookups
                    ->v1
                    ->phoneNumbers($contact->raw_phone_number)
                    ->fetch(['addOns' => [$rpvUniqueName]]);
            });

            if (is_array($rpvResult) && isset($rpvResult['circuit_open'])) {
                Log::warning("RPV circuit open for contact {$contact->id}");
                return;
            }

            $addOns = $rpvResult->addOns ?? null;
            if (!$addOns) {
                Log::info("RPV response has no add_ons data for contact {$contact->id}");
                return;
            }

            $rpvData = $addOns['results'][$rpvUniqueName]['result'] ?? null;
            if (!$rpvData) {
                Log::warning("RPV response missing data for contact {$contact->id}");
                return;
            }

            $contact->update([
                'rpv_status' => $rpvData['status'] ?? null,
                'rpv_error_text' => $rpvData['error_text'] ?? null,
                'rpv_iscell' => $rpvData['iscell'] ?? null,
                'rpv_cnam' => $rpvData['cnam'] ?? null,
                'rpv_carrier' => $rpvData['carrier'] ?? null,
            ]);

            Log::info("RPV completed for contact {$contact->id}: status={$rpvData['status']}");
        } catch (TwilioRestException $e) {
            Log::warning("RPV error for contact {$contact->id}: {$e->getMessage()}");
        } catch (Exception $e) {
            Log::warning("RPV unexpected error for contact {$contact->id}: {$e->getMessage()}");
        }
    }

    /**
     * Perform IceHook Scout add-on
     */
    protected function performIcehookScout($client, $contact)
    {
        try {
            Log::info("Starting IceHook Scout for contact {$contact->id}");

            $scoutResult = CircuitBreakerService::call('twilio', function () use ($client, $contact) {
                return $client->lookups
                    ->v1
                    ->phoneNumbers($contact->raw_phone_number)
                    ->fetch(['addOns' => ['icehook_scout']]);
            });

            if (is_array($scoutResult) && isset($scoutResult['circuit_open'])) {
                Log::warning("Scout circuit open for contact {$contact->id}");
                return;
            }

            $addOns = $scoutResult->addOns ?? null;
            if (!$addOns) {
                Log::info("Scout response has no add_ons data for contact {$contact->id}");
                return;
            }

            $scoutData = $addOns['results']['icehook_scout']['result'] ?? null;
            if (!$scoutData) {
                Log::warning("Scout response missing data for contact {$contact->id}");
                return;
            }

            // Parse ported as boolean
            $portedValue = $scoutData['ported'] ?? null;
            $portedBool = null;
            if ($portedValue === 'true' || $portedValue === true) {
                $portedBool = true;
            } elseif ($portedValue === 'false' || $portedValue === false) {
                $portedBool = false;
            }

            $contact->update([
                'scout_ported' => $portedBool,
                'scout_location_routing_number' => $scoutData['location_routing_number'] ?? null,
                'scout_operating_company_name' => $scoutData['operating_company_name'] ?? null,
                'scout_operating_company_type' => $scoutData['operating_company_type'] ?? null,
            ]);

            Log::info("Scout completed for contact {$contact->id}: ported={$portedBool}");
        } catch (TwilioRestException $e) {
            Log::warning("Scout error for contact {$contact->id}: {$e->getMessage()}");
        } catch (Exception $e) {
            Log::warning("Scout unexpected error for contact {$contact->id}: {$e->getMessage()}");
        }
    }

    /**
     * Handle Twilio API errors
     */
    protected function handleTwilioError($contact, TwilioRestException $error)
    {
        $errorCode = $error->getCode();
        $errorMessage = $error->getMessage();

        Log::warning("Twilio error for contact {$contact->id}: [{$errorCode}] {$errorMessage}");

        switch ($errorCode) {
            case 20404: // Invalid number
                $contact->markFailed("Invalid phone number: {$errorMessage}");
                break;

            case 20003:
            case 20005: // Authentication errors
                $contact->markFailed("Authentication error: {$errorMessage}");
                break;

            case 20429: // Rate limit
                $contact->markFailed("Rate limit exceeded: {$errorMessage}");
                Log::warning('Rate limit exceeded, will retry');
                $this->release($this->backoff()); // Re-queue with backoff
                break;

            case 21211:
            case 21212:
            case 21213:
            case 21214:
            case 21215:
            case 21216:
            case 21217:
            case 21218:
            case 21219: // Invalid number formats
                $contact->markFailed("Invalid number format: {$errorMessage}");
                break;

            default:
                // Unknown error - allow retry
                $contact->markFailed("Twilio error {$errorCode}: {$errorMessage}");
                Log::warning("Unknown Twilio error {$errorCode}, will retry");
                throw $error;
        }
    }

    /**
     * Notify Slack on batch completion
     */
    protected function notifyBatchCompletionIfNeeded()
    {
        $pendingCount = Contact::where('status', 'pending')->count();
        $processingCount = Contact::where('status', 'processing')->count();

        if ($pendingCount === 0 && $processingCount === 0) {
            Cache::remember('bulk_lookup_completion_notified', 300, function () {
                try {
                    $completedCount = Contact::where('status', 'completed')->count();
                    $failedCount = Contact::where('status', 'failed')->count();

                    if (config('services.slack.webhook_url')) {
                        // Send Slack notification
                        Log::info("Bulk Lookup Complete! Total Processed: {$completedCount} | Failed: {$failedCount}");
                    }
                } catch (Exception $e) {
                    Log::warning("Slack notification failed: {$e->getMessage()}");
                }
                return now();
            });
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
        $contact = Contact::find($this->contactId);
        if ($contact) {
            $contact->markFailed("Job failed after retries: {$exception->getMessage()}");
        }

        Log::error("LookupRequestJob failed for contact {$this->contactId}: {$exception->getMessage()}");
    }
}
