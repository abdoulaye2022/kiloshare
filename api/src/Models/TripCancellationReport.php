<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Carbon\Carbon;

class TripCancellationReport extends Model
{
    protected $table = 'trip_cancellation_reports';

    protected $fillable = [
        'trip_id',
        'user_id',
        'booking_id',
        'cancellation_reason',
        'cancellation_type',
        'is_public',
        'expires_at',
    ];

    protected $casts = [
        'is_public' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'expires_at' => 'datetime',
    ];

    protected $dates = [
        'created_at',
        'updated_at',
        'expires_at',
    ];

    // Types d'annulation
    const TYPE_WITH_BOOKING = 'with_booking';
    const TYPE_WITHOUT_BOOKING = 'without_booking';

    // Relations
    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    // Scopes
    public function scopePublic($query)
    {
        return $query->where('is_public', true);
    }

    public function scopeNotExpired($query)
    {
        return $query->where(function ($query) {
            $query->whereNull('expires_at')
                  ->orWhere('expires_at', '>', now());
        });
    }

    public function scopeVisible($query)
    {
        return $query->public()->notExpired();
    }

    // Accesseurs
    public function getIsExpiredAttribute(): bool
    {
        if (!$this->expires_at) {
            return false;
        }

        return Carbon::now()->isAfter($this->expires_at);
    }

    public function getDaysUntilExpirationAttribute(): ?int
    {
        if (!$this->expires_at || $this->is_expired) {
            return null;
        }

        return Carbon::now()->diffInDays($this->expires_at);
    }

    // Méthodes
    public function hide(): void
    {
        $this->is_public = false;
        $this->save();
    }

    public function show(): void
    {
        $this->is_public = true;
        $this->save();
    }

    public function extendVisibility(int $days): void
    {
        $this->expires_at = Carbon::now()->addDays($days);
        $this->save();
    }
}