<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Carbon\Carbon;

class UserFCMToken extends Model
{
    use SoftDeletes;

    protected $table = 'user_fcm_tokens';

    protected $fillable = [
        'user_id',
        'fcm_token',
        'platform',
        'is_active',
        'device_info',
        'app_version',
        'last_used_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'device_info' => 'array',
        'last_used_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = [
        'last_used_at',
        'created_at',
        'updated_at',
        'deleted_at',
    ];

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($token) {
            $token->last_used_at = Carbon::now();
            if (is_null($token->is_active)) {
                $token->is_active = true;
            }
        });

        static::updating(function ($token) {
            if ($token->isDirty('fcm_token') || $token->isDirty('is_active')) {
                $token->last_used_at = Carbon::now();
            }
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function activate(): void
    {
        $this->is_active = true;
        $this->last_used_at = Carbon::now();
        $this->save();
    }

    public function deactivate(): void
    {
        $this->is_active = false;
        $this->save();
    }

    public function updateLastUsed(): void
    {
        $this->last_used_at = Carbon::now();
        $this->save();
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeInactive($query)
    {
        return $query->where('is_active', false);
    }

    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    public function scopeByPlatform($query, string $platform)
    {
        return $query->where('platform', $platform);
    }

    public function scopeByToken($query, string $token)
    {
        return $query->where('fcm_token', $token);
    }

    public function scopeExpired($query, int $daysOld = 30)
    {
        return $query->where('last_used_at', '<', Carbon::now()->subDays($daysOld));
    }
}