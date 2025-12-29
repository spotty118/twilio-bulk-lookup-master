<?php

namespace App\Filament\Pages;

use Filament\Pages\Dashboard as BaseDashboard;
use App\Models\Contact;
use App\Models\ApiUsageLog;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;

class Dashboard extends BaseDashboard
{
    protected static ?string $navigationIcon = 'heroicon-o-home';

    protected static string $view = 'filament.pages.dashboard';

    public $stats = [];
    public $recentContacts = [];
    public $systemHealth = [];
    public $dailyProcessing = [];

    public function mount(): void
    {
        $this->loadStats();
        $this->loadRecentContacts();
        $this->loadSystemHealth();
        $this->loadDailyProcessing();
    }

    protected function loadStats(): void
    {
        $this->stats = [
            'total' => Contact::count(),
            'pending' => Contact::where('status', 'pending')->count(),
            'processing' => Contact::where('status', 'processing')->count(),
            'completed' => Contact::where('status', 'completed')->count(),
            'failed' => Contact::where('status', 'failed')->count(),
        ];
    }

    protected function loadRecentContacts(): void
    {
        $this->recentContacts = Contact::latest()
            ->take(10)
            ->get()
            ->map(function ($contact) {
                return [
                    'id' => $contact->id,
                    'phone' => $contact->formatted_phone_number ?? $contact->raw_phone_number,
                    'name' => $contact->business_name ?? ($contact->first_name . ' ' . $contact->last_name) ?: 'N/A',
                    'status' => $contact->status,
                    'type' => $contact->is_business ? 'Business' : 'Consumer',
                    'created_at' => $contact->created_at->diffForHumans(),
                ];
            });
    }

    protected function loadSystemHealth(): void
    {
        $this->systemHealth = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
            'queue' => $this->checkQueue(),
        ];
    }

    protected function loadDailyProcessing(): void
    {
        $this->dailyProcessing = Contact::select(
            DB::raw('DATE(created_at) as date'),
            DB::raw('COUNT(*) as count')
        )
            ->where('created_at', '>=', now()->subDays(7))
            ->groupBy('date')
            ->orderBy('date', 'desc')
            ->get()
            ->map(function ($item) {
                return [
                    'date' => \Carbon\Carbon::parse($item->date)->format('M d'),
                    'count' => $item->count,
                ];
            });
    }

    protected function checkDatabase(): array
    {
        try {
            DB::connection()->getPdo();
            return ['status' => 'healthy', 'message' => 'Connected'];
        } catch (\Exception $e) {
            return ['status' => 'unhealthy', 'message' => 'Connection failed'];
        }
    }

    protected function checkRedis(): array
    {
        try {
            Cache::store('redis')->get('health_check');
            return ['status' => 'healthy', 'message' => 'Connected'];
        } catch (\Exception $e) {
            return ['status' => 'warning', 'message' => 'Not available'];
        }
    }

    protected function checkQueue(): array
    {
        try {
            $failedJobs = DB::table('failed_jobs')->count();
            if ($failedJobs > 10) {
                return ['status' => 'warning', 'message' => "{$failedJobs} failed jobs"];
            }
            return ['status' => 'healthy', 'message' => 'Running'];
        } catch (\Exception $e) {
            return ['status' => 'unknown', 'message' => 'Cannot check'];
        }
    }

    public function getWidgets(): array
    {
        return [
            \App\Filament\Widgets\ContactsStatsWidget::class,
        ];
    }

    public function getColumns(): int | string | array
    {
        return 2;
    }
}
