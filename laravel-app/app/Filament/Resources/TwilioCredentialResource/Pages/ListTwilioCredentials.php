<?php

namespace App\Filament\Resources\TwilioCredentialResource\Pages;

use App\Filament\Resources\TwilioCredentialResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListTwilioCredentials extends ListRecords
{
    protected static string $resource = TwilioCredentialResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make()
                ->visible(fn (): bool => \App\Models\TwilioCredential::count() === 0),
        ];
    }
}
