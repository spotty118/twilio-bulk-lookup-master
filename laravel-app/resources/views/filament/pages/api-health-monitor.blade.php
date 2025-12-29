<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Header Actions --}}
        <div class="flex justify-end">
            <x-filament::button
                wire:click="refreshMetrics"
                icon="heroicon-o-arrow-path"
                color="gray"
            >
                Refresh Metrics
            </x-filament::button>
        </div>

        {{-- API Metrics Overview --}}
        <x-filament::section>
            <x-slot name="heading">
                API Metrics (Last 24 Hours)
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                    <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Total Requests</div>
                    <div class="mt-2 text-3xl font-semibold text-gray-900 dark:text-white">{{ number_format($apiMetrics['total_requests']) }}</div>
                </div>
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                    <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Successful</div>
                    <div class="mt-2 text-3xl font-semibold text-green-600 dark:text-green-400">{{ number_format($apiMetrics['successful']) }}</div>
                </div>
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                    <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Failed</div>
                    <div class="mt-2 text-3xl font-semibold text-red-600 dark:text-red-400">{{ number_format($apiMetrics['failed']) }}</div>
                </div>
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                    <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Success Rate</div>
                    <div class="mt-2 text-3xl font-semibold text-blue-600 dark:text-blue-400">{{ $apiMetrics['success_rate'] }}%</div>
                </div>
                <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                    <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Avg Response Time</div>
                    <div class="mt-2 text-3xl font-semibold text-purple-600 dark:text-purple-400">{{ number_format($apiMetrics['avg_response_time']) }}ms</div>
                </div>
            </div>
        </x-filament::section>

        {{-- Circuit Breaker Status --}}
        <x-filament::section>
            <x-slot name="heading">
                Circuit Breaker Status
            </x-slot>
            <x-slot name="description">
                Circuit breakers protect against API failures by temporarily blocking requests when error thresholds are exceeded
            </x-slot>

            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                    <thead class="bg-gray-50 dark:bg-gray-800">
                        <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Service</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Description</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Status</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Failures</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Threshold</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Timeout</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                        @foreach($circuitBreakers as $service => $breaker)
                            <tr>
                                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                                    {{ $service }}
                                </td>
                                <td class="px-6 py-4 text-sm text-gray-600 dark:text-gray-400">
                                    {{ $breaker['description'] }}
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    @if($breaker['state'] === 'closed')
                                        <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100">
                                            Closed (Healthy)
                                        </span>
                                    @elseif($breaker['state'] === 'open')
                                        <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100">
                                            Open (Failing)
                                        </span>
                                    @elseif($breaker['state'] === 'half_open')
                                        <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800 dark:bg-yellow-800 dark:text-yellow-100">
                                            Half-Open (Testing)
                                        </span>
                                    @else
                                        <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-100">
                                            Unknown
                                        </span>
                                    @endif
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                    {{ $breaker['failures'] }}
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                    {{ $breaker['threshold'] }}
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                    {{ $breaker['timeout'] }}s
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm space-x-2">
                                    <x-filament::button
                                        wire:click="resetCircuitBreaker('{{ $service }}')"
                                        size="xs"
                                        color="success"
                                    >
                                        Reset
                                    </x-filament::button>
                                    @if($breaker['state'] !== 'open')
                                        <x-filament::button
                                            wire:click="openCircuitBreaker('{{ $service }}')"
                                            size="xs"
                                            color="danger"
                                        >
                                            Open
                                        </x-filament::button>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </x-filament::section>

        {{-- Cost Tracking --}}
        <x-filament::section>
            <x-slot name="heading">
                Cost Tracking (Current Month)
            </x-slot>

            <div class="space-y-4">
                <div class="bg-gradient-to-r from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-800/20 rounded-lg p-6">
                    <div class="text-sm font-medium text-gray-600 dark:text-gray-400">Total API Cost This Month</div>
                    <div class="mt-2 text-4xl font-bold text-blue-600 dark:text-blue-400">${{ number_format($totalCost, 2) }}</div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                    @foreach($costsByProvider as $provider => $cost)
                        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
                            <div class="text-sm font-medium text-gray-600 dark:text-gray-400">{{ ucfirst($provider) }}</div>
                            <div class="mt-2 text-2xl font-semibold text-gray-900 dark:text-white">${{ number_format($cost, 2) }}</div>
                        </div>
                    @endforeach
                </div>
            </div>
        </x-filament::section>

        {{-- Recent API Usage --}}
        <x-filament::section>
            <x-slot name="heading">
                Recent API Usage (Last 20 Calls)
            </x-slot>

            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                    <thead class="bg-gray-50 dark:bg-gray-800">
                        <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Provider</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Service</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Status</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Response Time</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Cost</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Contact</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Time</th>
                        </tr>
                    </thead>
                    <tbody class="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                        @forelse($recentUsage as $usage)
                            <tr>
                                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-gray-100">
                                    {{ ucfirst($usage['provider']) }}
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                    {{ $usage['service'] }}
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    @if($usage['status'] === 'success')
                                        <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100">
                                            Success
                                        </span>
                                    @else
                                        <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100">
                                            {{ ucfirst($usage['status']) }}
                                        </span>
                                    @endif
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                    {{ $usage['response_time'] ? number_format($usage['response_time']) . 'ms' : 'N/A' }}
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                    ${{ number_format($usage['cost'], 4) }}
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">
                                    @if($usage['contact_id'])
                                        <a href="{{ route('filament.admin.resources.contacts.view', ['record' => $usage['contact_id']]) }}"
                                           class="text-primary-600 hover:text-primary-900 dark:text-primary-400 dark:hover:text-primary-300">
                                            #{{ $usage['contact_id'] }}
                                        </a>
                                    @else
                                        N/A
                                    @endif
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                                    {{ $usage['requested_at'] }}
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7" class="px-6 py-4 text-center text-sm text-gray-500 dark:text-gray-400">No API usage logs found</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </x-filament::section>

        {{-- Requests by Provider --}}
        @if(!empty($apiMetrics['by_provider']))
            <x-filament::section>
                <x-slot name="heading">
                    Requests by Provider (Last 24 Hours)
                </x-slot>

                <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                    @foreach($apiMetrics['by_provider'] as $provider => $count)
                        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-4">
                            <div class="text-sm font-medium text-gray-600 dark:text-gray-400">{{ ucfirst($provider) }}</div>
                            <div class="mt-2 text-2xl font-semibold text-gray-900 dark:text-white">{{ number_format($count) }}</div>
                        </div>
                    @endforeach
                </div>
            </x-filament::section>
        @endif
    </div>
</x-filament-panels::page>
