<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Notification extends Model
{
    use SoftDeletes;

    protected $table = 'notifications';

    const TYPE_BOOKING_REQUEST = 'booking_request';
    const TYPE_BOOKING_ACCEPTED = 'booking_accepted';
    const TYPE_BOOKING_REJECTED = 'booking_rejected';
    const TYPE_TRIP_APPROVED = 'trip_approved';
    const TYPE_TRIP_REJECTED = 'trip_rejected';
    const TYPE_PAYMENT_RECEIVED = 'payment_received';
    const TYPE_REVIEW_RECEIVED = 'review_received';
    const TYPE_MESSAGE_RECEIVED = 'message_received';

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'message',
        'data',
        'is_read',
        'read_at',
        'action_url',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'data' => 'array',
        'is_read' => 'boolean',
        'read_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at', 'read_at'];

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

    public function markAsRead(): bool
    {
        $this->is_read = true;
        $this->read_at = now();
        return $this->save();
    }

    public function markAsUnread(): bool
    {
        $this->is_read = false;
        $this->read_at = null;
        return $this->save();
    }

    public static function createForUser(
        int $userId,
        string $type,
        string $title,
        string $message,
        array $data = [],
        string $actionUrl = null
    ): self {
        return self::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'message' => $message,
            'data' => $data,
            'action_url' => $actionUrl,
        ]);
    }
}