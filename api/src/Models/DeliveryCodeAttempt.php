<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeliveryCodeAttempt extends Model
{
    protected $table = 'delivery_code_attempts';

    protected $fillable = [
        'delivery_code_id',
        'attempted_code',
        'user_id',
        'attempt_latitude',
        'attempt_longitude',
        'success',
        'error_message',
        'attempted_at',
    ];

    protected $casts = [
        'attempt_latitude' => 'decimal:8',
        'attempt_longitude' => 'decimal:8',
        'success' => 'boolean',
        'attempted_at' => 'datetime',
    ];

    public $timestamps = false; // Utilise attempted_at au lieu de created_at/updated_at

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($attempt) {
            if (empty($attempt->attempted_at)) {
                $attempt->attempted_at = now();
            }
        });
    }

    // Relations
    public function deliveryCode(): BelongsTo
    {
        return $this->belongsTo(DeliveryCode::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeSuccessful($query)
    {
        return $query->where('success', true);
    }

    public function scopeFailed($query)
    {
        return $query->where('success', false);
    }

    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    public function scopeForDeliveryCode($query, int $deliveryCodeId)
    {
        return $query->where('delivery_code_id', $deliveryCodeId);
    }

    public function scopeRecent($query, int $hours = 24)
    {
        return $query->where('attempted_at', '>=', now()->subHours($hours));
    }

    // Méthodes utilitaires
    public function hasLocation(): bool
    {
        return $this->attempt_latitude !== null && $this->attempt_longitude !== null;
    }

    public function getLocationArray(): array
    {
        return [
            'latitude' => $this->attempt_latitude,
            'longitude' => $this->attempt_longitude,
        ];
    }
}