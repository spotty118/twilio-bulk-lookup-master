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
        Schema::create('admin_users', function (Blueprint $table) {
            $table->id();

            // Database authenticatable
            $table->string('email')->unique();
            $table->string('password');

            // Recoverable
            $table->string('reset_password_token')->nullable()->unique();
            $table->timestamp('reset_password_sent_at')->nullable();

            // Rememberable
            $table->timestamp('remember_created_at')->nullable();

            // Trackable
            $table->integer('sign_in_count')->default(0);
            $table->timestamp('current_sign_in_at')->nullable();
            $table->timestamp('last_sign_in_at')->nullable();
            $table->ipAddress('current_sign_in_ip')->nullable();
            $table->ipAddress('last_sign_in_ip')->nullable();

            // API Token
            $table->string('api_token', 48)->nullable()->unique();

            $table->timestamps();

            // Indexes
            $table->index('email');
            $table->index('api_token');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('admin_users');
    }
};
