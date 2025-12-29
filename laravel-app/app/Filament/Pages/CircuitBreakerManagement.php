<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;
use Filament\Notifications\Notification;
use App\Services\CircuitBreakerService;
use Illuminate\Support\Facades\Redis;

class CircuitBreakerManagement extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-shield-check';
    protected static string $view = 'filament.pages.circuit-breaker-management';
    protected static ?string $navigationLabel = 'Circuit Breakers';
    protected static ?string $navigationGroup = 'Monitoring';
    protected static ?int $navigationSort = 3;

    public $circuitBreakers = [];
    public $editingService = null;
    public $editThreshold = 0;
    public $editTimeout = 0;
    public $historicalData = [];

    public function mount(): void
    {
        $this->loadCircuitBreakers();
        $this->loadHistoricalData();
    }

    protected function loadCircuitBreakers(): void
    {
        $this->circuitBreakers = CircuitBreakerService::allStates();
    }

    protected function loadHistoricalData(): void
    {
        // Load historical failure data from Redis or database
        $this->historicalData = [];

        try {
            $redis = Redis::connection();
            foreach (array_keys($this->circuitBreakers) as $service) {
                $key = "circuit_breaker:{$service}:history";
                $history = $redis->lrange($key, 0, 9); // Get last 10 events
                $this->historicalData[$service] = array_map(function ($item) {
                    return json_decode($item, true);
                }, $history);
            }
        } catch (\Exception $e) {
            // Redis not available, continue without historical data
        }
    }

    public function resetCircuitBreaker(string $service): void
    {
        if (CircuitBreakerService::reset($service)) {
            Notification::make()
                ->title('Circuit breaker reset')
                ->success()
                ->body("Circuit breaker for {$service} has been reset to closed state.")
                ->send();

            $this->loadCircuitBreakers();
            $this->loadHistoricalData();
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
                ->body("Circuit breaker for {$service} has been manually opened. It will automatically reset after the timeout period.")
                ->send();

            $this->loadCircuitBreakers();
            $this->loadHistoricalData();
        } else {
            Notification::make()
                ->title('Operation failed')
                ->danger()
                ->body("Failed to open circuit breaker for {$service}.")
                ->send();
        }
    }

    public function closeCircuitBreaker(string $service): void
    {
        if (CircuitBreakerService::reset($service)) {
            Notification::make()
                ->title('Circuit breaker closed')
                ->success()
                ->body("Circuit breaker for {$service} has been manually closed.")
                ->send();

            $this->loadCircuitBreakers();
            $this->loadHistoricalData();
        } else {
            Notification::make()
                ->title('Operation failed')
                ->danger()
                ->body("Failed to close circuit breaker for {$service}.")
                ->send();
        }
    }

    public function setHalfOpen(string $service): void
    {
        try {
            $redis = Redis::connection();
            $key = "circuit_breaker:{$service}:state";
            $redis->set($key, 'half_open');

            Notification::make()
                ->title('Circuit breaker set to half-open')
                ->info()
                ->body("Circuit breaker for {$service} is now in half-open state for testing.")
                ->send();

            $this->loadCircuitBreakers();
        } catch (\Exception $e) {
            Notification::make()
                ->title('Operation failed')
                ->danger()
                ->body("Failed to set circuit breaker state: {$e->getMessage()}")
                ->send();
        }
    }

    public function resetAllCircuitBreakers(): void
    {
        $count = 0;
        foreach (array_keys($this->circuitBreakers) as $service) {
            if (CircuitBreakerService::reset($service)) {
                $count++;
            }
        }

        Notification::make()
            ->title('All circuit breakers reset')
            ->success()
            ->body("Reset {$count} circuit breakers.")
            ->send();

        $this->loadCircuitBreakers();
        $this->loadHistoricalData();
    }

    public function refreshData(): void
    {
        $this->loadCircuitBreakers();
        $this->loadHistoricalData();

        Notification::make()
            ->title('Data refreshed')
            ->success()
            ->send();
    }
}
