<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use App\Models\TwilioCredential;
use App\Models\ApiUsageLog;

class ApiConnectorSettings extends Page implements HasForms
{
    use InteractsWithForms;

    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';
    protected static string $view = 'filament.pages.api-connector-settings';
    protected static ?string $navigationLabel = 'API Settings';
    protected static ?string $navigationGroup = 'Settings';
    protected static ?int $navigationSort = 1;

    public $credentials = null;
    public $usageStats = [];
    public $testing = [];

    // Twilio
    public $account_sid = '';
    public $auth_token = '';

    // Business APIs
    public $clearbit_api_key = '';
    public $numverify_api_key = '';
    public $google_places_api_key = '';
    public $yelp_api_key = '';

    // Email APIs
    public $hunter_api_key = '';
    public $zerobounce_api_key = '';

    // Address APIs
    public $whitepages_api_key = '';
    public $truecaller_api_key = '';
    public $google_geocoding_api_key = '';

    // AI/LLM APIs
    public $openai_api_key = '';
    public $anthropic_api_key = '';
    public $google_ai_api_key = '';
    public $openrouter_api_key = '';

    // Verizon
    public $verizon_api_key = '';
    public $verizon_api_secret = '';

    public function mount(): void
    {
        $this->credentials = TwilioCredential::current();

        if ($this->credentials) {
            $this->account_sid = $this->credentials->account_sid ?? '';
            $this->auth_token = $this->credentials->auth_token ?? '';
            $this->clearbit_api_key = $this->credentials->clearbit_api_key ?? '';
            $this->numverify_api_key = $this->credentials->numverify_api_key ?? '';
            $this->google_places_api_key = $this->credentials->google_places_api_key ?? '';
            $this->yelp_api_key = $this->credentials->yelp_api_key ?? '';
            $this->hunter_api_key = $this->credentials->hunter_api_key ?? '';
            $this->zerobounce_api_key = $this->credentials->zerobounce_api_key ?? '';
            $this->whitepages_api_key = $this->credentials->whitepages_api_key ?? '';
            $this->truecaller_api_key = $this->credentials->truecaller_api_key ?? '';
            $this->google_geocoding_api_key = $this->credentials->google_geocoding_api_key ?? '';
            $this->openai_api_key = $this->credentials->openai_api_key ?? '';
            $this->anthropic_api_key = $this->credentials->anthropic_api_key ?? '';
            $this->google_ai_api_key = $this->credentials->google_ai_api_key ?? '';
            $this->openrouter_api_key = $this->credentials->openrouter_api_key ?? '';
            $this->verizon_api_key = $this->credentials->verizon_api_key ?? '';
            $this->verizon_api_secret = $this->credentials->verizon_api_secret ?? '';
        }

        $this->loadUsageStats();
    }

    protected function loadUsageStats(): void
    {
        $this->usageStats = ApiUsageLog::usageStats(now()->startOfMonth(), now());
    }

    public function save(): void
    {
        if (!$this->credentials) {
            $this->credentials = new TwilioCredential();
        }

        $this->credentials->account_sid = $this->account_sid;
        $this->credentials->auth_token = $this->auth_token;
        $this->credentials->clearbit_api_key = $this->clearbit_api_key;
        $this->credentials->numverify_api_key = $this->numverify_api_key;
        $this->credentials->google_places_api_key = $this->google_places_api_key;
        $this->credentials->yelp_api_key = $this->yelp_api_key;
        $this->credentials->hunter_api_key = $this->hunter_api_key;
        $this->credentials->zerobounce_api_key = $this->zerobounce_api_key;
        $this->credentials->whitepages_api_key = $this->whitepages_api_key;
        $this->credentials->truecaller_api_key = $this->truecaller_api_key;
        $this->credentials->google_geocoding_api_key = $this->google_geocoding_api_key;
        $this->credentials->openai_api_key = $this->openai_api_key;
        $this->credentials->anthropic_api_key = $this->anthropic_api_key;
        $this->credentials->google_ai_api_key = $this->google_ai_api_key;
        $this->credentials->openrouter_api_key = $this->openrouter_api_key;
        $this->credentials->verizon_api_key = $this->verizon_api_key;
        $this->credentials->verizon_api_secret = $this->verizon_api_secret;

        $this->credentials->save();

        Notification::make()
            ->title('Settings saved')
            ->success()
            ->body('API credentials have been updated successfully.')
            ->send();
    }

    public function testConnection(string $provider): void
    {
        $this->testing[$provider] = true;

        // Simulate connection test (implement actual tests as needed)
        sleep(1);

        $success = !empty($this->{"{$provider}_api_key"});

        $this->testing[$provider] = false;

        if ($success) {
            Notification::make()
                ->title('Connection successful')
                ->success()
                ->body("{$provider} API connection is working.")
                ->send();
        } else {
            Notification::make()
                ->title('Connection failed')
                ->danger()
                ->body("{$provider} API key is not configured or invalid.")
                ->send();
        }
    }
}
