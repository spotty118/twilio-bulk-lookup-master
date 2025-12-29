<?php

namespace App\Traits;

use Illuminate\Database\Eloquent\Builder;

/**
 * ErrorTrackable Trait
 * Adds error tracking and analytics capabilities to models
 */
trait ErrorTrackable
{
    /**
     * Query Scopes
     */
    public function scopeWithErrors(Builder $query): Builder
    {
        return $query->whereNotNull('error_code');
    }

    public function scopeWithoutErrors(Builder $query): Builder
    {
        return $query->whereNull('error_code');
    }

    /**
     * Class Methods - Error Statistics
     */
    public static function errorStats(): array
    {
        return self::withErrors()
                   ->groupBy('error_code')
                   ->selectRaw('error_code, COUNT(*) as count')
                   ->orderByDesc('count')
                   ->pluck('count', 'error_code')
                   ->toArray();
    }

    public static function topErrors(int $limit = 10): array
    {
        $stats = self::errorStats();
        return array_slice($stats, 0, $limit, true);
    }

    public static function errorRate(): float
    {
        $total = self::count();
        
        if ($total === 0) {
            return 0;
        }

        $errorsCount = self::withErrors()->count();
        
        return round(($errorsCount / $total) * 100, 2);
    }

    public static function errorsByCategory(): array
    {
        $categories = [
            'invalid_format' => 0,
            'not_found' => 0,
            'authentication' => 0,
            'rate_limit' => 0,
            'network' => 0,
            'other' => 0,
        ];

        $errors = self::withErrors()->pluck('error_code');

        foreach ($errors as $error) {
            if (empty($error)) {
                continue;
            }

            $errorLower = strtolower($error);
            
            if (preg_match('/(invalid|format|malformed)/', $errorLower)) {
                $categories['invalid_format']++;
            } elseif (preg_match('/(not found|does not exist)/', $errorLower)) {
                $categories['not_found']++;
            } elseif (preg_match('/(auth|permission|unauthorized)/', $errorLower)) {
                $categories['authentication']++;
            } elseif (preg_match('/(rate limit|too many)/', $errorLower)) {
                $categories['rate_limit']++;
            } elseif (preg_match('/(network|timeout|connection)/', $errorLower)) {
                $categories['network']++;
            } else {
                $categories['other']++;
            }
        }

        // Return only categories with errors
        return array_filter($categories, fn($count) => $count > 0);
    }

    /**
     * Instance Methods
     */
    public function hasError(): bool
    {
        return !empty($this->error_code);
    }

    public function errorCategory(): ?string
    {
        if (!$this->hasError()) {
            return null;
        }

        $errorLower = strtolower($this->error_code);

        if (preg_match('/(invalid|format|malformed)/', $errorLower)) {
            return 'invalid_format';
        } elseif (preg_match('/(not found|does not exist)/', $errorLower)) {
            return 'not_found';
        } elseif (preg_match('/(auth|permission|unauthorized)/', $errorLower)) {
            return 'authentication';
        } elseif (preg_match('/(rate limit|too many)/', $errorLower)) {
            return 'rate_limit';
        } elseif (preg_match('/(network|timeout|connection)/', $errorLower)) {
            return 'network';
        } else {
            return 'other';
        }
    }

    public function errorSeverity(): string
    {
        if (!$this->hasError()) {
            return 'none';
        }

        return match ($this->errorCategory()) {
            'authentication', 'rate_limit' => 'critical',
            'invalid_format', 'not_found' => 'low',
            'network' => 'medium',
            default => 'medium',
        };
    }

    public function errorRecoverable(): bool
    {
        if (!$this->hasError()) {
            return false;
        }

        $category = $this->errorCategory();

        // Network and rate limit errors are typically recoverable
        if (in_array($category, ['network', 'rate_limit'])) {
            return true;
        }

        // Invalid format, not found, and authentication errors are not recoverable
        if (in_array($category, ['invalid_format', 'not_found', 'authentication'])) {
            return false;
        }

        // Conservative: don't retry unknown errors
        return false;
    }

    /**
     * Get a human-readable error message
     */
    public function errorMessageFormatted(): ?string
    {
        if (!$this->hasError()) {
            return null;
        }

        $category = $this->errorCategory();
        $severity = $this->errorSeverity();

        return match ($category) {
            'invalid_format' => "Invalid format: {$this->error_code}",
            'not_found' => "Not found: {$this->error_code}",
            'authentication' => "Authentication error: {$this->error_code}",
            'rate_limit' => "Rate limit exceeded: {$this->error_code}",
            'network' => "Network error: {$this->error_code}",
            default => "Error: {$this->error_code}",
        };
    }

    /**
     * Check if error should be retried
     */
    public function shouldRetryError(): bool
    {
        return $this->hasError() && $this->errorRecoverable();
    }
}
