<?php

namespace App\Http\Controllers;

use App\Models\Webhook;
use App\Models\AdminUser;
use App\Models\TwilioCredential;
use App\Jobs\WebhookProcessorJob;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Twilio\Security\RequestValidator;

class WebhooksController extends Controller
{
    /**
     * Twilio SMS Status Webhook
     */
    public function twilioSmsStatus(Request $request)
    {
        try {
            // Verify Twilio signature
            if (!$this->verifyTwilioSignature($request)) {
                Log::warning('Invalid Twilio signature for webhook: ' . $request->path());
                return response('Forbidden', 403);
            }

            // Atomic upsert to prevent race conditions
            $data = [
                'source' => 'twilio_sms',
                'external_id' => $request->input('MessageSid'),
                'event_type' => 'sms_status',
                'payload' => json_encode($this->getWebhookParams($request)),
                'headers' => json_encode($this->extractHeaders($request)),
                'status' => 'pending',
                'received_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ];

            // Use INSERT ... ON DUPLICATE KEY UPDATE
            $webhook = Webhook::updateOrCreate(
                [
                    'source' => 'twilio_sms',
                    'external_id' => $request->input('MessageSid'),
                ],
                $data
            );

            // Check if this was a new insert (wasRecentlyCreated)
            if ($webhook->wasRecentlyCreated) {
                WebhookProcessorJob::dispatch($webhook->id);
            } else {
                Log::info("Duplicate SMS webhook ignored: {$request->input('MessageSid')}");
            }

            return response('', 200);
        } catch (\Exception $e) {
            Log::error("SMS webhook error: " . get_class($e) . " - " . $e->getMessage());
            return response('', 200);
        }
    }

    /**
     * Twilio Voice Status Webhook
     */
    public function twilioVoiceStatus(Request $request)
    {
        try {
            // Verify Twilio signature
            if (!$this->verifyTwilioSignature($request)) {
                Log::warning('Invalid Twilio signature for webhook: ' . $request->path());
                return response('Forbidden', 403);
            }

            // Atomic upsert to prevent race conditions
            $data = [
                'source' => 'twilio_voice',
                'external_id' => $request->input('CallSid'),
                'event_type' => 'voice_status',
                'payload' => json_encode($this->getWebhookParams($request)),
                'headers' => json_encode($this->extractHeaders($request)),
                'status' => 'pending',
                'received_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ];

            $webhook = Webhook::updateOrCreate(
                [
                    'source' => 'twilio_voice',
                    'external_id' => $request->input('CallSid'),
                ],
                $data
            );

            if ($webhook->wasRecentlyCreated) {
                WebhookProcessorJob::dispatch($webhook->id);
            } else {
                Log::info("Duplicate Voice webhook ignored: {$request->input('CallSid')}");
            }

            return response('', 200);
        } catch (\Exception $e) {
            Log::error("Voice webhook error: " . get_class($e) . " - " . $e->getMessage());
            return response('', 200);
        }
    }

    /**
     * Twilio Trust Hub Status Webhook
     */
    public function twilioTrustHub(Request $request)
    {
        try {
            // Verify Twilio signature
            if (!$this->verifyTwilioSignature($request)) {
                Log::warning('Invalid Twilio signature for webhook: ' . $request->path());
                return response('Forbidden', 403);
            }

            // Atomic upsert to prevent race conditions
            $data = [
                'source' => 'twilio_trust_hub',
                'external_id' => $request->input('CustomerProfileSid'),
                'event_type' => $request->input('StatusCallbackEvent', 'status_update'),
                'payload' => json_encode($this->getWebhookParams($request)),
                'headers' => json_encode($this->extractHeaders($request)),
                'status' => 'pending',
                'received_at' => now(),
                'created_at' => now(),
                'updated_at' => now(),
            ];

            $webhook = Webhook::updateOrCreate(
                [
                    'source' => 'twilio_trust_hub',
                    'external_id' => $request->input('CustomerProfileSid'),
                ],
                $data
            );

            if ($webhook->wasRecentlyCreated) {
                WebhookProcessorJob::dispatch($webhook->id);
            } else {
                Log::info("Duplicate Trust Hub webhook ignored: {$request->input('CustomerProfileSid')}");
            }

            return response('', 200);
        } catch (\Exception $e) {
            Log::error("Trust Hub webhook error: " . get_class($e) . " - " . $e->getMessage());
            return response('', 200);
        }
    }

    /**
     * Generic webhook endpoint (requires API key authentication)
     * Usage: POST /webhooks/generic with Authorization: Bearer <api_token>
     */
    public function generic(Request $request)
    {
        try {
            // Verify API key authentication
            if (!$this->authenticateWebhookApiKey($request)) {
                return response()->json([
                    'success' => false,
                    'error' => 'Unauthorized: Invalid or missing API key'
                ], 401);
            }

            $webhook = Webhook::create([
                'source' => $request->input('source', 'unknown'),
                'event_type' => $request->input('event_type', 'unknown'),
                'external_id' => $request->input('external_id'),
                'payload' => $this->getWebhookParams($request),
                'headers' => $this->extractHeaders($request),
                'status' => 'pending',
                'received_at' => now(),
            ]);

            if ($webhook->exists) {
                WebhookProcessorJob::dispatch($webhook->id);
                return response()->json([
                    'success' => true,
                    'webhook_id' => $webhook->id
                ]);
            }

            return response()->json([
                'success' => false,
                'errors' => $webhook->getErrors()
            ], 422);
        } catch (\Exception $e) {
            Log::error("Generic webhook error: " . get_class($e) . " - " . $e->getMessage());
            return response()->json([
                'success' => false,
                'error' => $e->getMessage()
            ], 500);
        }
    }

    /**
     * Authenticate generic webhook using API key from Authorization header
     * Uses timing-safe comparison to prevent timing attacks
     */
    private function authenticateWebhookApiKey(Request $request): bool
    {
        $authHeader = $request->header('Authorization');
        if (!$authHeader) {
            return false;
        }

        // Extract Bearer token
        $parts = explode(' ', $authHeader);
        $token = end($parts);
        if (!$token) {
            return false;
        }

        // Timing-safe token validation to prevent brute-force via timing analysis
        $adminTokens = AdminUser::whereNotNull('api_token')->pluck('api_token');
        foreach ($adminTokens as $storedToken) {
            if (hash_equals($storedToken, $token)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Verify webhook is from Twilio using signature validation
     */
    private function verifyTwilioSignature(Request $request): bool
    {
        try {
            // Get auth token from TwilioCredential model or AppConfig
            $authToken = TwilioCredential::current()?->auth_token;
            if (!$authToken) {
                return false;
            }

            $validator = new RequestValidator($authToken);
            $signature = $request->header('X-Twilio-Signature');
            $url = $request->fullUrl();

            // Combine POST parameters and query parameters for signature validation
            $paramsForValidation = array_merge(
                $request->post(),
                $request->query()
            );

            return $validator->validate($signature, $url, $paramsForValidation);
        } catch (\ArgumentCountError | \TypeError $e) {
            // Handle invalid auth token or malformed signature
            Log::error("Signature verification error: " . get_class($e) . " - " . $e->getMessage());
            return false;
        } catch (\Exception $e) {
            // Unexpected errors during validation
            Log::error("Unexpected signature verification error: " . get_class($e) . " - " . $e->getMessage());
            Log::error($e->getTraceAsString());
            return false;
        }
    }

    /**
     * Extract all webhook parameters except controller/action
     */
    private function getWebhookParams(Request $request): array
    {
        $all = $request->all();
        unset($all['controller'], $all['action']);
        return $all;
    }

    /**
     * Extract relevant headers from the request
     */
    private function extractHeaders(Request $request): array
    {
        return [
            'User-Agent' => $request->header('User-Agent'),
            'X-Twilio-Signature' => $request->header('X-Twilio-Signature'),
            'Content-Type' => $request->header('Content-Type'),
        ];
    }
}
