<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Header Info --}}
        <x-filament::section>
            <div class="flex items-start space-x-4">
                <div class="flex-shrink-0">
                    <svg class="h-12 w-12 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                    </svg>
                </div>
                <div class="flex-1">
                    <h3 class="text-lg font-semibold text-gray-900 dark:text-white">AI-Powered Contact Intelligence</h3>
                    <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                        Ask questions about your contacts in natural language. The AI assistant can help you search, analyze, and gain insights from your contact database.
                    </p>
                </div>
            </div>
        </x-filament::section>

        {{-- Chat Interface --}}
        <x-filament::section>
            <x-slot name="heading">
                AI Chat
            </x-slot>
            <x-slot name="headerActions">
                <div class="flex items-center space-x-2">
                    <select wire:model="llmProvider" class="text-sm rounded-md border-gray-300 dark:bg-gray-800 dark:border-gray-600 dark:text-white">
                        <option value="openai">OpenAI (GPT-4)</option>
                        <option value="anthropic">Anthropic (Claude)</option>
                        <option value="google">Google (Gemini)</option>
                        <option value="openrouter">OpenRouter</option>
                    </select>
                    <x-filament::button
                        wire:click="clearChat"
                        size="sm"
                        color="gray"
                    >
                        Clear Chat
                    </x-filament::button>
                </div>
            </x-slot>

            <div class="space-y-4">
                {{-- Query Input --}}
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Your Question
                    </label>
                    <textarea
                        wire:model="query"
                        rows="3"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        placeholder="Ask me anything about your contacts..."
                        @keydown.ctrl.enter="$wire.submitQuery()"
                    ></textarea>
                    <div class="mt-2 text-xs text-gray-500 dark:text-gray-400">
                        Press Ctrl+Enter to submit
                    </div>
                </div>

                {{-- Submit Button --}}
                <div class="flex justify-end">
                    <x-filament::button
                        wire:click="submitQuery"
                        :disabled="$loading"
                        color="primary"
                        size="lg"
                    >
                        @if($loading)
                            <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                            </svg>
                            Processing...
                        @else
                            Submit Query
                        @endif
                    </x-filament::button>
                </div>

                {{-- Response --}}
                @if(!empty($response))
                    <div class="mt-6 bg-gray-50 dark:bg-gray-800 rounded-lg p-6">
                        <div class="flex justify-between items-start mb-4">
                            <h4 class="text-sm font-semibold text-gray-900 dark:text-white">AI Response</h4>
                            <x-filament::button
                                wire:click="exportResponse"
                                size="xs"
                                color="gray"
                            >
                                Export
                            </x-filament::button>
                        </div>
                        <div class="prose dark:prose-invert max-w-none">
                            <div class="text-sm text-gray-700 dark:text-gray-300 whitespace-pre-wrap">{{ $response }}</div>
                        </div>
                    </div>
                @endif
            </div>
        </x-filament::section>

        {{-- Example Queries --}}
        <x-filament::section>
            <x-slot name="heading">
                Example Queries
            </x-slot>
            <x-slot name="description">
                Click any example to try it out
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                @foreach($exampleQueries as $example)
                    <button
                        wire:click="useExampleQuery('{{ $example }}')"
                        class="text-left p-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg hover:border-primary-500 dark:hover:border-primary-500 transition-colors"
                    >
                        <div class="flex items-start space-x-3">
                            <svg class="h-5 w-5 text-primary-600 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                            </svg>
                            <span class="text-sm text-gray-700 dark:text-gray-300">{{ $example }}</span>
                        </div>
                    </button>
                @endforeach
            </div>
        </x-filament::section>

        {{-- Query History --}}
        @if(!empty($queryHistory))
            <x-filament::section>
                <x-slot name="heading">
                    Recent Queries
                </x-slot>

                <div class="space-y-4">
                    @foreach(array_slice($queryHistory, 0, 5) as $item)
                        <div class="border dark:border-gray-700 rounded-lg p-4">
                            <div class="flex items-start justify-between mb-2">
                                <div class="flex-1">
                                    <div class="text-sm font-medium text-gray-900 dark:text-white">{{ $item['query'] }}</div>
                                    <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
                                        {{ $item['timestamp'] }} • {{ ucfirst($item['provider']) }}
                                    </div>
                                </div>
                                <button
                                    wire:click="useExampleQuery('{{ $item['query'] }}')"
                                    class="text-primary-600 hover:text-primary-800 dark:text-primary-400 text-xs"
                                >
                                    Use again
                                </button>
                            </div>
                            <div class="mt-3 p-3 bg-gray-50 dark:bg-gray-800 rounded text-xs text-gray-600 dark:text-gray-400">
                                {{ \Str::limit($item['response'], 200) }}
                            </div>
                        </div>
                    @endforeach
                </div>
            </x-filament::section>
        @endif

        {{-- Capabilities Info --}}
        <x-filament::section>
            <x-slot name="heading">
                AI Assistant Capabilities
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="text-center">
                    <div class="inline-flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 mb-4">
                        <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                        </svg>
                    </div>
                    <h4 class="text-sm font-semibold text-gray-900 dark:text-white mb-2">Natural Language Search</h4>
                    <p class="text-xs text-gray-600 dark:text-gray-400">
                        Search your contacts using plain English. No need to learn complex query syntax.
                    </p>
                </div>

                <div class="text-center">
                    <div class="inline-flex items-center justify-center h-12 w-12 rounded-full bg-green-100 dark:bg-green-900/20 text-green-600 dark:text-green-400 mb-4">
                        <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                        </svg>
                    </div>
                    <h4 class="text-sm font-semibold text-gray-900 dark:text-white mb-2">Data Analysis</h4>
                    <p class="text-xs text-gray-600 dark:text-gray-400">
                        Get insights and trends from your contact data with AI-powered analysis.
                    </p>
                </div>

                <div class="text-center">
                    <div class="inline-flex items-center justify-center h-12 w-12 rounded-full bg-purple-100 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400 mb-4">
                        <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"/>
                        </svg>
                    </div>
                    <h4 class="text-sm font-semibold text-gray-900 dark:text-white mb-2">Sales Intelligence</h4>
                    <p class="text-xs text-gray-600 dark:text-gray-400">
                        Generate personalized outreach messages and sales talking points.
                    </p>
                </div>
            </div>
        </x-filament::section>
    </div>
</x-filament-panels::page>
