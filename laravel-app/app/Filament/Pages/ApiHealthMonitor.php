<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;
use Filament\Notifications\Notification;
use App\Services\CircuitBreakerService;
use App\Models\ApiUsageLog;
use Illuminate\Support\Facades\DB;

class ApiHealthMonitor extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-chart-bar';
    protected static string $view = 'filament.pages.api-health-monitor';
    protected static ?string $navigationLabel = 'API Health';
    protected static ?string $navigationGroup = 'Monitoring';
    protected static ?int $navigationSort = 2;

    public $circuitBreakers = [];
    public $apiMetrics = [];
    public $recentUsage = [];
    public $costsByProvider = [];
    public $totalCost = 0;

    public function mount(): void
    {
        $this->loadCircuitBreakers();
        $this->loadApiMetrics();
        $this->loadRecentUsage();
        $this->loadCostTracking();
    }

    protected function loadCircuitBreakers(): void
    {
        $this->circuitBreakers = CircuitBreakerService::allStates();
    }

    protected function loadApiMetrics(): void
    {
        $stats = ApiUsageLog::usageStats(now()->subHours(24), now());

        $this->apiMetrics = [
            'total_requests' => $stats['total_requests'] ?? 0,
            'successful' => $stats['successful_requests'] ?? 0,
            'failed' => $stats['failed_requests'] ?? 0,
            'success_rate' => $stats['total_requests'] > 0
                ? round(($stats['successful_requests'] / $stats['total_requests']) * 100, 2)
                : 0,
            'avg_response_time' => $stats['average_response_time'] ?? 0,
            'by_provider' => $stats['by_provider'] ?? [],
        ];
    }

    protected function loadRecentUsage(): void
    {
        $this->recentUsage = ApiUsageLog::with('contact')
            ->latest('requested_at')
            ->take(20)
            ->get()
            ->map(function ($log) {
                return [
                    'id' => $log->id,
                    'provider' => $log->provider,
                    'service' => $log->service,
                    'status' => $log->status,
                    'response_time' => $log->response_time_ms,
                    'cost' => $log->cost,
                    'requested_at' => $log->requested_at->diffForHumans(),
                    'contact_id' => $log->contact_id,
                ];
            })
            ->toArray();
    }

    protected function loadCostTracking(): void
    {
        $this->totalCost = ApiUsageLog::totalCost(now()->startOfMonth(), now());
        $this->costsByProvider = ApiUsageLog::totalCostByProvider(now()->startOfMonth(), now());
    }

    public function resetCircuitBreaker(string $service): void
    {
        if (CircuitBreakerService::reset($service)) {
            Notification::make()
                ->title('Circuit breaker reset')
                ->success()
                ->body("Circuit breaker for {$service} has been reset.")
                ->send();

            $this->loadCircuitBreakers();
        } else {
            Notification::make()
                ->title('Reset failed')
                ->danger()
                ->body("Failed to reset circuit breaker for {$service}.")
                ->send();
        }
    }

    public function openCircuitBreaker(string $service): void
    {
        if (CircuitBreakerService::openCircuit($service)) {
            Notification::make()
                ->title('Circuit breaker opened')
                ->warning()
                ->body("Circuit breaker for {$service} has been manually opened.")
                ->send();

            $this->loadCircuitBreakers();
        } else {
            Notification::make()
                ->title('Operation failed')
                ->danger()
                ->body("Failed to open circuit breaker for {$service}.")
                ->send();
        }
    }

    public function refreshMetrics(): void
    {
        $this->loadCircuitBreakers();
        $this->loadApiMetrics();
        $this->loadRecentUsage();
        $this->loadCostTracking();

        Notification::make()
            ->title('Metrics refreshed')
            ->success()
            ->send();
    }
}
