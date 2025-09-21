<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserStripeAccount extends Model
{
    protected $table = 'user_stripe_accounts';
    
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
        'details_submitted' => 'boolean',
        'charges_enabled' => 'boolean',
        'payouts_enabled' => 'boolean',
        'requirements' => 'json',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    public function scopeRestricted($query)
    {
        return $query->where('status', 'restricted');
    }

    public function isActive(): bool
    {
        return $this->status === 'active' && $this->charges_enabled && $this->payouts_enabled;
    }

    public function getCapabilities(): array
    {
        return [
            'card_payments' => $this->charges_enabled ? 'active' : 'inactive',
            'transfers' => $this->payouts_enabled ? 'active' : 'inactive',
        ];
    }

    /**
     * Check if the account can accept payments
     */
    public function canAcceptPayments(): bool
    {
        return $this->isActive() && 
               $this->details_submitted && 
               $this->charges_enabled && 
               $this->payouts_enabled;
    }
}