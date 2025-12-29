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
        Schema::create('webhooks', function (Blueprint $table) {
            $table->id();

            // Foreign key to contact (optional, nullified on delete)
            $table->foreignId('contact_id')->nullable()->constrained()->nullOnDelete();

            // Webhook identification
            $table->string('source')->index(); // twilio_trust_hub, twilio_sms, twilio_voice, etc.
            $table->string('event_type')->index(); // status_update, delivery_report, etc.
            $table->string('external_id')->nullable()->index(); // external reference ID

            // Payload (JSON)
            $table->json('payload')->nullable();
            $table->json('headers')->nullable();

            // Processing status
            $table->string('status')->default('pending')->index(); // pending, processing, processed, failed
            $table->timestamp('processed_at')->nullable();
            $table->text('processing_error')->nullable();
            $table->integer('retry_count')->default(0);

            // Idempotency
            $table->string('idempotency_key')->unique();

            // Timestamps
            $table->timestamp('received_at')->index();
            $table->timestamps();

            // Composite indexes
            $table->index(['source', 'event_type']);
            $table->unique(['source', 'external_id'], 'webhooks_source_external_id_unique')
                  ->where('external_id', '!=', null);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('webhooks');
    }
};
