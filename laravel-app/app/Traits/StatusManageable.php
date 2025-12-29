<?php

namespace App\Traits;

use Illuminate\Database\Eloquent\Builder;

/**
 * StatusManageable Trait
 * Provides status tracking and workflow management for models
 */
trait StatusManageable
{
    /**
     * Boot the trait
     */
    public static function bootStatusManageable()
    {
        // Track status changes before save
        static::saving(function ($model) {
            if ($model->isDirty('status')) {
                $model->trackStatusChange();
            }
        });

        // Log status changes after save
        static::saved(function ($model) {
            if ($model->wasChanged('status')) {
                $model->logStatusChange();
            }
        });
    }

    /**
     * Query Scopes for status management
     */
    public function scopeNeedsAttention(Builder $query): Builder
    {
        return $query->whereIn('status', ['pending', 'failed']);
    }

    public function scopeInProgress(Builder $query): Builder
    {
        return $query->where('status', 'processing');
    }

    public function scopeFinished(Builder $query): Builder
    {
        return $query->whereIn('status', ['completed', 'failed']);
    }

    /**
     * Get status distribution
     */
    public static function statusDistribution(): array
    {
        return self::groupBy('status')
                   ->selectRaw('status, COUNT(*) as count')
                   ->pluck('count', 'status')
                   ->toArray();
    }

    /**
     * Get status percentages
     */
    public static function statusPercentages(): array
    {
        $total = self::count();
        
        if ($total === 0) {
            return [];
        }

        $distribution = self::statusDistribution();
        
        return array_map(function ($count) use ($total) {
            return round(($count / $total) * 100, 2);
        }, $distribution);
    }

    /**
     * Get success rate
     */
    public static function successRate(): float
    {
        $finishedCount = self::finished()->count();
        
        if ($finishedCount === 0) {
            return 0;
        }

        $completedCount = self::where('status', 'completed')->count();
        
        return round(($completedCount / $finishedCount) * 100, 2);
    }

    /**
     * Get average processing time
     */
    public static function averageProcessingTime(): ?float
    {
        $average = self::whereNotNull('lookup_performed_at')
                       ->selectRaw('AVG(EXTRACT(EPOCH FROM (lookup_performed_at - created_at))) as avg_time')
                       ->value('avg_time');

        return $average ? round($average, 2) : null;
    }

    /**
     * Get stuck records (in processing for too long)
     */
    public function scopeStuckInProcessing(Builder $query, int $thresholdHours = 1): Builder
    {
        return $query->where('status', 'processing')
                     ->where('updated_at', '<', now()->subHours($thresholdHours));
    }

    /**
     * Instance Methods
     */
    public function statusValidTransition(?string $newStatus, ?string $fromStatus = null): bool
    {
        $fromStatus = $fromStatus ?? $this->status;

        return match ($fromStatus) {
            'pending' => in_array($newStatus, ['processing', 'failed']),
            'processing' => in_array($newStatus, ['completed', 'failed']),
            'completed' => $newStatus === 'pending', // Allow reprocessing
            'failed' => in_array($newStatus, ['pending', 'processing']), // Allow retry
            default => true, // Unknown state, allow transition
        };
    }

    public function canTransitionTo(string $newStatus): bool
    {
        return $this->statusValidTransition($newStatus);
    }

    public function processingTime(): ?float
    {
        if (!$this->lookup_performed_at || !$this->created_at) {
            return null;
        }

        return $this->lookup_performed_at->diffInSeconds($this->created_at);
    }

    public function processingTimeHumanized(): string
    {
        $seconds = $this->processingTime();

        if ($seconds === null) {
            return 'N/A';
        }

        if ($seconds < 60) {
            return round($seconds, 1) . 's';
        } elseif ($seconds < 3600) {
            return round($seconds / 60, 1) . 'm';
        } else {
            return round($seconds / 3600, 1) . 'h';
        }
    }

    public function isStuck(): bool
    {
        return $this->status === 'processing' && 
               $this->updated_at->lessThan(now()->subHour());
    }

    public function isTerminalState(): bool
    {
        return $this->status === 'completed';
    }

    public function isRetryableState(): bool
    {
        return in_array($this->status, ['failed', 'pending']);
    }

    public function statusBadgeClass(): string
    {
        return match ($this->status) {
            'completed' => 'success',
            'processing' => 'warning',
            'failed' => 'error',
            'pending' => 'info',
            default => 'default',
        };
    }

    /**
     * Private helper methods
     */
    private function trackStatusChange(): void
    {
        if ($this->exists) {
            $oldStatus = $this->getOriginal('status');
            $newStatus = $this->status;

            // Validate status transitions
            if ($oldStatus && !$this->statusValidTransition($newStatus, $oldStatus)) {
                \Log::error(get_class($this) . " #{$this->id}: Invalid status transition: {$oldStatus} -> {$newStatus}");
                // In Laravel, we can't use throw :abort like Rails, so we'll just log and proceed
                // You could throw an exception here if you want to prevent the save
            }
        } else {
            // New record - validate initial status
            $validInitialStatuses = ['pending', 'failed', 'completed', 'processing'];
            
            if ($this->status && !in_array($this->status, $validInitialStatuses)) {
                \Log::error(get_class($this) . ": Invalid initial status: {$this->status}");
            }
        }
    }

    private function logStatusChange(): void
    {
        $oldStatus = $this->getOriginal('status');
        $newStatus = $this->status;

        \Log::info(get_class($this) . " #{$this->id} status changed: {$oldStatus} -> {$newStatus}");
    }
}
