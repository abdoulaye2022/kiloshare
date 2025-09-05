<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    protected $fillable = [
        'uuid',
        'booking_id',
        'stripe_payment_intent_id',
        'stripe_payment_method_id',
        'stripe_account_id',
        'amount',
        'commission',
        'receiver_amount',
        'currency',
        'status',
        'transfer_status',
        'payment_method',
        'processed_at',
        'delivered_at',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'commission' => 'decimal:2',
        'receiver_amount' => 'decimal:2',
        'processed_at' => 'datetime',
        'delivered_at' => 'datetime',
    ];

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function scopeCompleted($query)
    {
        return $query->where('status', 'completed');
    }

    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    public function getStripeFeesAttribute(): float
    {
        // Stripe fees: 2.9% + $0.30 CAD per successful transaction
        return ($this->amount * 0.029) + 0.30;
    }

    public function getNetAmountAttribute(): float
    {
        return $this->amount - $this->stripe_fees - $this->commission;
    }
}