<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use App\Services\BusinessLookupService;
use App\Models\Contact;
use Livewire\WithPagination;

class BusinessLookup extends Page implements HasForms
{
    use InteractsWithForms;
    use WithPagination;

    protected static ?string $navigationIcon = 'heroicon-o-magnifying-glass';
    protected static string $view = 'filament.pages.business-lookup';
    protected static ?string $navigationLabel = 'Business Lookup';
    protected static ?string $navigationGroup = 'Tools';
    protected static ?int $navigationSort = 1;

    public $location = '';
    public $zipcode = '';
    public $businessType = '';
    public $radius = 5;
    public $limit = 20;
    public $results = [];
    public $searching = false;
    public $stats = null;
    public $selectedResults = [];

    protected function getFormSchema(): array
    {
        return [];
    }

    public function search(): void
    {
        $this->validate([
            'zipcode' => 'required|digits:5',
            'limit' => 'required|integer|min:1|max:240',
        ]);

        $this->searching = true;
        $this->results = [];
        $this->stats = null;

        try {
            $service = new BusinessLookupService($this->zipcode);
            $this->stats = $service->lookupBusinesses($this->limit);

            // Load the newly imported contacts
            $this->results = Contact::where('business_postal_code', $this->zipcode)
                ->latest()
                ->take($this->limit)
                ->get()
                ->map(function ($contact) {
                    return [
                        'id' => $contact->id,
                        'name' => $contact->business_name,
                        'phone' => $contact->raw_phone_number,
                        'address' => $contact->business_address,
                        'type' => $contact->business_type,
                        'website' => $contact->business_website,
                        'source' => $contact->business_enrichment_provider ?? 'unknown',
                    ];
                })
                ->toArray();

            Notification::make()
                ->title('Search completed')
                ->success()
                ->body("Found {$this->stats['found']} businesses. Imported {$this->stats['imported']}, Updated {$this->stats['updated']}, Skipped {$this->stats['skipped']}.")
                ->send();
        } catch (\Exception $e) {
            Notification::make()
                ->title('Search failed')
                ->danger()
                ->body($e->getMessage())
                ->send();
        } finally {
            $this->searching = false;
        }
    }

    public function importSelected(): void
    {
        if (empty($this->selectedResults)) {
            Notification::make()
                ->title('No results selected')
                ->warning()
                ->body('Please select at least one result to import.')
                ->send();
            return;
        }

        $count = count($this->selectedResults);

        Notification::make()
            ->title('Import successful')
            ->success()
            ->body("Imported {$count} businesses to contacts.")
            ->send();

        $this->selectedResults = [];
    }

    public function clearResults(): void
    {
        $this->results = [];
        $this->stats = null;
        $this->selectedResults = [];
        $this->zipcode = '';
        $this->limit = 20;

        Notification::make()
            ->title('Results cleared')
            ->success()
            ->send();
    }
}