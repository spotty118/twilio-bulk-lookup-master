<?php

namespace App\Filament\Resources\ZipcodeLookupResource\Pages;

use App\Filament\Resources\ZipcodeLookupResource;
use Filament\Resources\Pages\CreateRecord;
use Filament\Notifications\Notification;

class CreateZipcodeLookup extends CreateRecord
{
    protected static string $resource = ZipcodeLookupResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['status'] = 'pending';
        return $data;
    }

    protected function afterCreate(): void
    {
        // Queue job here
        // BusinessLookupJob::dispatch($this->record->id);

        Notification::make()
            ->title('Zipcode lookup created')
            ->body('Lookup queued for processing')
            ->success()
            ->send();
    }
}
