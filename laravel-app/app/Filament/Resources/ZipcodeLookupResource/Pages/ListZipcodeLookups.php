<?php

namespace App\Filament\Resources\ZipcodeLookupResource\Pages;

use App\Filament\Resources\ZipcodeLookupResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;
use Filament\Resources\Components\Tab;
use Illuminate\Database\Eloquent\Builder;

class ListZipcodeLookups extends ListRecords
{
    protected static string $resource = ZipcodeLookupResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }

    public function getTabs(): array
    {
        return [
            'all' => Tab::make('All'),
            'completed' => Tab::make('✅ Completed')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'completed'))
                ->badge(fn (): int => \App\Models\ZipcodeLookup::where('status', 'completed')->count()),
            'failed' => Tab::make('❌ Failed')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'failed'))
                ->badge(fn (): int => \App\Models\ZipcodeLookup::where('status', 'failed')->count()),
            'processing' => Tab::make('⏳ Processing')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'processing'))
                ->badge(fn (): int => \App\Models\ZipcodeLookup::where('status', 'processing')->count()),
            'pending' => Tab::make('🕐 Pending')
                ->modifyQueryUsing(fn (Builder $query) => $query->where('status', 'pending'))
                ->badge(fn (): int => \App\Models\ZipcodeLookup::where('status', 'pending')->count()),
        ];
    }
}
