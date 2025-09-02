<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class BookingNegotiation extends Model
{
    use SoftDeletes;

    protected $table = 'booking_negotiations';

    const STATUS_PENDING = 'pending';
    const STATUS_ACCEPTED = 'accepted';
    const STATUS_REJECTED = 'rejected';
    const STATUS_COUNTER = 'counter';

    protected $fillable = [
        'booking_id',
        'user_id',
        'proposed_price',
        'message',
        'status',
        'response_message',
    ];

    protected $casts = [
        'booking_id' => 'integer',
        'user_id' => 'integer',
        'proposed_price' => 'decimal:2',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at'];

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeAccepted($query)
    {
        return $query->where('status', self::STATUS_ACCEPTED);
    }

    public function accept(string $responseMessage = null): bool
    {
        $this->status = self::STATUS_ACCEPTED;
        if ($responseMessage) {
            $this->response_message = $responseMessage;
        }
        return $this->save();
    }

    public function reject(string $responseMessage = null): bool
    {
        $this->status = self::STATUS_REJECTED;
        if ($responseMessage) {
            $this->response_message = $responseMessage;
        }
        return $this->save();
    }
}