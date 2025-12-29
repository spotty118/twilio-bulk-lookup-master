<?php

namespace App\Http\Controllers;

use App\Models\Contact;
use App\Models\TwilioCredential;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Cache;

/**
 * Health Check Controller
 * Provides detailed health status for monitoring and alerting systems
 *
 * Endpoints:
 *   GET /up              - Rails compatibility endpoint
 *   GET /health          - Basic liveness probe (fast)
 *   GET /health/ready    - Readiness probe (checks dependencies)
 *   GET /health/detailed - Full diagnostic info (for debugging)
 *   GET /health/queue    - Background job status
 */
class HealthController extends Controller
{
    /**
     * Rails compatibility endpoint
     */
    public function up()
    {
        return response()->json([
            'status' => 'ok',
            'timestamp' => now()->toIso8601String(),
        ]);
    }

    /**
     * Liveness probe - fast response (for load balancer health checks)
     * Returns 200 if process is running
     */
    public function show()
    {
        return response()->json([
            'status' => 'ok',
            'timestamp' => now()->toIso8601String(),
            'version' => config('app.version', '1.0.0'),
        ]);
    }

    /**
     * Readiness probe - checks if app can serve traffic
     * Returns 503 if any critical dependency is down
     */
    public function ready()
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
        ];

        $allOk = collect($checks)->every(fn($check) => $check['status'] === 'ok');

        return response()->json([
            'status' => $allOk ? 'ok' : 'error',
            'timestamp' => now()->toIso8601String(),
            'checks' => $checks,
        ], $allOk ? 200 : 503);
    }

    /**
     * Detailed health check - includes all dependencies
     */
    public function detailed()
    {
        $healthStatus = [
            'status' => 'ok',
            'timestamp' => now()->toIso8601String(),
            'environment' => config('app.env'),
            'version' => config('app.version', '1.0.0'),
            'php_version' => PHP_VERSION,
            'laravel_version' => app()->version(),
            'uptime_seconds' => $this->getUptimeSeconds(),
            'memory' => $this->getMemoryUsage(),
            'checks' => [],
        ];

        // Core infrastructure
        $healthStatus['checks']['database'] = $this->checkDatabase();
        $healthStatus['checks']['redis'] = $this->checkRedis();
        $healthStatus['checks']['queue'] = $this->checkQueue();

        // Application state
        $healthStatus['checks']['twilio_credentials'] = $this->checkTwilioCredentials();
        $healthStatus['checks']['circuit_breakers'] = $this->checkCircuitBreakers();

        // Overall status
        $checks = collect($healthStatus['checks']);
        if ($checks->contains('status', 'error')) {
            $healthStatus['status'] = 'error';
            $statusCode = 503;
        } elseif ($checks->contains('status', 'warning')) {
            $healthStatus['status'] = 'warning';
            $statusCode = 200;
        } else {
            $statusCode = 200;
        }

        return response()->json($healthStatus, $statusCode);
    }

    /**
     * Queue status - for monitoring background jobs
     */
    public function queue()
    {
        $stats = [
            'contacts' => [
                'total' => Contact::count(),
                'pending' => Contact::where('status', 'pending')->count(),
                'processing' => Contact::where('status', 'processing')->count(),
                'completed' => Contact::where('status', 'completed')->count(),
                'failed' => Contact::where('status', 'failed')->count(),
            ],
            'horizon' => $this->getHorizonStats(),
            'timestamp' => now()->toIso8601String(),
        ];

        return response()->json($stats);
    }

    /**
     * Check database connectivity and connection pool
     */
    private function checkDatabase(): array
    {
        try {
            $start = microtime(true);
            DB::select('SELECT 1');
            $responseTime = round((microtime(true) - $start) * 1000, 2);

            return [
                'status' => 'ok',
                'response_time_ms' => $responseTime,
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Check Redis connectivity
     */
    private function checkRedis(): array
    {
        try {
            $start = microtime(true);
            Redis::ping();
            $responseTime = round((microtime(true) - $start) * 1000, 2);

            $info = Redis::info();

            return [
                'status' => 'ok',
                'response_time_ms' => $responseTime,
                'connected_clients' => $info['connected_clients'] ?? 0,
                'used_memory_human' => $info['used_memory_human'] ?? 'unknown',
                'uptime_days' => isset($info['uptime_in_seconds'])
                    ? round($info['uptime_in_seconds'] / 86400, 1)
                    : 'unknown',
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Check Laravel Horizon queue status
     */
    private function checkQueue(): array
    {
        try {
            // Check if Horizon is installed and running
            if (!class_exists(\Laravel\Horizon\Contracts\MasterSupervisorRepository::class)) {
                return [
                    'status' => 'warning',
                    'message' => 'Horizon not installed',
                ];
            }

            $masters = app(\Laravel\Horizon\Contracts\MasterSupervisorRepository::class)->all();
            $processCount = count($masters);

            $status = 'ok';
            if ($processCount === 0) {
                $status = 'error';
            }

            return [
                'status' => $status,
                'processes' => $processCount,
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Check Twilio credentials configuration
     */
    private function checkTwilioCredentials(): array
    {
        try {
            $creds = TwilioCredential::current();

            if (!$creds) {
                return [
                    'status' => 'warning',
                    'configured' => false,
                    'message' => 'No credentials configured',
                ];
            }

            return [
                'status' => 'ok',
                'configured' => true,
                'has_account_sid' => !empty($creds->account_sid),
                'has_auth_token' => !empty($creds->auth_token),
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Check circuit breakers status (if implemented)
     */
    private function checkCircuitBreakers(): array
    {
        // Circuit breakers not yet implemented in Laravel version
        return [
            'status' => 'ok',
            'message' => 'Not configured',
        ];
    }

    /**
     * Get Laravel Horizon statistics
     */
    private function getHorizonStats(): array
    {
        try {
            if (!class_exists(\Laravel\Horizon\Contracts\MetricsRepository::class)) {
                return ['error' => 'Horizon not installed'];
            }

            $metrics = app(\Laravel\Horizon\Contracts\MetricsRepository::class);

            return [
                'jobs_per_minute' => $metrics->jobsProcessedPerMinute(),
                'recent_jobs' => $metrics->recentJobs(),
                'failed_jobs' => $metrics->failedJobs(0, 1)[0] ?? [],
            ];
        } catch (\Exception $e) {
            return ['error' => $e->getMessage()];
        }
    }

    /**
     * Get memory usage in MB
     */
    private function getMemoryUsage(): array
    {
        try {
            if (file_exists('/proc/self/status')) {
                // Linux
                $status = file_get_contents('/proc/self/status');
                preg_match('/VmRSS:\s+(\d+)/', $status, $matches);
                $vmRssKb = $matches[1] ?? 0;
                return ['rss_mb' => round($vmRssKb / 1024, 1)];
            } else {
                // macOS/other
                $pid = getmypid();
                $rssKb = trim(shell_exec("ps -o rss= -p {$pid}"));
                return ['rss_mb' => round($rssKb / 1024, 1)];
            }
        } catch (\Exception $e) {
            return ['rss_mb' => 'unknown'];
        }
    }

    /**
     * Get application uptime in seconds
     */
    private function getUptimeSeconds()
    {
        try {
            if (file_exists('/proc/self/stat')) {
                $stat = explode(' ', file_get_contents('/proc/self/stat'));
                $startTimeTicks = $stat[21] ?? 0;
                $hertz = 100; // Usually 100 on Linux
                $systemUptime = floatval(explode(' ', file_get_contents('/proc/uptime'))[0]);
                $processStart = $startTimeTicks / $hertz;
                return (int)($systemUptime - $processStart);
            }
            return 'unknown';
        } catch (\Exception $e) {
            return 'unknown';
        }
    }
}
