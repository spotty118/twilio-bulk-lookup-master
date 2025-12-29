<?php

namespace App\Filament\Resources\TwilioCredentialResource\Pages;

use App\Filament\Resources\TwilioCredentialResource;
use Filament\Actions;
use Filament\Resources\Pages\ViewRecord;

class ViewTwilioCredential extends ViewRecord
{
    protected static string $resource = TwilioCredentialResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\EditAction::make(),
        ];
    }
}
