<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeliveryCodeHistory extends Model
{
    protected $table = 'delivery_code_history';

    protected $fillable = [
        'booking_id',
        'old_code',
        'new_code',
        'action',
        'triggered_by_user_id',
        'reason',
    ];

    public $timestamps = false; // Utilise created_at seulement

    // Actions possibles
    const ACTION_GENERATED = 'generated';
    const ACTION_REGENERATED = 'regenerated';
    const ACTION_EXPIRED = 'expired';
    const ACTION_USED = 'used';

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($history) {
            $history->created_at = now();
        });
    }

    // Relations
    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function triggeredByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'triggered_by_user_id');
    }

    // Scopes
    public function scopeForBooking($query, int $bookingId)
    {
        return $query->where('booking_id', $bookingId);
    }

    public function scopeByAction($query, string $action)
    {
        return $query->where('action', $action);
    }

    public function scopeRecent($query, int $days = 30)
    {
        return $query->where('created_at', '>=', now()->subDays($days));
    }

    // Méthodes utilitaires
    public function getActionLabelAttribute(): string
    {
        $labels = [
            self::ACTION_GENERATED => 'Code généré',
            self::ACTION_REGENERATED => 'Code régénéré',
            self::ACTION_EXPIRED => 'Code expiré',
            self::ACTION_USED => 'Code utilisé',
        ];

        return $labels[$this->action] ?? $this->action;
    }
}