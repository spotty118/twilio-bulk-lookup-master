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
        Schema::create('api_usage_logs', function (Blueprint $table) {
            $table->id();

            // Foreign key to contact (optional)
            $table->foreignId('contact_id')->nullable()->constrained()->onDelete('cascade');

            // API identification
            $table->string('provider')->index();
            $table->string('service')->index();
            $table->string('endpoint')->nullable();

            // Cost tracking
            $table->decimal('cost', 10, 4)->default(0.0);
            $table->string('currency')->default('USD');
            $table->integer('credits_used')->default(0);

            // Request details
            $table->string('request_id')->nullable();
            $table->string('status')->nullable()->index();
            $table->integer('response_time_ms')->nullable();
            $table->integer('http_status_code')->nullable();

            // Metadata (JSON)
            $table->json('request_params')->nullable();
            $table->json('response_data')->nullable();
            $table->text('error_message')->nullable();

            // Timestamps
            $table->timestamp('requested_at')->index();
            $table->timestamps();

            // Composite indexes for efficient querying
            $table->index(['provider', 'requested_at']);
            $table->index(['contact_id', 'provider']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('api_usage_logs');
    }
};
