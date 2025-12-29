<?php

namespace App\Filament\Widgets;

use App\Models\Contact;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class ContactsStatsWidget extends BaseWidget
{
    protected function getStats(): array
    {
        $total = Contact::count();
        $pending = Contact::where('status', 'pending')->count();
        $processing = Contact::where('status', 'processing')->count();
        $completed = Contact::where('status', 'completed')->count();
        $failed = Contact::where('status', 'failed')->count();
        $highRisk = Contact::where('sms_pumping_risk_level', 'high')->count();

        return [
            Stat::make('Total Contacts', number_format($total))
                ->description('All contacts in database')
                ->icon('heroicon-o-phone')
                ->color('gray'),

            Stat::make('Pending', number_format($pending))
                ->description('Waiting for processing')
                ->icon('heroicon-o-clock')
                ->color('warning'),

            Stat::make('Processing', number_format($processing))
                ->description('Currently being processed')
                ->icon('heroicon-o-arrow-path')
                ->color('info'),

            Stat::make('Completed', number_format($completed))
                ->description('Successfully processed')
                ->icon('heroicon-o-check-circle')
                ->color('success'),

            Stat::make('Failed', number_format($failed))
                ->description('Processing failed')
                ->icon('heroicon-o-x-circle')
                ->color('danger'),

            Stat::make('High Risk', number_format($highRisk))
                ->description('SMS pumping risk')
                ->icon('heroicon-o-shield-exclamation')
                ->color('danger'),
        ];
    }

    protected function getColumns(): int
    {
        return 3;
    }
}
