<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Payment extends Model
{
    use SoftDeletes;

    protected $table = 'payments';

    const STATUS_PENDING = 'pending';
    const STATUS_PROCESSING = 'processing';
    const STATUS_COMPLETED = 'completed';
    const STATUS_FAILED = 'failed';
    const STATUS_CANCELLED = 'cancelled';
    const STATUS_REFUNDED = 'refunded';

    const TYPE_BOOKING = 'booking';
    const TYPE_REFUND = 'refund';
    const TYPE_PAYOUT = 'payout';

    const PROVIDER_STRIPE = 'stripe';
    const PROVIDER_PAYPAL = 'paypal';

    protected $fillable = [
        'booking_id',
        'user_id',
        'type',
        'provider',
        'provider_payment_id',
        'amount',
        'currency',
        'fee_amount',
        'net_amount',
        'status',
        'description',
        'metadata',
        'processed_at',
        'failed_at',
        'failure_reason',
    ];

    protected $casts = [
        'booking_id' => 'integer',
        'user_id' => 'integer',
        'amount' => 'decimal:2',
        'fee_amount' => 'decimal:2',
        'net_amount' => 'decimal:2',
        'metadata' => 'array',
        'processed_at' => 'datetime',
        'failed_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at', 'processed_at', 'failed_at'];

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

    public function scopeCompleted($query)
    {
        return $query->where('status', self::STATUS_COMPLETED);
    }

    public function scopeFailed($query)
    {
        return $query->where('status', self::STATUS_FAILED);
    }

    public function markAsCompleted(): bool
    {
        $this->status = self::STATUS_COMPLETED;
        $this->processed_at = now();
        return $this->save();
    }

    public function markAsFailed(string $reason = null): bool
    {
        $this->status = self::STATUS_FAILED;
        $this->failed_at = now();
        if ($reason) {
            $this->failure_reason = $reason;
        }
        return $this->save();
    }

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isFailed(): bool
    {
        return $this->status === self::STATUS_FAILED;
    }
}