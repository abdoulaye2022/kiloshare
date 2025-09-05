<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    protected $table = 'transactions';

    protected $fillable = [
        'booking_id',
        'stripe_payment_intent_id',
        'stripe_payment_method_id',
        'amount',
        'commission',
        'receiver_amount',
        'currency',
        'status',
        'payment_method',
        'processed_at',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'processed_at' => 'datetime',
        'created_at' => 'datetime',
    ];

    // Transaction types
    const TYPE_HOLD = 'hold';
    const TYPE_RELEASE = 'release';
    const TYPE_REFUND = 'refund';
    const TYPE_FEE_DEDUCTION = 'fee_deduction';

    // Relations
    public function escrowAccount(): BelongsTo
    {
        return $this->belongsTo(EscrowAccount::class);
    }
}