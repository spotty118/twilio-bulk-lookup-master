<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditUser extends EditRecord
{
    protected static string $resource = UserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\ViewAction::make(),
            Actions\DeleteAction::make()
                ->before(function () {
                    // Prevent deleting your own account
                    if ($this->record->id === auth()->id()) {
                        throw new \Exception('You cannot delete your own account!');
                    }

                    // Prevent deleting last admin
                    if (\App\Models\User::count() <= 1) {
                        throw new \Exception('Cannot delete the last admin user!');
                    }
                }),
        ];
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        // Only hash password if it's been changed
        if (isset($data['password']) && filled($data['password'])) {
            $data['password'] = bcrypt($data['password']);
        } else {
            unset($data['password']);
        }

        return $data;
    }
}
