<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Header Actions --}}
        <div class="flex justify-between items-center">
            <div>
                <h2 class="text-2xl font-bold text-gray-900 dark:text-white">Circuit Breaker Management</h2>
                <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                    Monitor and control circuit breakers for all external API services
                </p>
            </div>
            <div class="flex space-x-2">
                <x-filament::button
                    wire:click="refreshData"
                    icon="heroicon-o-arrow-path"
                    color="gray"
                >
                    Refresh
                </x-filament::button>
                <x-filament::button
                    wire:click="resetAllCircuitBreakers"
                    icon="heroicon-o-arrow-uturn-left"
                    color="warning"
                    wire:confirm="Are you sure you want to reset all circuit breakers?"
                >
                    Reset All
                </x-filament::button>
            </div>
        </div>

        {{-- Circuit Breaker Status Overview --}}
        <x-filament::section>
            <x-slot name="heading">
                Circuit Breaker Status
            </x-slot>

            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                    <thead class="bg-gray-50 dark:bg-gray-800">
                        <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Service</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Description</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">State</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Failures</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Config</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Controls</th>
                        </tr>
                    </thead>
                    <tbody class="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                        @foreach($circuitBreakers as $service => $breaker)
                            <tr>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    <div class="text-sm font-medium text-gray-900 dark:text-gray-100">{{ $service }}</div>
                                </td>
                                <td class="px-6 py-4">
                                    <div class="text-sm text-gray-600 dark:text-gray-400">{{ $breaker['description'] }}</div>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    @if($breaker['state'] === 'closed')
                                        <div class="flex items-center">
                                            <div class="h-3 w-3 rounded-full bg-green-500 mr-2"></div>
                                            <span class="text-sm font-medium text-green-600 dark:text-green-400">Closed (Healthy)</span>
                                        </div>
                                    @elseif($breaker['state'] === 'open')
                                        <div class="flex items-center">
                                            <div class="h-3 w-3 rounded-full bg-red-500 mr-2 animate-pulse"></div>
                                            <span class="text-sm font-medium text-red-600 dark:text-red-400">Open (Failing)</span>
                                        </div>
                                    @elseif($breaker['state'] === 'half_open')
                                        <div class="flex items-center">
                                            <div class="h-3 w-3 rounded-full bg-yellow-500 mr-2"></div>
                                            <span class="text-sm font-medium text-yellow-600 dark:text-yellow-400">Half-Open (Testing)</span>
                                        </div>
                                    @else
                                        <div class="flex items-center">
                                            <div class="h-3 w-3 rounded-full bg-gray-400 mr-2"></div>
                                            <span class="text-sm font-medium text-gray-600 dark:text-gray-400">Unknown</span>
                                        </div>
                                    @endif
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    <div class="text-sm text-gray-900 dark:text-gray-100">
                                        <span class="font-medium {{ $breaker['failures'] > 0 ? 'text-red-600 dark:text-red-400' : '' }}">
                                            {{ $breaker['failures'] }}
                                        </span>
                                        / {{ $breaker['threshold'] }}
                                    </div>
                                    @if($breaker['failures'] > 0)
                                        <div class="mt-1">
                                            <div class="w-32 bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                                                <div class="bg-red-600 h-2 rounded-full" style="width: {{ min(100, ($breaker['failures'] / $breaker['threshold']) * 100) }}%"></div>
                                            </div>
                                        </div>
                                    @endif
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    <div class="text-sm text-gray-600 dark:text-gray-400">
                                        <div>Threshold: <span class="font-medium">{{ $breaker['threshold'] }}</span></div>
                                        <div>Timeout: <span class="font-medium">{{ $breaker['timeout'] }}s</span></div>
                                    </div>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    <div class="flex flex-col space-y-1">
                                        @if($breaker['state'] === 'open')
                                            <x-filament::button
                                                wire:click="closeCircuitBreaker('{{ $service }}')"
                                                size="xs"
                                                color="success"
                                            >
                                                Close
                                            </x-filament::button>
                                            <x-filament::button
                                                wire:click="setHalfOpen('{{ $service }}')"
                                                size="xs"
                                                color="warning"
                                            >
                                                Half-Open
                                            </x-filament::button>
                                        @elseif($breaker['state'] === 'half_open')
                                            <x-filament::button
                                                wire:click="closeCircuitBreaker('{{ $service }}')"
                                                size="xs"
                                                color="success"
                                            >
                                                Close
                                            </x-filament::button>
                                            <x-filament::button
                                                wire:click="openCircuitBreaker('{{ $service }}')"
                                                size="xs"
                                                color="danger"
                                            >
                                                Open
                                            </x-filament::button>
                                        @else
                                            <x-filament::button
                                                wire:click="resetCircuitBreaker('{{ $service }}')"
                                                size="xs"
                                                color="gray"
                                            >
                                                Reset
                                            </x-filament::button>
                                            <x-filament::button
                                                wire:click="openCircuitBreaker('{{ $service }}')"
                                                size="xs"
                                                color="danger"
                                            >
                                                Open
                                            </x-filament::button>
                                        @endif
                                    </div>
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </x-filament::section>

        {{-- Circuit Breaker States Explanation --}}
        <x-filament::section>
            <x-slot name="heading">
                Understanding Circuit Breaker States
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="border border-green-200 dark:border-green-800 rounded-lg p-6 bg-green-50 dark:bg-green-900/20">
                    <div class="flex items-center mb-4">
                        <div class="h-4 w-4 rounded-full bg-green-500 mr-3"></div>
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Closed (Healthy)</h3>
                    </div>
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                        Normal operation. All requests are allowed to pass through to the API.
                        The circuit breaker monitors for failures and will open if the threshold is exceeded.
                    </p>
                </div>

                <div class="border border-red-200 dark:border-red-800 rounded-lg p-6 bg-red-50 dark:bg-red-900/20">
                    <div class="flex items-center mb-4">
                        <div class="h-4 w-4 rounded-full bg-red-500 mr-3 animate-pulse"></div>
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Open (Failing)</h3>
                    </div>
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                        Too many failures detected. All requests fail immediately without calling the API.
                        After the timeout period, the circuit automatically transitions to Half-Open to test recovery.
                    </p>
                </div>

                <div class="border border-yellow-200 dark:border-yellow-800 rounded-lg p-6 bg-yellow-50 dark:bg-yellow-900/20">
                    <div class="flex items-center mb-4">
                        <div class="h-4 w-4 rounded-full bg-yellow-500 mr-3"></div>
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">Half-Open (Testing)</h3>
                    </div>
                    <p class="text-sm text-gray-600 dark:text-gray-400">
                        Testing if the API has recovered. A limited number of requests are allowed through.
                        If successful, transitions to Closed. If failures continue, returns to Open.
                    </p>
                </div>
            </div>
        </x-filament::section>

        {{-- Historical Failure Data --}}
        @if(!empty($historicalData))
            <x-filament::section>
                <x-slot name="heading">
                    Recent Circuit Breaker Events
                </x-slot>

                <div class="space-y-4">
                    @foreach($historicalData as $service => $events)
                        @if(!empty($events))
                            <div class="border dark:border-gray-700 rounded-lg p-4">
                                <h4 class="text-sm font-semibold text-gray-900 dark:text-white mb-3">{{ $service }}</h4>
                                <div class="space-y-2">
                                    @foreach($events as $event)
                                        <div class="flex items-center justify-between text-sm">
                                            <span class="text-gray-600 dark:text-gray-400">
                                                {{ $event['type'] ?? 'Event' }}
                                            </span>
                                            <span class="text-gray-500 dark:text-gray-500">
                                                {{ $event['timestamp'] ?? 'N/A' }}
                                            </span>
                                        </div>
                                    @endforeach
                                </div>
                            </div>
                        @endif
                    @endforeach
                </div>
            </x-filament::section>
        @endif

        {{-- Alert Settings Info --}}
        <x-filament::section>
            <x-slot name="heading">
                Alert Configuration
            </x-slot>

            <div class="prose dark:prose-invert max-w-none">
                <p class="text-sm text-gray-600 dark:text-gray-400">
                    Circuit breakers automatically log events when state changes occur. Configure your monitoring
                    system to alert on circuit breaker state changes by watching the application logs for entries
                    containing "Circuit breaker OPENED" or "Circuit breaker CLOSED".
                </p>
                <div class="mt-4 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
                    <h4 class="text-sm font-semibold text-gray-900 dark:text-white mb-2">Recommended Actions</h4>
                    <ul class="text-sm text-gray-600 dark:text-gray-400 space-y-1">
                        <li>Monitor circuit breaker states in your logging/monitoring system</li>
                        <li>Set up alerts for OPEN states to notify your team immediately</li>
                        <li>Review API health regularly in the API Health Monitor page</li>
                        <li>Adjust thresholds and timeouts if you experience frequent false positives</li>
                    </ul>
                </div>
            </div>
        </x-filament::section>
    </div>
</x-filament-panels::page>
