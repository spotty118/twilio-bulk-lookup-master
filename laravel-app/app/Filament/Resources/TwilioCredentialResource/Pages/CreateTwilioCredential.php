<?php

namespace App\Filament\Resources\TwilioCredentialResource\Pages;

use App\Filament\Resources\TwilioCredentialResource;
use Filament\Resources\Pages\CreateRecord;

class CreateTwilioCredential extends CreateRecord
{
    protected static string $resource = TwilioCredentialResource::class;

    protected function beforeCreate(): void
    {
        // Enforce singleton pattern
        if (\App\Models\TwilioCredential::count() > 0) {
            $this->halt();
            redirect()->to(TwilioCredentialResource::getUrl('edit', ['record' => \App\Models\TwilioCredential::first()]));
        }
    }
}
