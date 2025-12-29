<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\ContactsController;

// Public API V1
Route::prefix('v1')->name('api.v1.')->group(function () {
    // API Token authentication middleware will be applied in the controller
    Route::apiResource('contacts', ContactsController::class)->only(['index', 'show', 'store']);
});
