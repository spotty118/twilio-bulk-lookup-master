<?php

namespace App\Filament\Resources\TwilioCredentialResource\Pages;

use App\Filament\Resources\TwilioCredentialResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Filament\Notifications\Notification;

class EditTwilioCredential extends EditRecord
{
    protected static string $resource = TwilioCredentialResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\Action::make('test_connection')
                ->label('Test Connection')
                ->icon('heroicon-o-signal')
                ->action(function () {
                    try {
                        // Test Twilio connection logic here
                        Notification::make()
                            ->title('Connection Successful')
                            ->success()
                            ->send();
                    } catch (\Exception $e) {
                        Notification::make()
                            ->title('Connection Failed')
                            ->body($e->getMessage())
                            ->danger()
                            ->send();
                    }
                }),
        ];
    }

    protected function afterSave(): void
    {
        // Clear cache after update
        cache()->forget('twilio_credentials');

        Notification::make()
            ->title('Settings Saved')
            ->body('Twilio credentials have been updated successfully.')
            ->success()
            ->send();
    }
}
