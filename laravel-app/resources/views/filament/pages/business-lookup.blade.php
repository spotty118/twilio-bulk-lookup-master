<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Search Form --}}
        <x-filament::section>
            <x-slot name="heading">
                Search Business Directory
            </x-slot>
            <x-slot name="description">
                Search for businesses by zipcode using Yelp and Google Places APIs
            </x-slot>

            <div class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Zipcode *
                        </label>
                        <input
                            type="text"
                            wire:model="zipcode"
                            placeholder="90210"
                            maxlength="5"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        />
                        @error('zipcode')
                            <span class="text-sm text-red-600 dark:text-red-400 mt-1">{{ $message }}</span>
                        @enderror
                    </div>

                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            Results Limit *
                        </label>
                        <input
                            type="number"
                            wire:model="limit"
                            min="1"
                            max="240"
                            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 dark:bg-gray-800 dark:border-gray-600 dark:text-white"
                        />
                        @error('limit')
                            <span class="text-sm text-red-600 dark:text-red-400 mt-1">{{ $message }}</span>
                        @enderror
                    </div>

                    <div class="flex items-end">
                        <x-filament::button
                            wire:click="search"
                            :disabled="$searching"
                            color="primary"
                            class="w-full"
                            size="lg"
                        >
                            @if($searching)
                                <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                </svg>
                                Searching...
                            @else
                                Search Businesses
                            @endif
                        </x-filament::button>
                    </div>
                </div>

                <div class="text-sm text-gray-600 dark:text-gray-400">
                    <strong>Note:</strong> Yelp can return up to 240 results, Google Places up to 60 results.
                </div>
            </div>
        </x-filament::section>

        {{-- Statistics --}}
        @if($stats)
            <x-filament::section>
                <x-slot name="heading">
                    Search Statistics
                </x-slot>

                <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
                    <div class="text-center p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
                        <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">{{ $stats['found'] ?? 0 }}</div>
                        <div class="text-sm text-gray-600 dark:text-gray-400">Found</div>
                    </div>
                    <div class="text-center p-4 bg-green-50 dark:bg-green-900/20 rounded-lg">
                        <div class="text-2xl font-bold text-green-600 dark:text-green-400">{{ $stats['imported'] ?? 0 }}</div>
                        <div class="text-sm text-gray-600 dark:text-gray-400">Imported</div>
                    </div>
                    <div class="text-center p-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg">
                        <div class="text-2xl font-bold text-yellow-600 dark:text-yellow-400">{{ $stats['updated'] ?? 0 }}</div>
                        <div class="text-sm text-gray-600 dark:text-gray-400">Updated</div>
                    </div>
                    <div class="text-center p-4 bg-gray-50 dark:bg-gray-900/20 rounded-lg">
                        <div class="text-2xl font-bold text-gray-600 dark:text-gray-400">{{ $stats['skipped'] ?? 0 }}</div>
                        <div class="text-sm text-gray-600 dark:text-gray-400">Skipped</div>
                    </div>
                    <div class="text-center p-4 bg-purple-50 dark:bg-purple-900/20 rounded-lg">
                        <div class="text-2xl font-bold text-purple-600 dark:text-purple-400">{{ $stats['duplicates_prevented'] ?? 0 }}</div>
                        <div class="text-sm text-gray-600 dark:text-gray-400">Duplicates</div>
                    </div>
                </div>
            </x-filament::section>
        @endif

        {{-- Results Table --}}
        @if(!empty($results))
            <x-filament::section>
                <x-slot name="heading">
                    Search Results ({{ count($results) }})
                </x-slot>

                <x-slot name="headerActions">
                    <x-filament::button
                        wire:click="clearResults"
                        color="gray"
                        size="sm"
                    >
                        Clear Results
                    </x-filament::button>
                </x-slot>

                <div class="overflow-x-auto">
                    <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                        <thead class="bg-gray-50 dark:bg-gray-800">
                            <tr>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">ID</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Business Name</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Phone</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Address</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Type</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Source</th>
                                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Actions</th>
                            </tr>
                        </thead>
                        <tbody class="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                            @foreach($results as $result)
                                <tr class="hover:bg-gray-50 dark:hover:bg-gray-800">
                                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                        {{ $result['id'] }}
                                    </td>
                                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                                        {{ $result['name'] ?? 'N/A' }}
                                    </td>
                                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                        {{ $result['phone'] ?? 'N/A' }}
                                    </td>
                                    <td class="px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                                        {{ \Str::limit($result['address'] ?? 'N/A', 40) }}
                                    </td>
                                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                        {{ $result['type'] ?? 'N/A' }}
                                    </td>
                                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                        <span class="px-2 py-1 text-xs font-semibold rounded-full
                                            @if($result['source'] === 'yelp') bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100
                                            @elseif($result['source'] === 'google_places') bg-blue-100 text-blue-800 dark:bg-blue-800 dark:text-blue-100
                                            @else bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-100
                                            @endif">
                                            {{ ucfirst($result['source']) }}
                                        </span>
                                    </td>
                                    <td class="px-6 py-4 whitespace-nowrap text-sm">
                                        <a href="{{ route('filament.admin.resources.contacts.view', ['record' => $result['id']]) }}"
                                           class="text-primary-600 hover:text-primary-900 dark:text-primary-400 dark:hover:text-primary-300">
                                            View
                                        </a>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            </x-filament::section>
        @elseif(!$searching && $stats === null)
            <x-filament::section>
                <div class="text-center py-12">
                    <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                    </svg>
                    <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-white">No search performed</h3>
                    <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Enter a zipcode and click search to find businesses.</p>
                </div>
            </x-filament::section>
        @endif
    </div>
</x-filament-panels::page>
