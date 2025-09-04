<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
class BookingNegotiation extends Model
{

    protected $table = 'booking_negotiations';

    const STATUS_PENDING = 'pending';
    const STATUS_ACCEPTED = 'accepted';
    const STATUS_REJECTED = 'rejected';
    const STATUS_COUNTER = 'counter';

    protected $fillable = [
        'booking_id',
        'proposed_by',
        'amount',
        'message',
        'is_accepted',
    ];

    protected $casts = [
        'booking_id' => 'integer',
        'proposed_by' => 'integer',
        'amount' => 'decimal:2',
        'is_accepted' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function proposedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'proposed_by');
    }

    public function scopePending($query)
    {
        return $query->where('is_accepted', null);
    }

    public function scopeAccepted($query)
    {
        return $query->where('is_accepted', true);
    }

    public function accept(?string $responseMessage = null): bool
    {
        $this->is_accepted = true;
        return $this->save();
    }

    public function reject(?string $responseMessage = null): bool
    {
        $this->is_accepted = false;
        return $this->save();
    }
}