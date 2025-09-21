<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Carbon\Carbon;

class Notification extends Model
{
    use SoftDeletes;

    protected $table = 'notifications';

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'message',
        'data',
        'is_read',
        'priority',
        'expires_at',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'data' => 'array',
        'is_read' => 'boolean',
        'expires_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at', 'expires_at'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopeUnread($query)
    {
        return $query->where('is_read', false);
    }

    public function scopeRead($query)
    {
        return $query->where('is_read', true);
    }

    public function scopeByType($query, string $type)
    {
        return $query->where('type', $type);
    }

    public function scopePriority($query, string $priority)
    {
        return $query->where('priority', $priority);
    }

    public function scopeNotExpired($query)
    {
        return $query->where(function ($q) {
            $q->whereNull('expires_at')
              ->orWhere('expires_at', '>', now());
        });
    }

    public function markAsRead(): bool
    {
        return $this->update(['is_read' => true]);
    }

    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    public function isCritical(): bool
    {
        return $this->priority === 'critical';
    }

    public function getAgeAttribute(): string
    {
        return $this->created_at->diffForHumans();
    }

    public static function createForUser(
        int $userId,
        string $type,
        string $title,
        string $message,
        array $data = [],
        string $priority = 'normal',
        ?Carbon $expiresAt = null
    ): self {
        return self::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'message' => $message,
            'data' => $data,
            'priority' => $priority,
            'expires_at' => $expiresAt,
        ]);
    }

    // Constants pour les types de notifications
    public const TYPES = [
        'trip_submitted' => 'trip_submitted',
        'trip_approved' => 'trip_approved', 
        'trip_rejected' => 'trip_rejected',
        'new_booking_request' => 'new_booking_request',
        'booking_accepted' => 'booking_accepted',
        'booking_rejected' => 'booking_rejected',
        'payment_confirmed' => 'payment_confirmed',
        'package_delivered' => 'package_delivered',
        'security_alert' => 'security_alert',
    ];

    public const PRIORITIES = [
        'low' => 'low',
        'normal' => 'normal', 
        'high' => 'high',
        'critical' => 'critical'
    ];
}