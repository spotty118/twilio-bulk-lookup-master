<?php

namespace App\Jobs;

use App\Models\DashboardStats;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Exception;

/**
 * Debounced dashboard broadcast job
 * This job is enqueued by Contact model callbacks but only actually broadcasts
 * if sufficient time has passed since the last broadcast, coalescing rapid changes.
 */
class DashboardBroadcastJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

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
     * The unique ID of the job.
     * This prevents duplicate jobs from being enqueued.
     *
     * @return string
     */
    public function uniqueId()
    {
        return 'dashboard-broadcast';
    }

    /**
     * Create a new job instance.
     */
    public function __construct()
    {
        $this->onQueue('default');
    }

    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        // Double-check throttle to handle race conditions between job enqueue and execution
        $throttleKey = 'dashboard_broadcast_executing';

        // Use atomic operation to prevent multiple jobs from broadcasting simultaneously
        if (!Cache::add($throttleKey, true, 1)) {
            return;
        }

        try {
            // Refresh materialized stats outside of write transactions
            try {
                DashboardStats::refresh();
            } catch (Exception $e) {
                Log::warning("Dashboard stats refresh failed: {$e->getMessage()}");
            }

            // Broadcast the actual update using Laravel's broadcasting
            // This replaces Rails' Turbo::StreamsChannel
            broadcast(new \App\Events\DashboardStatsUpdated());

            Log::debug("Dashboard stats broadcast completed");

        } catch (Exception $e) {
            Log::warning("Dashboard broadcast job failed: {$e->getMessage()}");
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
        Log::warning("DashboardBroadcastJob failed: {$exception->getMessage()}");
    }
}
