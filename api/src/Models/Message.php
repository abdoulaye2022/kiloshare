<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Message extends Model
{
    use SoftDeletes;

    protected $table = 'messages';

    protected $fillable = [
        'booking_id',
        'sender_id',
        'receiver_id',
        'content',
        'is_read',
        'read_at',
        'message_type',
        'attachment_url',
    ];

    protected $casts = [
        'booking_id' => 'integer',
        'sender_id' => 'integer',
        'receiver_id' => 'integer',
        'is_read' => 'boolean',
        'read_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at', 'read_at'];

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function receiver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    public function scopeUnread($query)
    {
        return $query->where('is_read', false);
    }

    public function scopeRead($query)
    {
        return $query->where('is_read', true);
    }

    public function scopeForBooking($query, int $bookingId)
    {
        return $query->where('booking_id', $bookingId);
    }

    public function scopeBetweenUsers($query, int $user1Id, int $user2Id)
    {
        return $query->where(function ($q) use ($user1Id, $user2Id) {
            $q->where(function ($qq) use ($user1Id, $user2Id) {
                $qq->where('sender_id', $user1Id)->where('receiver_id', $user2Id);
            })->orWhere(function ($qq) use ($user1Id, $user2Id) {
                $qq->where('sender_id', $user2Id)->where('receiver_id', $user1Id);
            });
        });
    }

    public function markAsRead(): bool
    {
        $this->is_read = true;
        $this->read_at = now();
        return $this->save();
    }
}