<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserStripeAccount extends Model
{
    protected $table = 'user_stripe_accounts';

    const STATUS_PENDING = 'pending';
    const STATUS_ONBOARDING = 'onboarding';  
    const STATUS_ACTIVE = 'active';
    const STATUS_RESTRICTED = 'restricted';
    const STATUS_REJECTED = 'rejected';

    protected $fillable = [
        'user_id',
        'stripe_account_id',
        'status',
        'details_submitted',
        'charges_enabled',
        'payouts_enabled',
        'onboarding_url',
        'requirements',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'details_submitted' => 'boolean',
        'charges_enabled' => 'boolean',
        'payouts_enabled' => 'boolean',
        'requirements' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopePending($query)  
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeOnboarding($query)
    {
        return $query->where('status', self::STATUS_ONBOARDING);
    }

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }

    public function canAcceptPayments(): bool
    {
        // Allow payments if charges are enabled, even if account is restricted
        // Full payouts may be delayed until verification is complete
        return ($this->status === self::STATUS_ACTIVE || $this->status === self::STATUS_RESTRICTED) 
            && $this->charges_enabled;
    }

    public function canReceivePayouts(): bool
    {
        return $this->isActive() && $this->charges_enabled && $this->payouts_enabled;
    }

    public function needsOnboarding(): bool
    {
        return !$this->details_submitted;
    }

    public function getRequirementsAttribute($value): array
    {
        return $value ? json_decode($value, true) : [];
    }

    public function setRequirementsAttribute($value): void
    {
        $this->attributes['requirements'] = is_array($value) ? json_encode($value) : $value;
    }
}