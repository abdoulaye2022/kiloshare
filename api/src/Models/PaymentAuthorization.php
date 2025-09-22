<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Carbon\Carbon;

class PaymentAuthorization extends Model
{
    protected $table = 'payment_authorizations';

    // Statuts d'autorisation
    const STATUS_PENDING = 'pending';           // En attente de confirmation par l'expéditeur
    const STATUS_PENDING_STRIPE_CONFIG = 'pending_stripe_config'; // En attente de configuration Stripe du transporteur
    const STATUS_CONFIRMED = 'confirmed';       // Confirmé par l'expéditeur, en attente de capture
    const STATUS_CAPTURED = 'captured';         // Montant capturé avec succès
    const STATUS_CANCELLED = 'cancelled';       // Annulé avant capture
    const STATUS_EXPIRED = 'expired';           // Expiré (4h de confirmation ou délai de capture dépassé)
    const STATUS_FAILED = 'failed';             // Échec de capture

    // Raisons de capture
    const CAPTURE_REASON_MANUAL = 'manual';     // Capture manuelle
    const CAPTURE_REASON_AUTO_72H = 'auto_72h'; // Capture automatique 72h avant
    const CAPTURE_REASON_AUTO_PICKUP = 'auto_pickup'; // Capture automatique à la récupération
    const CAPTURE_REASON_EXPIRED = 'expired';   // Capture d'expiration

    protected $fillable = [
        'booking_id',
        'payment_intent_id',
        'stripe_account_id',
        'amount_cents',
        'currency',
        'platform_fee_cents',
        'status',
        'confirmed_at',
        'expires_at',
        'captured_at',
        'cancelled_at',
        'confirmation_deadline',
        'auto_capture_at',
        'capture_reason',
        'capture_attempts',
        'last_capture_error',
    ];

    protected $casts = [
        'booking_id' => 'integer',
        'amount_cents' => 'integer',
        'platform_fee_cents' => 'integer',
        'capture_attempts' => 'integer',
        'confirmed_at' => 'datetime',
        'expires_at' => 'datetime',
        'captured_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'confirmation_deadline' => 'datetime',
        'auto_capture_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Relations
    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class, 'payment_authorization_id');
    }

    public function eventLogs(): HasMany
    {
        return $this->hasMany(PaymentEventLog::class, 'payment_authorization_id');
    }

    public function scheduledJobs(): HasMany
    {
        return $this->hasMany(ScheduledJob::class, 'payment_authorization_id');
    }

    // Scopes pour les requêtes
    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeConfirmed($query)
    {
        return $query->where('status', self::STATUS_CONFIRMED);
    }

    public function scopeReadyForCapture($query)
    {
        return $query->where('status', self::STATUS_CONFIRMED)
                    ->where('auto_capture_at', '<=', Carbon::now());
    }

    public function scopeExpired($query)
    {
        return $query->where('status', self::STATUS_PENDING)
                    ->where('confirmation_deadline', '<', Carbon::now());
    }

    public function scopeExpiredConfirmed($query)
    {
        return $query->where('status', self::STATUS_CONFIRMED)
                    ->where('expires_at', '<', Carbon::now());
    }

    // Méthodes de statut
    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isConfirmed(): bool
    {
        return $this->status === self::STATUS_CONFIRMED;
    }

    public function isCaptured(): bool
    {
        return $this->status === self::STATUS_CAPTURED;
    }

    public function isCancelled(): bool
    {
        return $this->status === self::STATUS_CANCELLED;
    }

    public function isExpired(): bool
    {
        return $this->status === self::STATUS_EXPIRED;
    }

    public function isFailed(): bool
    {
        return $this->status === self::STATUS_FAILED;
    }

    // Méthodes de validation de délais
    public function isConfirmationExpired(): bool
    {
        return $this->isPending() &&
               $this->confirmation_deadline &&
               $this->confirmation_deadline->isPast();
    }

    public function isCaptureExpired(): bool
    {
        return $this->isConfirmed() &&
               $this->expires_at &&
               $this->expires_at->isPast();
    }

    public function isReadyForAutoCapture(): bool
    {
        return $this->isConfirmed() &&
               $this->auto_capture_at &&
               $this->auto_capture_at->isPast();
    }

    public function canBeConfirmed(): bool
    {
        return $this->isPending() && !$this->isConfirmationExpired();
    }

    public function canBeCaptured(): bool
    {
        return $this->isConfirmed() && !$this->isCaptureExpired();
    }

    public function canBeCancelled(): bool
    {
        return in_array($this->status, [self::STATUS_PENDING, self::STATUS_CONFIRMED]);
    }

    // Méthodes de transition d'état
    public function confirm(): bool
    {
        if (!$this->canBeConfirmed()) {
            return false;
        }

        $this->status = self::STATUS_CONFIRMED;
        $this->confirmed_at = Carbon::now();

        // Calculer la date d'expiration pour la capture (72h avant le voyage ou 7 jours max)
        if ($this->booking && $this->booking->trip) {
            $tripDate = Carbon::parse($this->booking->trip->departure_date);
            $captureDeadline = $tripDate->copy()->subHours(72);
            $maxCaptureTime = Carbon::now()->addDays(7);

            $this->expires_at = $captureDeadline->min($maxCaptureTime);
            $this->auto_capture_at = $captureDeadline->copy()->subHours(1); // 1h avant la deadline
        } else {
            // Valeur par défaut si pas de voyage associé
            $this->expires_at = Carbon::now()->addDays(7);
            $this->auto_capture_at = Carbon::now()->addDays(6)->addHours(23);
        }

        return $this->save();
    }

    public function capture(string $reason = self::CAPTURE_REASON_MANUAL): bool
    {
        if (!$this->canBeCaptured()) {
            return false;
        }

        $this->status = self::STATUS_CAPTURED;
        $this->captured_at = Carbon::now();
        $this->capture_reason = $reason;

        return $this->save();
    }

    public function cancel(): bool
    {
        if (!$this->canBeCancelled()) {
            return false;
        }

        $this->status = self::STATUS_CANCELLED;
        $this->cancelled_at = Carbon::now();

        return $this->save();
    }

    public function expire(): bool
    {
        if ($this->isPending()) {
            $this->status = self::STATUS_EXPIRED;
        } elseif ($this->isConfirmed()) {
            $this->status = self::STATUS_EXPIRED;
        } else {
            return false;
        }

        return $this->save();
    }

    public function markAsFailed(?string $error = null): bool
    {
        $this->status = self::STATUS_FAILED;
        $this->capture_attempts++;

        if ($error) {
            $this->last_capture_error = $error;
        }

        return $this->save();
    }

    // Méthodes utilitaires
    public function getAmountInDollars(): float
    {
        return $this->amount_cents / 100;
    }

    public function getPlatformFeeInDollars(): float
    {
        return $this->platform_fee_cents / 100;
    }

    public function getNetAmountInDollars(): float
    {
        return ($this->amount_cents - $this->platform_fee_cents) / 100;
    }

    public function getRemainingConfirmationTime(): ?int
    {
        if (!$this->isPending() || !$this->confirmation_deadline) {
            return null;
        }

        return max(0, Carbon::now()->diffInMinutes($this->confirmation_deadline, false));
    }

    public function getRemainingCaptureTime(): ?int
    {
        if (!$this->isConfirmed() || !$this->expires_at) {
            return null;
        }

        return max(0, Carbon::now()->diffInMinutes($this->expires_at, false));
    }

    // Événement pour calculer les délais automatiquement
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($authorization) {
            // Définir la deadline de confirmation (4 heures par défaut)
            if (!$authorization->confirmation_deadline) {
                $authorization->confirmation_deadline = Carbon::now()->addHours(4);
            }
        });
    }
}