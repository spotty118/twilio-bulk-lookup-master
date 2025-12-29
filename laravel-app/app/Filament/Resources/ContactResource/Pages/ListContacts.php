<?php

namespace App\Filament\Resources\ContactResource\Pages;

use App\Filament\Resources\ContactResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Filament\Resources\Components\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListContacts extends ListRecords
{
    protected static string $resource = ContactResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
            Actions\Action::make('run_lookup')
                ->label('Run Bulk Lookup')
                ->icon('heroicon-o-play')
                ->color('success')
                ->url(route('lookup.run'))
                ->requiresConfirmation()
                ->modalHeading('Run Bulk Lookup')
                ->modalDescription('This will queue pending contacts for lookup processing. Maximum 1000 contacts per batch.')
                ->modalSubmitActionLabel('Start Lookup'),
        ];
    }

    public function getTabs(): array
    {
        return [
            'all' => Tab::make('All'),
            'pending' => Tab::make('Pending')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'pending'))
                ->badge(fn (): int => \App\Models\Contact::where('status', 'pending')->count()),
            'processing' => Tab::make('Processing')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'processing'))
                ->badge(fn (): int => \App\Models\Contact::where('status', 'processing')->count()),
            'completed' => Tab::make('Completed')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'completed'))
                ->badge(fn (): int => \App\Models\Contact::where('status', 'completed')->count()),
            'failed' => Tab::make('Failed')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'failed'))
                ->badge(fn (): int => \App\Models\Contact::where('status', 'failed')->count()),
            'high_risk' => Tab::make('High Risk')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('sms_pumping_risk_level', 'high'))
                ->badge(fn (): int => \App\Models\Contact::where('sms_pumping_risk_level', 'high')->count()),
            'businesses' => Tab::make('Businesses')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('is_business', true))
                ->badge(fn (): int => \App\Models\Contact::where('is_business', true)->count()),
            'consumers' => Tab::make('Consumers')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('is_business', false))
                ->badge(fn (): int => \App\Models\Contact::where('is_business', false)->count()),
        ];
    }
}
