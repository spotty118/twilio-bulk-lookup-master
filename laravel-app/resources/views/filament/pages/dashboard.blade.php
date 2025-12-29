<x-filament-panels::page>
    <div class="space-y-6">
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

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
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
                    href="{{ route('lookup.run') }}"
                    icon="heroicon-o-play"
                    color="success"
                    size="lg"
                    class="w-full"
                >
                    Run Bulk Lookup
                </x-filament::button>

                <x-filament::button
                    href="{{ route('health.detailed') }}"
                    icon="heroicon-o-heart"
                    color="gray"
                    size="lg"
                    class="w-full"
                    target="_blank"
                >
                    System Health
                </x-filament::button>
            </div>
        </x-filament::section>

        {{-- System Information --}}
        <x-filament::section>
            <x-slot name="heading">
                System Information
            </x-slot>

            <dl class="grid grid-cols-1 md:grid-cols-2 gap-4">
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
