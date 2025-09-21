<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Carbon\Carbon;

class EscrowAccount extends Model
{
    protected $table = 'escrow_accounts';
    
    // Disable timestamps since the table doesn't have created_at/updated_at columns
    public $timestamps = false;

    protected $fillable = [
        'transaction_id',
        'amount_held',
        'amount_released',
        'hold_reason',
        'status',
        'held_at',
        'released_at',
        'release_notes',
    ];

    protected $casts = [
        'amount_held' => 'decimal:2',
        'amount_released' => 'decimal:2',
        'held_at' => 'datetime',
        'released_at' => 'datetime',
    ];

    // Status constants
    const STATUS_PENDING = 'pending';
    const STATUS_HELD = 'held';
    const STATUS_RELEASED = 'released';
    const STATUS_REFUNDED = 'refunded';
    const STATUS_DISPUTED = 'disputed';

    // Release reasons
    const RELEASE_DELIVERY_COMPLETED = 'delivery_completed';
    const RELEASE_ADMIN_ACTION = 'admin_action';
    const RELEASE_DISPUTE_RESOLVED = 'dispute_resolved';

    // Relations
    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    // Business methods
    public function holdFunds(): void
    {
        if ($this->status !== self::STATUS_PENDING) {
            throw new \Exception('Can only hold funds from pending escrow accounts');
        }

        $this->status = self::STATUS_HELD;
        $this->held_at = Carbon::now();
        $this->save();

        // Create transaction record
        $this->transactions()->create([
            'type' => 'hold',
            'amount' => $this->amount,
            'currency' => $this->currency,
            'description' => 'Funds held in escrow for trip #' . $this->trip_id,
        ]);
    }

    public function releaseFunds(string $reason = self::RELEASE_DELIVERY_COMPLETED): void
    {
        if ($this->status !== self::STATUS_HELD) {
            throw new \Exception('Can only release funds from held escrow accounts');
        }

        $this->status = self::STATUS_RELEASED;
        $this->released_at = Carbon::now();
        $this->release_reason = $reason;
        $this->save();

        // Create transaction record
        $this->transactions()->create([
            'type' => 'release',
            'amount' => $this->amount,
            'currency' => $this->currency,
            'description' => 'Funds released: ' . $reason,
        ]);
    }

    public function refundFunds(): void
    {
        if (!in_array($this->status, [self::STATUS_HELD, self::STATUS_PENDING])) {
            throw new \Exception('Can only refund funds from held or pending escrow accounts');
        }

        $this->status = self::STATUS_REFUNDED;
        $this->save();

        // Create transaction record
        $this->transactions()->create([
            'type' => 'refund',
            'amount' => $this->amount,
            'currency' => $this->currency,
            'description' => 'Funds refunded to sender',
        ]);
    }

    public function markAsDisputed(): void
    {
        $this->status = self::STATUS_DISPUTED;
        $this->save();
    }
}