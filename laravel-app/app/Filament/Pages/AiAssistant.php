<?php

namespace App\Filament\Pages;

use Filament\Pages\Page;
use Filament\Notifications\Notification;
use App\Services\AiAssistantService;
use App\Models\TwilioCredential;

class AiAssistant extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-sparkles';
    protected static string $view = 'filament.pages.ai-assistant';
    protected static ?string $navigationLabel = 'AI Assistant';
    protected static ?string $navigationGroup = 'Tools';
    protected static ?int $navigationSort = 3;

    public $query = '';
    public $response = '';
    public $loading = false;
    public $llmProvider = 'openai';
    public $queryHistory = [];
    public $exampleQueries = [
        'Find all mobile contacts in California',
        'List businesses with high SMS pumping risk',
        'Show contacts that haven\'t been verified yet',
        'Which contacts have Verizon coverage available?',
        'Find duplicates with confidence score above 90%',
    ];

    public function mount(): void
    {
        $this->loadQueryHistory();
        $this->loadDefaultProvider();
    }

    protected function loadDefaultProvider(): void
    {
        $credentials = TwilioCredential::current();
        $this->llmProvider = $credentials?->preferred_llm_provider ?? 'openai';
    }

    protected function loadQueryHistory(): void
    {
        // Load recent queries from session or database
        $this->queryHistory = session('ai_query_history', []);
    }

    public function submitQuery(): void
    {
        if (empty(trim($this->query))) {
            Notification::make()
                ->title('Empty query')
                ->warning()
                ->body('Please enter a question or request.')
                ->send();
            return;
        }

        $this->loading = true;
        $this->response = '';

        try {
            $result = AiAssistantService::query($this->query);

            if (is_array($result) && isset($result['error'])) {
                $this->response = "Error: " . $result['error'];
                Notification::make()
                    ->title('Query failed')
                    ->danger()
                    ->body($result['error'])
                    ->send();
            } else {
                $this->response = is_string($result) ? $result : json_encode($result, JSON_PRETTY_PRINT);

                // Add to history
                $this->addToHistory($this->query, $this->response);

                Notification::make()
                    ->title('Query completed')
                    ->success()
                    ->send();
            }
        } catch (\Exception $e) {
            $this->response = "Error: " . $e->getMessage();
            Notification::make()
                ->title('Query failed')
                ->danger()
                ->body($e->getMessage())
                ->send();
        } finally {
            $this->loading = false;
        }
    }

    public function useExampleQuery(string $query): void
    {
        $this->query = $query;
    }

    public function clearChat(): void
    {
        $this->query = '';
        $this->response = '';
        $this->queryHistory = [];
        session()->forget('ai_query_history');

        Notification::make()
            ->title('Chat cleared')
            ->success()
            ->send();
    }

    public function exportResponse(): void
    {
        if (empty($this->response)) {
            Notification::make()
                ->title('Nothing to export')
                ->warning()
                ->body('No response available to export.')
                ->send();
            return;
        }

        $filename = 'ai-response-' . date('Y-m-d-His') . '.txt';
        $content = "Query: {$this->query}\n\n";
        $content .= "Response:\n{$this->response}\n";

        // Create temporary file for download
        $path = storage_path('app/' . $filename);
        file_put_contents($path, $content);

        Notification::make()
            ->title('Response exported')
            ->success()
            ->body("Response saved to {$filename}")
            ->send();

        return response()->download($path)->deleteFileAfterSend(true);
    }

    protected function addToHistory(string $query, string $response): void
    {
        $historyItem = [
            'query' => $query,
            'response' => $response,
            'timestamp' => now()->toDateTimeString(),
            'provider' => $this->llmProvider,
        ];

        array_unshift($this->queryHistory, $historyItem);
        $this->queryHistory = array_slice($this->queryHistory, 0, 20); // Keep last 20

        session(['ai_query_history' => $this->queryHistory]);
    }
}
