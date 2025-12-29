<?php

namespace App\Filament\Resources;

use App\Filament\Resources\ContactResource\Pages;
use App\Models\Contact;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Infolists;
use Filament\Infolists\Infolist;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\Filter;
use Illuminate\Database\Eloquent\Builder;

class ContactResource extends Resource
{
    protected static ?string $model = Contact::class;

    protected static ?string $navigationIcon = 'heroicon-o-phone';

    protected static ?string $navigationLabel = 'Contacts';

    protected static ?int $navigationSort = 2;

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Contact Details')
                    ->schema([
                        Forms\Components\TextInput::make('raw_phone_number')
                            ->label('Phone Number')
                            ->placeholder('+14155551234')
                            ->helperText('E.164 format (e.g., +14155551234)')
                            ->required(),
                        Forms\Components\Select::make('status')
                            ->options([
                                'pending' => 'Pending',
                                'processing' => 'Processing',
                                'completed' => 'Completed',
                                'failed' => 'Failed',
                            ])
                            ->required(),
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
                Tables\Columns\TextColumn::make('raw_phone_number')
                    ->label('Phone')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('status')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'completed' => 'success',
                        'processing' => 'info',
                        'failed' => 'danger',
                        'pending' => 'warning',
                    })
                    ->sortable(),
                Tables\Columns\TextColumn::make('device_type')
                    ->label('Type')
                    ->badge()
                    ->color('gray')
                    ->default('-')
                    ->sortable(),
                Tables\Columns\TextColumn::make('rpv_status')
                    ->label('Line Status')
                    ->badge()
                    ->color(fn (?string $state): string => match ($state) {
                        'connected' => 'success',
                        'disconnected' => 'danger',
                        default => 'warning',
                    })
                    ->default('-')
                    ->sortable(),
                Tables\Columns\TextColumn::make('carrier_name')
                    ->label('Carrier')
                    ->default('-')
                    ->searchable(),
                Tables\Columns\IconColumn::make('scout_ported')
                    ->label('Ported')
                    ->boolean()
                    ->default(false)
                    ->sortable(),
                Tables\Columns\TextColumn::make('business_name')
                    ->label('Contact')
                    ->formatStateUsing(function (Contact $record) {
                        if ($record->is_business) {
                            return $record->business_name ?? 'Business';
                        }
                        return $record->email ?? '-';
                    })
                    ->searchable(),
                Tables\Columns\TextColumn::make('lookup_performed_at')
                    ->label('Processed')
                    ->date('M d')
                    ->default('-')
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
                SelectFilter::make('device_type')
                    ->label('Type')
                    ->options([
                        'mobile' => 'Mobile',
                        'landline' => 'Landline',
                        'voip' => 'VoIP',
                    ]),
                SelectFilter::make('rpv_status')
                    ->label('Line Status')
                    ->options([
                        'connected' => 'Connected',
                        'disconnected' => 'Disconnected',
                    ]),
                SelectFilter::make('sms_pumping_risk_level')
                    ->label('Risk Level')
                    ->options([
                        'high' => 'High Risk',
                        'medium' => 'Medium Risk',
                        'low' => 'Low Risk',
                    ]),
                Filter::make('is_business')
                    ->label('Businesses')
                    ->query(fn (Builder $query): Builder => $query->where('is_business', true)),
                Filter::make('is_consumer')
                    ->label('Consumers')
                    ->query(fn (Builder $query): Builder => $query->where('is_business', false)),
                Filter::make('scout_ported')
                    ->label('Ported Numbers')
                    ->query(fn (Builder $query): Builder => $query->where('scout_ported', true)),
            ])
            ->actions([
                Tables\Actions\ViewAction::make(),
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                    Tables\Actions\BulkAction::make('reprocess')
                        ->label('Reprocess Selected')
                        ->icon('heroicon-o-arrow-path')
                        ->requiresConfirmation()
                        ->action(function ($records) {
                            // Queue reprocessing logic here
                            foreach ($records as $record) {
                                $record->update(['status' => 'pending']);
                            }
                        }),
                    Tables\Actions\BulkAction::make('mark_pending')
                        ->label('Mark as Pending')
                        ->icon('heroicon-o-clock')
                        ->requiresConfirmation()
                        ->action(function ($records) {
                            $records->each->update(['status' => 'pending']);
                        }),
                ]),
            ])
            ->defaultSort('id', 'asc');
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist
            ->schema([
                Infolists\Components\Section::make('Basic Information')
                    ->schema([
                        Infolists\Components\TextEntry::make('id')->label('ID'),
                        Infolists\Components\TextEntry::make('status')
                            ->badge()
                            ->color(fn (string $state): string => match ($state) {
                                'completed' => 'success',
                                'processing' => 'info',
                                'failed' => 'danger',
                                'pending' => 'warning',
                            }),
                        Infolists\Components\TextEntry::make('raw_phone_number')->label('Raw Phone'),
                        Infolists\Components\TextEntry::make('formatted_phone_number')->label('Formatted Phone'),
                        Infolists\Components\TextEntry::make('lookup_performed_at')
                            ->dateTime()
                            ->default('Not performed yet'),
                    ])
                    ->columns(2),

                Infolists\Components\Section::make('Line Information')
                    ->schema([
                        Infolists\Components\TextEntry::make('device_type')
                            ->badge()
                            ->default('Unknown'),
                        Infolists\Components\TextEntry::make('line_type')->default('-'),
                        Infolists\Components\TextEntry::make('carrier_name')->default('-'),
                        Infolists\Components\TextEntry::make('country_code')->default('-'),
                    ])
                    ->columns(2)
                    ->visible(fn (Contact $record): bool => $record->device_type !== null),

                Infolists\Components\Section::make('Line Status (Real Phone Validation)')
                    ->schema([
                        Infolists\Components\TextEntry::make('rpv_status')
                            ->label('Status')
                            ->badge()
                            ->color(fn (?string $state): string => match ($state) {
                                'connected' => 'success',
                                'disconnected' => 'danger',
                                default => 'warning',
                            }),
                        Infolists\Components\TextEntry::make('rpv_iscell')
                            ->label('Is Cell')
                            ->formatStateUsing(fn (?string $state): string => match ($state) {
                                'Y' => 'Yes',
                                'N' => 'No',
                                'V' => 'VoIP',
                                default => '-',
                            }),
                        Infolists\Components\TextEntry::make('rpv_carrier')->label('Carrier')->default('-'),
                        Infolists\Components\TextEntry::make('rpv_cnam')->label('Caller Name (CNAM)')->default('-'),
                    ])
                    ->columns(2)
                    ->visible(fn (Contact $record): bool => $record->rpv_status !== null),

                Infolists\Components\Section::make('Porting Information (Scout)')
                    ->schema([
                        Infolists\Components\IconEntry::make('scout_ported')
                            ->label('Ported')
                            ->boolean(),
                        Infolists\Components\TextEntry::make('scout_operating_company_name')
                            ->label('Operating Company')
                            ->default('-'),
                        Infolists\Components\TextEntry::make('scout_operating_company_type')
                            ->label('Company Type')
                            ->default('-'),
                        Infolists\Components\TextEntry::make('scout_location_routing_number')
                            ->label('Location Routing Number')
                            ->default('-'),
                    ])
                    ->columns(2)
                    ->visible(fn (Contact $record): bool => $record->scout_ported !== null),

                Infolists\Components\Section::make('Fraud Assessment')
                    ->schema([
                        Infolists\Components\TextEntry::make('sms_pumping_risk_level')
                            ->label('Risk Level')
                            ->badge()
                            ->color(fn (?string $state): string => match ($state) {
                                'high' => 'danger',
                                'medium' => 'warning',
                                'low' => 'success',
                                default => 'gray',
                            }),
                        Infolists\Components\TextEntry::make('sms_pumping_risk_score')
                            ->label('Risk Score')
                            ->formatStateUsing(fn (?int $state): string => $state ? "{$state}/100" : '-'),
                        Infolists\Components\IconEntry::make('sms_pumping_number_blocked')
                            ->label('Blocked')
                            ->boolean(),
                    ])
                    ->columns(3)
                    ->visible(fn (Contact $record): bool => $record->sms_pumping_risk_level !== null),

                Infolists\Components\Section::make('Business Details')
                    ->schema([
                        Infolists\Components\TextEntry::make('business_name')->default('-'),
                        Infolists\Components\TextEntry::make('business_type')->default('-'),
                        Infolists\Components\TextEntry::make('business_industry')->default('-'),
                        Infolists\Components\TextEntry::make('business_employee_range')
                            ->label('Employee Range')
                            ->default('-'),
                        Infolists\Components\TextEntry::make('business_website')
                            ->url(fn (?string $state): ?string => $state ? "https://{$state}" : null)
                            ->openUrlInNewTab()
                            ->default('-'),
                        Infolists\Components\TextEntry::make('business_location')
                            ->label('Location')
                            ->formatStateUsing(function (Contact $record): string {
                                $parts = array_filter([
                                    $record->business_city,
                                    $record->business_state,
                                    $record->business_country,
                                ]);
                                return implode(', ', $parts) ?: '-';
                            }),
                    ])
                    ->columns(2)
                    ->visible(fn (Contact $record): bool => $record->is_business === true),

                Infolists\Components\Section::make('Email Information')
                    ->schema([
                        Infolists\Components\TextEntry::make('email')
                            ->url(fn (?string $state): ?string => $state ? "mailto:{$state}" : null)
                            ->default('-'),
                        Infolists\Components\IconEntry::make('email_verified')
                            ->label('Verified')
                            ->boolean(),
                        Infolists\Components\TextEntry::make('first_name')->default('-'),
                        Infolists\Components\TextEntry::make('last_name')->default('-'),
                        Infolists\Components\TextEntry::make('position')->default('-'),
                    ])
                    ->columns(2)
                    ->visible(fn (Contact $record): bool => $record->email !== null),

                Infolists\Components\Section::make('Consumer Address')
                    ->schema([
                        Infolists\Components\TextEntry::make('full_address')
                            ->label('Full Address')
                            ->default('-'),
                        Infolists\Components\TextEntry::make('address_type')->default('-'),
                        Infolists\Components\IconEntry::make('address_verified')
                            ->label('Verified')
                            ->boolean(),
                    ])
                    ->columns(2)
                    ->visible(fn (Contact $record): bool =>
                        $record->is_business === false && $record->hasFullAddress()
                    ),

                Infolists\Components\Section::make('Verizon Coverage')
                    ->schema([
                        Infolists\Components\IconEntry::make('verizon_5g_home_available')
                            ->label('5G Home')
                            ->boolean(),
                        Infolists\Components\IconEntry::make('verizon_lte_home_available')
                            ->label('LTE Home')
                            ->boolean(),
                        Infolists\Components\IconEntry::make('verizon_fios_available')
                            ->label('Fios')
                            ->boolean(),
                        Infolists\Components\TextEntry::make('estimated_download_speed')
                            ->label('Est. Download Speed')
                            ->default('-'),
                    ])
                    ->columns(2)
                    ->visible(fn (Contact $record): bool =>
                        $record->verizon_5g_home_available !== null ||
                        $record->verizon_lte_home_available !== null ||
                        $record->verizon_fios_available !== null
                    ),

                Infolists\Components\Section::make('Error Details')
                    ->schema([
                        Infolists\Components\TextEntry::make('error_code')
                            ->color('danger'),
                    ])
                    ->visible(fn (Contact $record): bool => $record->error_code !== null),
            ]);
    }

    public static function getRelations(): array
    {
        return [
            //
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListContacts::route('/'),
            'create' => Pages\CreateContact::route('/create'),
            'view' => Pages\ViewContact::route('/{record}'),
            'edit' => Pages\EditContact::route('/{record}/edit'),
        ];
    }
}
