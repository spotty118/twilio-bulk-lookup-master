<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Header --}}
        <div class="flex justify-between items-center">
            <div>
                <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Duplicate Contacts</h2>
                <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                    Review and merge duplicate contacts based on phone numbers, emails, and business names
                </p>
            </div>
            <x-filament::button
                wire:click="refreshDuplicates"
                :disabled="$loading"
                icon="heroicon-o-arrow-path"
                color="gray"
            >
                Refresh
            </x-filament::button>
        </div>

        {{-- Search and Filters --}}
        <x-filament::section>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="md:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Search
                    </label>
                    <input
                        type="text"
                        wire:model.live="searchTerm"
                        placeholder="Search by name, phone, or email..."
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                    />
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Min Confidence Score
                    </label>
                    <input
                        type="number"
                        wire:model.live="minConfidence"
                        min="0"
                        max="100"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                    />
                </div>
            </div>
        </x-filament::section>

        {{-- Comparison Modal --}}
        @if($comparing && $comparisonData)
            <x-filament::section>
                <x-slot name="heading">
                    Side-by-Side Comparison
                </x-slot>
                <x-slot name="headerActions">
                    <x-filament::button
                        wire:click="closeComparison"
                        size="sm"
                        color="gray"
                    >
                        Close
                    </x-filament::button>
                </x-slot>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {{-- Primary Contact --}}
                    <div class="border-2 border-green-500 dark:border-green-600 rounded-lg p-6">
                        <div class="flex items-center justify-between mb-4">
                            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Primary Contact</h3>
                            <span class="px-3 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100">
                                Keep This
                            </span>
                        </div>
                        <dl class="space-y-3">
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">ID</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">#{{ $comparisonData['primary']['id'] }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Name</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['primary']['name'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Phone</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['primary']['phone'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Email</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['primary']['email'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Address</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['primary']['address'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Type</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['primary']['type'] }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Created At</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['primary']['created_at'] }}</dd>
                            </div>
                        </dl>
                    </div>

                    {{-- Duplicate Contact --}}
                    <div class="border-2 border-red-500 dark:border-red-600 rounded-lg p-6">
                        <div class="flex items-center justify-between mb-4">
                            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Duplicate Contact</h3>
                            <span class="px-3 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100">
                                Will Be Merged
                            </span>
                        </div>
                        <dl class="space-y-3">
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">ID</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">#{{ $comparisonData['duplicate']['id'] }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Name</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['duplicate']['name'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Phone</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['duplicate']['phone'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Email</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['duplicate']['email'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Address</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['duplicate']['address'] ?: 'N/A' }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Type</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['duplicate']['type'] }}</dd>
                            </div>
                            <div>
                                <dt class="text-xs font-medium text-gray-500 dark:text-gray-400">Created At</dt>
                                <dd class="text-sm text-gray-900 dark:text-white">{{ $comparisonData['duplicate']['created_at'] }}</dd>
                            </div>
                        </dl>
                    </div>
                </div>

                {{-- Merge Actions --}}
                <div class="mt-6 flex justify-center space-x-4">
                    <x-filament::button
                        wire:click="mergeDuplicates({{ $comparing['primary_id'] }}, {{ $comparing['duplicate_id'] }})"
                        color="success"
                        size="lg"
                        wire:confirm="Are you sure you want to merge these contacts? This action cannot be undone."
                    >
                        Merge Contacts
                    </x-filament::button>
                    <x-filament::button
                        wire:click="ignoreDuplicate({{ $comparing['primary_id'] }}, {{ $comparing['duplicate_id'] }})"
                        color="warning"
                        size="lg"
                    >
                        Not a Duplicate
                    </x-filament::button>
                </div>
            </x-filament::section>
        @endif

        {{-- Duplicates List --}}
        @if($loading)
            <x-filament::section>
                <div class="text-center py-12">
                    <svg class="animate-spin h-12 w-12 text-primary-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                    </svg>
                    <p class="mt-4 text-sm text-gray-600 dark:text-gray-400">Scanning for duplicates...</p>
                </div>
            </x-filament::section>
        @elseif(empty($duplicates))
            <x-filament::section>
                <div class="text-center py-12">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-white">No duplicates found</h3>
                    <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Your contact database is clean!</p>
                </div>
            </x-filament::section>
        @else
            <x-filament::section>
                <x-slot name="heading">
                    Potential Duplicates ({{ count($duplicates) }})
                </x-slot>

                <div class="space-y-4">
                    @foreach($duplicates as $item)
                        <div class="border dark:border-gray-700 rounded-lg p-6">
                            <div class="flex items-start justify-between mb-4">
                                <div class="flex-1">
                                    <h4 class="text-lg font-semibold text-gray-900 dark:text-white">
                                        {{ $item['contact']->business_name ?? ($item['contact']->first_name . ' ' . $item['contact']->last_name) ?: 'Unnamed Contact' }}
                                    </h4>
                                    <p class="text-sm text-gray-600 dark:text-gray-400">
                                        ID: #{{ $item['contact']->id }} • {{ $item['contact']->formatted_phone_number ?? $item['contact']->raw_phone_number }}
                                    </p>
                                </div>
                                <span class="px-3 py-1 text-xs font-semibold rounded-full
                                    @if($item['highest_confidence'] >= 90) bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100
                                    @elseif($item['highest_confidence'] >= 80) bg-yellow-100 text-yellow-800 dark:bg-yellow-800 dark:text-yellow-100
                                    @else bg-blue-100 text-blue-800 dark:bg-blue-800 dark:text-blue-100
                                    @endif">
                                    {{ $item['highest_confidence'] }}% Match
                                </span>
                            </div>

                            <div class="space-y-3">
                                @foreach($item['duplicates'] as $duplicate)
                                    <div class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
                                        <div class="flex-1">
                                            <div class="text-sm font-medium text-gray-900 dark:text-white">
                                                {{ $duplicate['contact']->business_name ?? ($duplicate['contact']->first_name . ' ' . $duplicate['contact']->last_name) ?: 'Unnamed Contact' }}
                                            </div>
                                            <div class="text-xs text-gray-600 dark:text-gray-400 mt-1">
                                                ID: #{{ $duplicate['contact']->id }} • {{ $duplicate['reason'] }}
                                            </div>
                                        </div>
                                        <div class="flex items-center space-x-2">
                                            <span class="text-sm font-semibold text-gray-900 dark:text-white">{{ $duplicate['confidence'] }}%</span>
                                            <x-filament::button
                                                wire:click="compare({{ $item['contact']->id }}, {{ $duplicate['contact']->id }})"
                                                size="xs"
                                                color="primary"
                                            >
                                                Compare
                                            </x-filament::button>
                                        </div>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    @endforeach
                </div>
            </x-filament::section>
        @endif

        {{-- Info Section --}}
        <x-filament::section>
            <x-slot name="heading">
                How Duplicate Detection Works
            </x-slot>

            <div class="prose dark:prose-invert max-w-none">
                <p class="text-sm text-gray-600 dark:text-gray-400">
                    Our duplicate detection system uses multiple matching algorithms to identify potential duplicates:
                </p>
                <ul class="text-sm text-gray-600 dark:text-gray-400 space-y-2 mt-4">
                    <li><strong>Phone Number Matching (40 points):</strong> Exact and fuzzy matching on normalized phone numbers</li>
                    <li><strong>Email Matching (30 points):</strong> Exact email match and domain similarity</li>
                    <li><strong>Name Matching (20 points):</strong> Business name or full name similarity using Levenshtein distance</li>
                    <li><strong>Location Matching (10 points):</strong> City and address similarity for businesses</li>
                </ul>
                <div class="mt-4 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
                    <p class="text-sm text-gray-900 dark:text-white font-semibold mb-2">Confidence Scores:</p>
                    <ul class="text-sm text-gray-600 dark:text-gray-400 space-y-1">
                        <li>90-100%: Very likely duplicate (exact matches on multiple fields)</li>
                        <li>80-89%: Probable duplicate (strong similarity)</li>
                        <li>Below 80%: Possible duplicate (review carefully)</li>
                    </ul>
                </div>
            </div>
        </x-filament::section>
    </div>
</x-filament-panels::page>
