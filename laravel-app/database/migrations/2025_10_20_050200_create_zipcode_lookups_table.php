<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('zipcode_lookups', function (Blueprint $table) {
            $table->id();

            // Zipcode and status
            $table->string('zipcode')->index();
            $table->string('status')->default('pending')->index(); // pending, processing, completed, failed

            // Statistics
            $table->integer('businesses_found')->default(0);
            $table->integer('businesses_imported')->default(0);
            $table->integer('businesses_updated')->default(0);
            $table->integer('businesses_skipped')->default(0);

            // Provider and search params
            $table->string('provider')->nullable(); // google_places, yelp, etc.
            $table->text('search_params')->nullable(); // JSON with search parameters
            $table->text('error_message')->nullable();

            // Timing
            $table->timestamp('lookup_started_at')->nullable();
            $table->timestamp('lookup_completed_at')->nullable();

            $table->timestamps();

            // Indexes
            $table->index('created_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('zipcode_lookups');
    }
};
