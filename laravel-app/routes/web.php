<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\LookupController;
use App\Http\Controllers\WebhooksController;
use App\Http\Controllers\HealthController;

// Root route - redirect to Filament admin panel
Route::redirect('/', '/admin');

// Bulk lookup trigger (requires authentication via Filament middleware)
Route::middleware(['auth:admin'])->group(function () {
    Route::get('/lookup', [LookupController::class, 'run'])->name('lookup.run');
});

// Webhook endpoints (no CSRF protection)
Route::prefix('webhooks')->withoutMiddleware([\App\Http\Middleware\VerifyCsrfToken::class])->group(function () {
    Route::post('twilio/sms_status', [WebhooksController::class, 'twilioSmsStatus'])->name('webhooks.twilio.sms');
    Route::post('twilio/voice_status', [WebhooksController::class, 'twilioVoiceStatus'])->name('webhooks.twilio.voice');
    Route::post('twilio/trust_hub', [WebhooksController::class, 'twilioTrustHub'])->name('webhooks.twilio.trust_hub');
    Route::post('generic', [WebhooksController::class, 'generic'])->name('webhooks.generic');
});

// Health check endpoints (Kubernetes-compatible)
Route::get('up', [HealthController::class, 'up'])->name('health.up');
Route::get('health', [HealthController::class, 'show'])->name('health.check');
Route::get('health/ready', [HealthController::class, 'ready'])->name('health.ready');
Route::get('health/detailed', [HealthController::class, 'detailed'])->name('health.detailed');
Route::get('health/queue', [HealthController::class, 'queue'])->name('health.queue');
