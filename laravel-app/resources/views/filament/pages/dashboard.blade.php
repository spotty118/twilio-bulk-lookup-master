<x-filament-panels::page>
    <div class="space-y-6">
        {{-- Statistics Overview --}}
        <div class="grid grid-cols-1 md:grid-cols-5 gap-4">
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Total Contacts</div>
                <div class="mt-2 text-3xl font-semibold text-gray-900 dark:text-white">{{ number_format($stats['total']) }}</div>
            </div>
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Pending</div>
                <div class="mt-2 text-3xl font-semibold text-yellow-600 dark:text-yellow-400">{{ number_format($stats['pending']) }}</div>
            </div>
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Processing</div>
                <div class="mt-2 text-3xl font-semibold text-blue-600 dark:text-blue-400">{{ number_format($stats['processing']) }}</div>
            </div>
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Completed</div>
                <div class="mt-2 text-3xl font-semibold text-green-600 dark:text-green-400">{{ number_format($stats['completed']) }}</div>
            </div>
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
                <div class="text-sm font-medium text-gray-500 dark:text-gray-400">Failed</div>
                <div class="mt-2 text-3xl font-semibold text-red-600 dark:text-red-400">{{ number_format($stats['failed']) }}</div>
            </div>
        </div>

        {{-- Display widgets --}}
        @if ($this->getWidgets())
            <x-filament-widgets::widgets
                :columns="$this->getColumns()"
                :widgets="$this->getWidgets()"
            />
        @endif

        {{-- Quick Actions --}}
        <x-filament::section>
            <x-slot name="heading">
                Quick Actions
            </x-slot>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <x-filament::button
                    href="{{ route('filament.admin.resources.contacts.index') }}"
                    icon="heroicon-o-phone"
                    color="primary"
                    size="lg"
                    class="w-full"
                >
                    View All Contacts
                </x-filament::button>

                <x-filament::button
                    wire:click="$refresh"
                    icon="heroicon-o-arrow-path"
                    color="gray"
                    size="lg"
                    class="w-full"
                >
                    Refresh Dashboard
                </x-filament::button>

                <x-filament::button
                    href="{{ url('/admin/business-lookup') }}"
                    icon="heroicon-o-magnifying-glass"
                    color="success"
                    size="lg"
                    class="w-full"
                >
                    Business Lookup
                </x-filament::button>

                <x-filament::button
                    href="{{ url('/admin/api-health-monitor') }}"
                    icon="heroicon-o-chart-bar"
                    color="warning"
                    size="lg"
                    class="w-full"
                >
                    API Health
                </x-filament::button>
            </div>
        </x-filament::section>

        {{-- Recent Contacts --}}
        <x-filament::section>
            <x-slot name="heading">
                Recent Contacts (Latest 10)
            </x-slot>

            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                    <thead class="bg-gray-50 dark:bg-gray-800">
                        <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">ID</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Phone</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Name</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Type</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Status</th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Created</th>
                        </tr>
                    </thead>
                    <tbody class="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                        @forelse($recentContacts as $contact)
                            <tr>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">{{ $contact['id'] }}</td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">{{ $contact['phone'] }}</td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">{{ $contact['name'] }}</td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100">{{ $contact['type'] }}</td>
                                <td class="px-6 py-4 whitespace-nowrap">
                                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full
                                        @if($contact['status'] === 'completed') bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-100
                                        @elseif($contact['status'] === 'processing') bg-blue-100 text-blue-800 dark:bg-blue-800 dark:text-blue-100
                                        @elseif($contact['status'] === 'pending') bg-yellow-100 text-yellow-800 dark:bg-yellow-800 dark:text-yellow-100
                                        @else bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-100
                                        @endif">
                                        {{ ucfirst($contact['status']) }}
                                    </span>
                                </td>
                                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">{{ $contact['created_at'] }}</td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="6" class="px-6 py-4 text-center text-sm text-gray-500 dark:text-gray-400">No contacts found</td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </x-filament::section>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            {{-- System Health --}}
            <x-filament::section>
                <x-slot name="heading">
                    System Health
                </x-slot>

                <div class="space-y-4">
                    @foreach($systemHealth as $service => $health)
                        <div class="flex items-center justify-between">
                            <div class="flex items-center space-x-3">
                                @if($health['status'] === 'healthy')
                                    <svg class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                                    </svg>
                                @elseif($health['status'] === 'warning')
                                    <svg class="h-5 w-5 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
                                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
                                    </svg>
                                @else
                                    <svg class="h-5 w-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                                    </svg>
                                @endif
                                <span class="text-sm font-medium text-gray-900 dark:text-white">{{ ucfirst($service) }}</span>
                            </div>
                            <span class="text-sm text-gray-500 dark:text-gray-400">{{ $health['message'] }}</span>
                        </div>
                    @endforeach
                </div>
            </x-filament::section>

            {{-- Daily Processing Trend --}}
            <x-filament::section>
                <x-slot name="heading">
                    Daily Processing (Last 7 Days)
                </x-slot>

                <div class="space-y-2">
                    @foreach($dailyProcessing as $day)
                        <div class="flex items-center justify-between">
                            <span class="text-sm text-gray-600 dark:text-gray-400">{{ $day['date'] }}</span>
                            <div class="flex items-center space-x-2">
                                <div class="w-32 bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                                    <div class="bg-blue-600 h-2 rounded-full" style="width: {{ min(100, ($day['count'] / max(1, $stats['total'])) * 1000) }}%"></div>
                                </div>
                                <span class="text-sm font-medium text-gray-900 dark:text-white w-16 text-right">{{ $day['count'] }}</span>
                            </div>
                        </div>
                    @endforeach
                </div>
            </x-filament::section>
        </div>

        {{-- System Information --}}
        <x-filament::section>
            <x-slot name="heading">
                System Information
            </x-slot>

            <dl class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Laravel Version</dt>
                    <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">{{ app()->version() }}</dd>
                </div>
                <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">PHP Version</dt>
                    <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">{{ PHP_VERSION }}</dd>
                </div>
                <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Environment</dt>
                    <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">{{ config('app.env') }}</dd>
                </div>
                <div>
                    <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Application Version</dt>
                    <dd class="mt-1 text-sm text-gray-900 dark:text-gray-100">{{ config('app.version', '1.0.0') }}</dd>
                </div>
            </dl>
        </x-filament::section>
    </div>
</x-filament-panels::page>
