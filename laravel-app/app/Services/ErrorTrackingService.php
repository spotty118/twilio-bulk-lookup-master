<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Exception;

/**
 * ErrorTrackingService - Unified error tracking with Sentry integration
 *
 * Provides structured error logging with consistent categorization,
 * stack traces, and optional Sentry reporting.
 *
 * Usage:
 *   ErrorTrackingService::capture($exception, ['contact_id' => 123]);
 *   ErrorTrackingService::warn("Rate limit exceeded", ['api' => 'twilio']);
 */
class ErrorTrackingService
{
    /**
     * Error categories for consistent classification
     */
    const CATEGORIES = [
        'transient' => ['timeout', 'network', 'rate_limit', '503', '502', '429'],
        'permanent' => ['invalid_number', 'not_found', 'authentication', 'validation'],
        'configuration' => ['missing_key', 'no_credentials', 'disabled'],
        'internal' => ['nil_class', 'undefined_method'],
    ];

    /**
     * Capture an exception with full context
     *
     * @param Exception $exception The exception to capture
     * @param array $context Additional context (contact_id, job_id, etc.)
     * @param array $tags Tags for categorization
     * @param string $level 'error', 'warning', 'info'
     * @return void
     */
    public static function capture(Exception $exception, array $context = [], array $tags = [], string $level = 'error'): void
    {
        $category = self::categorizeException($exception);

        self::logStructured([
            'level' => $level,
            'category' => $category,
            'exception_class' => get_class($exception),
            'message' => $exception->getMessage(),
            'context' => $context,
            'tags' => $tags,
            'backtrace' => implode("\n", array_slice($exception->getTrace(), 0, 10)),
        ]);

        // Report to Sentry if available and not transient
        if ($category !== 'transient' && function_exists('app') && app()->bound('sentry')) {
            if (function_exists('\Sentry\captureException')) {
                \Sentry\captureException($exception);
            }
        }
    }

    /**
     * Log a warning with structured format
     *
     * @param string $message
     * @param array $context
     * @param array $tags
     * @return void
     */
    public static function warn(string $message, array $context = [], array $tags = []): void
    {
        self::logStructured([
            'level' => 'warn',
            'category' => 'warning',
            'message' => $message,
            'context' => $context,
            'tags' => $tags,
        ]);
    }

    /**
     * Log info with structured format
     *
     * @param string $message
     * @param array $context
     * @param array $tags
     * @return void
     */
    public static function info(string $message, array $context = [], array $tags = []): void
    {
        self::logStructured([
            'level' => 'info',
            'category' => 'info',
            'message' => $message,
            'context' => $context,
            'tags' => $tags,
        ]);
    }

    /**
     * Track a rate limit event
     *
     * @param string $provider
     * @param int|null $retryAfter
     * @param array $context
     * @return void
     */
    public static function trackRateLimit(string $provider, ?int $retryAfter = null, array $context = []): void
    {
        $contextWithRetry = array_merge($context, ['retry_after' => $retryAfter]);

        self::logStructured([
            'level' => 'warn',
            'category' => 'rate_limit',
            'message' => "Rate limit exceeded for {$provider}",
            'context' => $contextWithRetry,
            'tags' => ['provider' => $provider, 'rate_limited' => true],
        ]);

        // Optionally report to Sentry as warning
        if (function_exists('\Sentry\captureMessage')) {
            \Sentry\captureMessage(
                "Rate limit: {$provider}",
                \Sentry\Severity::warning()
            );
        }
    }

    /**
     * Track a circuit breaker event
     *
     * @param string $service
     * @param string $state
     * @param array $context
     * @return void
     */
    public static function trackCircuitBreaker(string $service, string $state, array $context = []): void
    {
        $level = $state === 'open' ? 'error' : 'info';

        self::logStructured([
            'level' => $level,
            'category' => 'circuit_breaker',
            'message' => "Circuit breaker {$state} for {$service}",
            'context' => $context,
            'tags' => ['service' => $service, 'circuit_state' => $state],
        ]);

        if ($state === 'open' && function_exists('\Sentry\captureMessage')) {
            \Sentry\captureMessage(
                "Circuit breaker OPEN: {$service}",
                \Sentry\Severity::error()
            );
        }
    }

    /**
     * Categorize exception
     */
    private static function categorizeException(Exception $exception): string
    {
        $message = strtolower($exception->getMessage());

        foreach (self::CATEGORIES as $category => $keywords) {
            foreach ($keywords as $keyword) {
                if (strpos($message, $keyword) !== false) {
                    return $category;
                }
            }
        }

        // Default categorization by exception type
        $exceptionClass = get_class($exception);

        if (strpos($exceptionClass, 'Timeout') !== false || strpos($exceptionClass, 'Network') !== false) {
            return 'transient';
        }

        if (strpos($exceptionClass, 'Invalid') !== false || strpos($exceptionClass, 'NotFound') !== false) {
            return 'permanent';
        }

        return 'unknown';
    }

    /**
     * Log structured data
     */
    private static function logStructured(array $data): void
    {
        $logEntry = [
            'timestamp' => now()->toIso8601String(),
            'level' => strtoupper($data['level'] ?? 'INFO'),
            'category' => $data['category'] ?? 'unknown',
            'message' => $data['message'] ?? '',
            'context' => $data['context'] ?? [],
            'tags' => $data['tags'] ?? [],
        ];

        if (!empty($data['backtrace'])) {
            $logEntry['backtrace'] = $data['backtrace'];
        }

        if (!empty($data['exception_class'])) {
            $logEntry['exception_class'] = $data['exception_class'];
        }

        // Format for structured logging (JSON in production, readable in dev)
        if (app()->environment('production')) {
            Log::log(
                strtolower($data['level'] ?? 'info'),
                json_encode($logEntry)
            );
        } else {
            $formatted = "[{$logEntry['level']}] [{$logEntry['category']}] {$logEntry['message']}";

            if (!empty($logEntry['context'])) {
                $formatted .= " | context: " . json_encode($logEntry['context']);
            }

            if (!empty($logEntry['tags'])) {
                $formatted .= " | tags: " . json_encode($logEntry['tags']);
            }

            if (!empty($logEntry['backtrace'])) {
                $formatted .= "\n  {$logEntry['backtrace']}";
            }

            Log::log(strtolower($data['level'] ?? 'info'), $formatted);
        }
    }
}
