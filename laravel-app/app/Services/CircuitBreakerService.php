<?php

namespace App\Services;

use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Log;
use Exception;

/**
 * CircuitBreakerService - Provides circuit breaker protection for external API calls
 *
 * This service implements the circuit breaker pattern, preventing cascade failures
 * when external APIs are down or slow.
 *
 * Circuit Breaker States:
 * - CLOSED: Normal operation, requests pass through
 * - OPEN: Too many failures, requests fail fast without hitting API
 * - HALF_OPEN: Testing if API recovered, limited requests allowed
 *
 * Usage:
 *   CircuitBreakerService::call('clearbit', function() {
 *       return $httpClient->get('https://company.clearbit.com/v1/domains/find', ...);
 *   });
 *
 * Configuration:
 *   SERVICES array defines per-service thresholds and timeouts
 */
class CircuitBreakerService
{
    /** @var \Illuminate\Redis\Connections\Connection|null */
    private static $redisClient = null;

    /** @var bool */
    private static $redisAvailable = null;

    /**
     * Circuit breaker configuration for critical external APIs
     */
    const SERVICES = [
        // Core APIs
        'twilio' => [
            'threshold' => 5,
            'timeout' => 60,
            'description' => 'Twilio Core Lookup API',
        ],
        'twilio_trust_hub' => [
            'threshold' => 5,
            'timeout' => 60,
            'description' => 'Twilio Trust Hub Regulatory Compliance API',
        ],

        // Business Intelligence
        'clearbit' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'Clearbit Company API',
        ],
        'numverify' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'NumVerify Phone Intelligence',
        ],

        // Email Discovery
        'hunter' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'Hunter.io Email Discovery',
        ],
        'zerobounce' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'ZeroBounce Email Verification',
        ],

        // Address/Location APIs
        'whitepages' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'Whitepages Pro Address Lookup',
        ],
        'truecaller' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'TrueCaller Address Lookup',
        ],
        'fcc_broadband' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'FCC Broadband Map API',
        ],
        'google_geocoding' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'Google Geocoding API',
        ],

        // AI/LLM APIs
        'openai' => [
            'threshold' => 5,
            'timeout' => 90,
            'description' => 'OpenAI API',
        ],
        'anthropic' => [
            'threshold' => 5,
            'timeout' => 90,
            'description' => 'Anthropic Claude API',
        ],
        'google_ai' => [
            'threshold' => 5,
            'timeout' => 90,
            'description' => 'Google Gemini API',
        ],

        // Other APIs
        'verizon' => [
            'threshold' => 3,
            'timeout' => 60,
            'description' => 'Verizon Coverage API',
        ],
        'google_places' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'Google Places API',
        ],
        'yelp' => [
            'threshold' => 3,
            'timeout' => 30,
            'description' => 'Yelp Fusion API',
        ],
    ];

    /**
     * Get Redis client
     */
    private static function getRedisClient()
    {
        if (self::$redisClient === null) {
            try {
                self::$redisClient = Redis::connection();
                self::$redisAvailable = true;
            } catch (Exception $e) {
                Log::warning("CircuitBreakerService: Could not connect to Redis: {$e->getMessage()}");
                self::$redisAvailable = false;
            }
        }

        return self::$redisAvailable ? self::$redisClient : null;
    }

    /**
     * Execute block with circuit breaker protection
     *
     * @param string $serviceName Name of service (must be in SERVICES array)
     * @param callable $callback Code to execute (API call)
     * @return mixed Result of callback execution, or fallback on circuit open
     */
    public static function call(string $serviceName, callable $callback)
    {
        $config = self::SERVICES[$serviceName] ?? null;

        if (!$config) {
            Log::warning("Unknown circuit breaker service: {$serviceName}. Add to SERVICES array.");
            // If service not configured, execute without circuit breaker
            return $callback();
        }

        $redis = self::getRedisClient();

        // If Redis not available, execute without circuit breaker
        if (!$redis) {
            return $callback();
        }

        $key = "circuit_breaker:{$serviceName}";
        $failuresKey = "{$key}:failures";
        $stateKey = "{$key}:state";

        try {
            // Check circuit state
            $state = $redis->get($stateKey) ?: 'closed';
            $failures = (int) $redis->get($failuresKey) ?: 0;

            // If circuit is open, fail fast
            if ($state === 'open') {
                return self::handleCircuitOpen($serviceName, null, $config);
            }

            // Execute the callback
            $result = $callback();

            // Success - reset failures
            $redis->del($failuresKey);
            if ($state === 'half_open') {
                $redis->set($stateKey, 'closed');
                self::logEvent($serviceName, 'close', null);
            }

            return $result;
        } catch (Exception $e) {
            // Increment failure count
            $redis->incr($failuresKey);
            $failures = (int) $redis->get($failuresKey);

            // Check if threshold exceeded
            if ($failures >= $config['threshold']) {
                $redis->setex($stateKey, $config['timeout'], 'open');
                self::logEvent($serviceName, 'open', $e);
            } else {
                self::logEvent($serviceName, 'failure', $e);
            }

            return self::handleCircuitOpen($serviceName, $e, $config);
        }
    }

    /**
     * Get current state of a circuit
     *
     * @param string $serviceName Service to check
     * @return string 'closed', 'half_open', 'open', or 'unknown'
     */
    public static function state(string $serviceName): string
    {
        if (!isset(self::SERVICES[$serviceName])) {
            return 'unknown';
        }

        $redis = self::getRedisClient();
        if (!$redis) {
            return 'unknown';
        }

        $key = "circuit_breaker:{$serviceName}:state";
        $state = $redis->get($key) ?: 'closed';

        return $state;
    }

    /**
     * Get all circuit states
     *
     * @return array Service name => state hash
     */
    public static function allStates(): array
    {
        $states = [];

        foreach (array_keys(self::SERVICES) as $serviceName) {
            $redis = self::getRedisClient();
            if (!$redis) {
                $states[$serviceName] = [
                    'state' => 'unknown',
                    'failures' => 0,
                    'description' => self::SERVICES[$serviceName]['description'],
                    'threshold' => self::SERVICES[$serviceName]['threshold'],
                    'timeout' => self::SERVICES[$serviceName]['timeout'],
                ];
                continue;
            }

            $key = "circuit_breaker:{$serviceName}";
            $state = $redis->get("{$key}:state") ?: 'closed';
            $failures = (int) $redis->get("{$key}:failures") ?: 0;

            $states[$serviceName] = [
                'state' => $state,
                'failures' => $failures,
                'description' => self::SERVICES[$serviceName]['description'],
                'threshold' => self::SERVICES[$serviceName]['threshold'],
                'timeout' => self::SERVICES[$serviceName]['timeout'],
            ];
        }

        return $states;
    }

    /**
     * Manually close a circuit (reset failures)
     *
     * @param string $serviceName Service to reset
     * @return bool
     */
    public static function reset(string $serviceName): bool
    {
        if (!isset(self::SERVICES[$serviceName])) {
            return false;
        }

        $redis = self::getRedisClient();
        if (!$redis) {
            return false;
        }

        $key = "circuit_breaker:{$serviceName}";
        $redis->del("{$key}:failures");
        $redis->del("{$key}:state");

        Log::info("Circuit breaker RESET for {$serviceName}");
        return true;
    }

    /**
     * Manually open a circuit (force failures)
     *
     * @param string $serviceName Service to open
     * @return bool
     */
    public static function openCircuit(string $serviceName): bool
    {
        if (!isset(self::SERVICES[$serviceName])) {
            return false;
        }

        $redis = self::getRedisClient();
        if (!$redis) {
            return false;
        }

        $config = self::SERVICES[$serviceName];
        $key = "circuit_breaker:{$serviceName}";
        $redis->setex("{$key}:state", $config['timeout'], 'open');

        Log::warning("Circuit breaker MANUALLY OPENED for {$serviceName}");
        return true;
    }

    /**
     * Log circuit breaker events
     */
    private static function logEvent(string $serviceName, string $event, ?Exception $error): void
    {
        $config = self::SERVICES[$serviceName];

        switch ($event) {
            case 'failure':
                Log::warning("Circuit breaker failure for {$serviceName}: " . get_class($error) . " - {$error->getMessage()}");
                break;
            case 'open':
                Log::error("Circuit breaker OPENED for {$serviceName} ({$config['description']}): " . get_class($error));
                break;
            case 'close':
                Log::info("Circuit breaker CLOSED for {$serviceName} (recovered)");
                break;
        }
    }

    /**
     * Fallback handler when circuit is open
     * Returns error array instead of throwing exception
     */
    private static function handleCircuitOpen(string $serviceName, ?Exception $error, array $config): array
    {
        $errorMessage = $error ? $error->getMessage() : 'Circuit open';

        Log::warning(
            "Circuit breaker OPEN: {$serviceName} ({$config['description']}) temporarily unavailable. " .
            "Will retry in {$config['timeout']}s. Error: {$errorMessage}"
        );

        // Return error hash instead of raising exception
        // This allows graceful degradation in enrichment services
        return [
            'error' => "{$config['description']} temporarily unavailable",
            'circuit_open' => true,
            'service' => $serviceName,
            'retry_after' => $config['timeout'],
            'fallback' => true,
        ];
    }
}
