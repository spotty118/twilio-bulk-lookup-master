<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;
use Filament\Notifications\Notification;
use App\Services\DuplicateDetectionService;
use App\Models\Contact;
use Illuminate\Support\Facades\DB;
use Livewire\WithPagination;

class DuplicatesManager extends Page
{
    use WithPagination;

    protected static ?string $navigationIcon = 'heroicon-o-document-duplicate';
    protected static string $view = 'filament.pages.duplicates-manager';
    protected static ?string $navigationLabel = 'Duplicates Manager';
    protected static ?string $navigationGroup = 'Tools';
    protected static ?int $navigationSort = 4;

    public $duplicates = [];
    public $comparing = null;
    public $comparisonData = null;
    public $selectedDuplicate = null;
    public $searchTerm = '';
    public $minConfidence = 80;
    public $loading = false;

    public function mount(): void
    {
        $this->loadDuplicates();
    }

    protected function loadDuplicates(): void
    {
        $this->loading = true;

        try {
            // Find contacts with potential duplicates
            $this->duplicates = Contact::where('duplicate_of_id', null)
                ->where(function ($query) {
                    $query->whereNotNull('phone_fingerprint')
                        ->orWhereNotNull('email_fingerprint')
                        ->orWhereNotNull('name_fingerprint');
                })
                ->take(50)
                ->get()
                ->map(function ($contact) {
                    $duplicateCandidates = DuplicateDetectionService::findDuplicates($contact);

                    if (empty($duplicateCandidates)) {
                        return null;
                    }

                    return [
                        'contact' => $contact,
                        'duplicates' => $duplicateCandidates,
                        'highest_confidence' => max(array_column($duplicateCandidates, 'confidence')),
                    ];
                })
                ->filter()
                ->sortByDesc('highest_confidence')
                ->values()
                ->toArray();
        } finally {
            $this->loading = false;
        }
    }

    public function compare(int $contactId, int $duplicateId): void
    {
        $primary = Contact::find($contactId);
        $duplicate = Contact::find($duplicateId);

        if (!$primary || !$duplicate) {
            Notification::make()
                ->title('Contacts not found')
                ->danger()
                ->send();
            return;
        }

        $this->comparing = [
            'primary_id' => $contactId,
            'duplicate_id' => $duplicateId,
        ];

        $this->comparisonData = [
            'primary' => [
                'id' => $primary->id,
                'phone' => $primary->formatted_phone_number ?? $primary->raw_phone_number,
                'name' => $primary->business_name ?? ($primary->first_name . ' ' . $primary->last_name),
                'email' => $primary->email,
                'address' => $primary->business_address ?? $primary->consumer_address,
                'type' => $primary->is_business ? 'Business' : 'Consumer',
                'created_at' => $primary->created_at->format('Y-m-d H:i:s'),
            ],
            'duplicate' => [
                'id' => $duplicate->id,
                'phone' => $duplicate->formatted_phone_number ?? $duplicate->raw_phone_number,
                'name' => $duplicate->business_name ?? ($duplicate->first_name . ' ' . $duplicate->last_name),
                'email' => $duplicate->email,
                'address' => $duplicate->business_address ?? $duplicate->consumer_address,
                'type' => $duplicate->is_business ? 'Business' : 'Consumer',
                'created_at' => $duplicate->created_at->format('Y-m-d H:i:s'),
            ],
        ];
    }

    public function closeComparison(): void
    {
        $this->comparing = null;
        $this->comparisonData = null;
    }

    public function mergeDuplicates(int $primaryId, int $duplicateId): void
    {
        $primary = Contact::find($primaryId);
        $duplicate = Contact::find($duplicateId);

        if (!$primary || !$duplicate) {
            Notification::make()
                ->title('Merge failed')
                ->danger()
                ->body('One or both contacts not found.')
                ->send();
            return;
        }

        try {
            $success = DuplicateDetectionService::merge($primary, $duplicate);

            if ($success) {
                Notification::make()
                    ->title('Merge successful')
                    ->success()
                    ->body("Contact #{$duplicateId} has been merged into #{$primaryId}.")
                    ->send();

                $this->closeComparison();
                $this->loadDuplicates();
            } else {
                Notification::make()
                    ->title('Merge failed')
                    ->danger()
                    ->body('Failed to merge contacts.')
                    ->send();
            }
        } catch (\Exception $e) {
            Notification::make()
                ->title('Merge failed')
                ->danger()
                ->body($e->getMessage())
                ->send();
        }
    }

    public function ignoreDuplicate(int $contactId, int $duplicateId): void
    {
        try {
            $duplicate = Contact::find($duplicateId);
            if ($duplicate) {
                $duplicate->update([
                    'duplicate_checked_at' => now(),
                    'duplicate_confidence' => 0, // Mark as checked and ignored
                ]);

                Notification::make()
                    ->title('Duplicate ignored')
                    ->success()
                    ->body('This duplicate has been marked as ignored.')
                    ->send();

                $this->closeComparison();
                $this->loadDuplicates();
            }
        } catch (\Exception $e) {
            Notification::make()
                ->title('Operation failed')
                ->danger()
                ->body($e->getMessage())
                ->send();
        }
    }

    public function refreshDuplicates(): void
    {
        $this->loadDuplicates();

        Notification::make()
            ->title('Duplicates refreshed')
            ->success()
            ->send();
    }
}
