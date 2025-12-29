<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ZipcodeLookupResource\Pages;
use App\Models\ZipcodeLookup;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Tables\Filters\SelectFilter;

class ZipcodeLookupResource extends Resource
{
    protected static ?string $model = ZipcodeLookup::class;

    protected static ?string $navigationIcon = 'heroicon-o-map-pin';

    protected static ?string $navigationLabel = 'Zipcode History';

    protected static ?string $navigationGroup = 'Business Lookup';

    protected static ?int $navigationSort = 4;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Zipcode Lookup')
                    ->schema([
                        Forms\Components\TextInput::make('zipcode')
                            ->label('Zipcode')
                            ->required()
                            ->placeholder('90210')
                            ->helperText('5-digit US zipcode')
                            ->maxLength(5)
                            ->minLength(5),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('id')
                    ->label('ID')
                    ->sortable(),
                Tables\Columns\TextColumn::make('zipcode')
                    ->label('Zipcode')
                    ->searchable()
                    ->sortable()
                    ->weight('bold')
                    ->fontFamily('mono'),
                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'completed' => 'success',
                        'failed' => 'danger',
                        'processing' => 'warning',
                        'pending' => 'info',
                    })
                    ->sortable(),
                Tables\Columns\TextColumn::make('provider')
                    ->label('Provider')
                    ->formatStateUsing(fn (?string $state): string => match ($state) {
                        'google_places' => '🗺️ Google Places',
                        'yelp' => '⭐ Yelp',
                        default => $state ? ucwords(str_replace('_', ' ', $state)) : '-',
                    })
                    ->sortable(),
                Tables\Columns\TextColumn::make('businesses_found')
                    ->label('Found')
                    ->sortable(),
                Tables\Columns\TextColumn::make('businesses_imported')
                    ->label('Imported')
                    ->color('success')
                    ->weight(fn (int $state): string => $state > 0 ? 'bold' : 'normal')
                    ->sortable(),
                Tables\Columns\TextColumn::make('businesses_updated')
                    ->label('Updated')
                    ->color('info')
                    ->weight(fn (int $state): string => $state > 0 ? 'bold' : 'normal')
                    ->sortable(),
                Tables\Columns\TextColumn::make('businesses_skipped')
                    ->label('Skipped')
                    ->sortable(),
                Tables\Columns\TextColumn::make('duration')
                    ->label('Duration')
                    ->formatStateUsing(fn (?float $state): string => $state ? round($state, 1) . 's' : '-')
                    ->sortable(),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('Created')
                    ->date('M d, H:i')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'pending' => 'Pending',
                        'processing' => 'Processing',
                        'completed' => 'Completed',
                        'failed' => 'Failed',
                    ]),
                SelectFilter::make('provider')
                    ->options([
                        'google_places' => 'Google Places',
                        'yelp' => 'Yelp',
                    ]),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\Action::make('view_contacts')
                    ->label('View Contacts')
                    ->icon('heroicon-o-users')
                    ->url(fn (ZipcodeLookup $record): string =>
                        '/admin/contacts?tableFilters[business_postal_code][value]=' . $record->zipcode
                    )
                    ->visible(fn (ZipcodeLookup $record): bool =>
                        $record->status === 'completed' && $record->businesses_found > 0
                    ),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                    Tables\Actions\BulkAction::make('reprocess')
                        ->label('Reprocess Selected')
                        ->icon('heroicon-o-arrow-path')
                        ->requiresConfirmation()
                        ->action(function ($records) {
                            foreach ($records as $record) {
                                // Create new lookup for the same zipcode
                                ZipcodeLookup::create([
                                    'zipcode' => $record->zipcode,
                                    'status' => 'pending',
                                ]);
                            }
                        }),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListZipcodeLookups::route('/'),
            'create' => Pages\CreateZipcodeLookup::route('/create'),
            'view' => Pages\ViewZipcodeLookup::route('/{record}'),
        ];
    }
}
