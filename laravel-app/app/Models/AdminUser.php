<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;

class AdminUser extends Authenticatable
{
    use HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<string>
     */
    protected $fillable = [
        'email',
        'password',
        'reset_password_token',
        'reset_password_sent_at',
        'remember_created_at',
        'sign_in_count',
        'current_sign_in_at',
        'last_sign_in_at',
        'current_sign_in_ip',
        'last_sign_in_ip',
        'api_token',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'api_token',
        'reset_password_token',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'reset_password_sent_at' => 'datetime',
        'remember_created_at' => 'datetime',
        'current_sign_in_at' => 'datetime',
        'last_sign_in_at' => 'datetime',
    ];

    /**
     * Boot method for model events
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($adminUser) {
            if (empty($adminUser->api_token)) {
                $adminUser->generateApiToken();
            }
        });
    }

    /**
     * Generate a unique API token
     */
    public function generateApiToken(): void
    {
        do {
            $token = Str::random(48);
        } while (self::where('api_token', $token)->exists());

        $this->api_token = $token;
    }

    /**
     * Track sign in
     */
    public function trackSignIn(string $ip): void
    {
        $this->increment('sign_in_count');
        $this->update([
            'last_sign_in_at' => $this->current_sign_in_at,
            'last_sign_in_ip' => $this->current_sign_in_ip,
            'current_sign_in_at' => now(),
            'current_sign_in_ip' => $ip,
        ]);
    }
}
