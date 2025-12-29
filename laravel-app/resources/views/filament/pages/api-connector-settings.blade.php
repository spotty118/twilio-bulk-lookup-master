<x-filament-panels::page>
    <form wire:submit.prevent="save" class="space-y-6">
        {{-- Twilio Core API --}}
        <x-filament::section>
            <x-slot name="heading">
                Twilio Core API
            </x-slot>
            <x-slot name="description">
                Configure Twilio credentials for phone lookup and verification services
            </x-slot>
            <x-slot name="headerActions">
                <a href="https://console.twilio.com" target="_blank" class="text-sm text-primary-600 hover:text-primary-800 dark:text-primary-400">
                    Get API Keys →
                </a>
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Account SID
                    </label>
                    <input
                        type="text"
                        wire:model="account_sid"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        placeholder="ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                    />
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Auth Token
                    </label>
                    <input
                        type="password"
                        wire:model="auth_token"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        placeholder="••••••••••••••••••••••••••••••••"
                    />
                </div>
            </div>
        </x-filament::section>

        {{-- Business Intelligence APIs --}}
        <x-filament::section>
            <x-slot name="heading">
                Business Intelligence APIs
            </x-slot>
            <x-slot name="description">
                APIs for business lookup and enrichment
            </x-slot>

            <div class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Clearbit API Key
                            <a href="https://clearbit.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="clearbit_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="sk_••••••••••••••••"
                        />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            NumVerify API Key
                            <a href="https://numverify.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="numverify_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="••••••••••••••••"
                        />
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Google Places API Key
                            <a href="https://console.cloud.google.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="google_places_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="AIza••••••••••••••••••••••••••"
                        />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Yelp API Key
                            <a href="https://www.yelp.com/developers" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="yelp_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="••••••••••••••••••••••••••••••••"
                        />
                    </div>
                </div>
            </div>
        </x-filament::section>

        {{-- Email Discovery APIs --}}
        <x-filament::section>
            <x-slot name="heading">
                Email Discovery & Verification APIs
            </x-slot>
            <x-slot name="description">
                APIs for finding and verifying email addresses
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Hunter.io API Key
                        <a href="https://hunter.io" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                    </label>
                    <input
                        type="password"
                        wire:model="hunter_api_key"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        placeholder="••••••••••••••••••••••••••••••••"
                    />
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        ZeroBounce API Key
                        <a href="https://www.zerobounce.net" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                    </label>
                    <input
                        type="password"
                        wire:model="zerobounce_api_key"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        placeholder="••••••••••••••••••••••••••••••••"
                    />
                </div>
            </div>
        </x-filament::section>

        {{-- Address & Location APIs --}}
        <x-filament::section>
            <x-slot name="heading">
                Address & Location APIs
            </x-slot>
            <x-slot name="description">
                APIs for address lookup and geocoding
            </x-slot>

            <div class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Whitepages API Key
                            <a href="https://pro.whitepages.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="whitepages_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="••••••••••••••••••••••••••••••••"
                        />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Google Geocoding API Key
                            <a href="https://console.cloud.google.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="google_geocoding_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="AIza••••••••••••••••••••••••••"
                        />
                    </div>
                </div>
            </div>
        </x-filament::section>

        {{-- AI/LLM APIs --}}
        <x-filament::section>
            <x-slot name="heading">
                AI & LLM APIs
            </x-slot>
            <x-slot name="description">
                Large Language Model APIs for AI-powered features
            </x-slot>

            <div class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            OpenAI API Key
                            <a href="https://platform.openai.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="openai_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="sk-••••••••••••••••••••••••••••••••"
                        />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Anthropic (Claude) API Key
                            <a href="https://console.anthropic.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="anthropic_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="sk-ant-••••••••••••••••••••••••••"
                        />
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Google AI (Gemini) API Key
                            <a href="https://makersuite.google.com" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="google_ai_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="AIza••••••••••••••••••••••••••"
                        />
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            OpenRouter API Key
                            <a href="https://openrouter.ai" target="_blank" class="text-xs text-primary-600 ml-2">Get Key</a>
                        </label>
                        <input
                            type="password"
                            wire:model="openrouter_api_key"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                            placeholder="sk-or-••••••••••••••••••••••••••"
                        />
                    </div>
                </div>
            </div>
        </x-filament::section>

        {{-- Verizon Coverage API --}}
        <x-filament::section>
            <x-slot name="heading">
                Verizon Coverage API
            </x-slot>
            <x-slot name="description">
                Check Verizon coverage availability (5G Home, LTE Home, FiOS)
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        API Key
                    </label>
                    <input
                        type="password"
                        wire:model="verizon_api_key"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        placeholder="••••••••••••••••••••••••••••••••"
                    />
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        API Secret
                    </label>
                    <input
                        type="password"
                        wire:model="verizon_api_secret"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        placeholder="••••••••••••••••••••••••••••••••"
                    />
                </div>
            </div>
        </x-filament::section>

        {{-- Usage Statistics --}}
        @if(!empty($usageStats))
            <x-filament::section>
                <x-slot name="heading">
                    API Usage Statistics (Current Month)
                </x-slot>

                <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <div class="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4">
                        <div class="text-sm text-gray-600 dark:text-gray-400">Total Requests</div>
                        <div class="text-2xl font-semibold text-gray-900 dark:text-white">{{ number_format($usageStats['total_requests'] ?? 0) }}</div>
                    </div>
                    <div class="bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
                        <div class="text-sm text-gray-600 dark:text-gray-400">Successful</div>
                        <div class="text-2xl font-semibold text-green-600 dark:text-green-400">{{ number_format($usageStats['successful_requests'] ?? 0) }}</div>
                    </div>
                    <div class="bg-red-50 dark:bg-red-900/20 rounded-lg p-4">
                        <div class="text-sm text-gray-600 dark:text-gray-400">Failed</div>
                        <div class="text-2xl font-semibold text-red-600 dark:text-red-400">{{ number_format($usageStats['failed_requests'] ?? 0) }}</div>
                    </div>
                    <div class="bg-purple-50 dark:bg-purple-900/20 rounded-lg p-4">
                        <div class="text-sm text-gray-600 dark:text-gray-400">Total Cost</div>
                        <div class="text-2xl font-semibold text-purple-600 dark:text-purple-400">${{ number_format($usageStats['total_cost'] ?? 0, 2) }}</div>
                    </div>
                </div>
            </x-filament::section>
        @endif

        {{-- Save Button --}}
        <div class="flex justify-end space-x-4">
            <x-filament::button
                type="submit"
                color="primary"
                size="lg"
            >
                Save All Settings
            </x-filament::button>
        </div>
    </form>
</x-filament-panels::page>
