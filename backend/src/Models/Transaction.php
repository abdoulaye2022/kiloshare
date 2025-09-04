<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    protected $table = 'transactions';

    protected $fillable = [
        'escrow_account_id',
        'type',
        'amount',
        'currency',
        'stripe_transaction_id',
        'description',
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