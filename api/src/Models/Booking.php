<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Carbon\Carbon;

class Booking extends Model
{
    protected $table = 'bookings';

    protected $fillable = [
        'sender_id', // Utilisateur qui envoie le colis
        'receiver_id', // Propriétaire du voyage (qui reçoit le colis)
        'trip_id',
        'uuid',
        'status',
        'payment_status',
        'weight_kg',
        'proposed_price',
        'final_price',
        'payment_authorization_id',
        'payment_authorized_at',
        'payment_confirmed_at',
        'payment_captured_at',
        'package_description',
        'pickup_address',
        'delivery_address',
        'pickup_date',
        'delivery_date',
        'special_instructions',
        'cancelled_at',
        'cancellation_type',
        'cancellation_reason',
        'rejection_reason',
    ];

    protected $casts = [
        'weight_kg' => 'decimal:2',
        'proposed_price' => 'decimal:2',
        'final_price' => 'decimal:2',
        'commission_rate' => 'decimal:2',
        'commission_amount' => 'decimal:2',
        'pickup_date' => 'datetime',
        'delivery_date' => 'datetime',
        'cancelled_at' => 'datetime',
        'payment_authorized_at' => 'datetime',
        'payment_confirmed_at' => 'datetime',
        'payment_captured_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Statuts de réservation - Système de capture différée
    const STATUS_PENDING = 'pending';                    // En attente d'acceptation
    const STATUS_ACCEPTED = 'accepted';                  // Acceptée, en attente de paiement
    const STATUS_CONFIRMED = 'accepted';                 // Alias pour compatibilité
    const STATUS_REJECTED = 'rejected';                  // Refusée
    const STATUS_PAYMENT_AUTHORIZED = 'payment_authorized';     // Paiement autorisé, en attente de confirmation
    const STATUS_PAYMENT_CONFIRMED = 'payment_confirmed';      // Paiement confirmé, en attente de capture
    const STATUS_PAYMENT_PENDING = 'payment_pending';          // Ancien statut (déprécié)
    const STATUS_PAID = 'paid';                         // Paiement capturé avec succès
    const STATUS_IN_TRANSIT = 'in_transit';             // En cours de transport
    const STATUS_IN_PROGRESS = 'in_progress';           // Ancien statut (alias de in_transit)
    const STATUS_DELIVERED = 'delivered';               // Livré (avec code de livraison)
    const STATUS_COMPLETED = 'completed';               // Terminé et validé
    const STATUS_CANCELLED = 'cancelled';               // Annulé
    const STATUS_PAYMENT_FAILED = 'payment_failed';     // Échec de paiement
    const STATUS_PAYMENT_EXPIRED = 'payment_expired';   // Paiement expiré
    const STATUS_PAYMENT_CANCELLED = 'payment_cancelled'; // Paiement annulé
    const STATUS_REFUNDED = 'refunded';                 // Remboursé
    const STATUS_DISPUTED = 'disputed';                 // En litige

    // Statuts de paiement
    const PAYMENT_PENDING = 'pending';
    const PAYMENT_AUTHORIZED = 'authorized';
    const PAYMENT_CAPTURED = 'captured';
    const PAYMENT_FAILED = 'failed';
    const PAYMENT_REFUNDED = 'refunded';

    // Types d'annulation
    const CANCELLATION_EARLY = 'early';      // Plus de 24h avant
    const CANCELLATION_LATE = 'late';        // Moins de 24h avant
    const CANCELLATION_NO_SHOW = 'no_show';  // Non-présentation
    const CANCELLATION_BY_TRAVELER = 'by_traveler'; // Annulé par le voyageur
    const CANCELLATION_BY_SENDER = 'by_sender';     // Annulé par l'expéditeur

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($booking) {
            if (empty($booking->uuid)) {
                $booking->uuid = \Ramsey\Uuid\Uuid::uuid4()->toString();
            }
            if (empty($booking->status)) {
                $booking->status = self::STATUS_PENDING;
            }
        });
    }

    // Relations
    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function receiver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'receiver_id');
    }

    // Alias pour compatibilité - retourne le sender par défaut
    public function user(): BelongsTo
    {
        return $this->sender();
    }

    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }


    public function packagePhotos(): HasMany
    {
        return $this->hasMany(PackagePhoto::class)->ordered();
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function paymentAuthorization(): BelongsTo
    {
        return $this->belongsTo(PaymentAuthorization::class, 'payment_authorization_id');
    }

    public function deliveryCode(): HasOne
    {
        return $this->hasOne(DeliveryCode::class);
    }

    // Méthodes utilitaires
    public function canBeAcceptedBy(User $user): bool
    {
        return $this->status === self::STATUS_PENDING 
            && $this->trip->user_id === $user->id;
    }

    public function canBeCancelledBy(User $user): bool
    {
        $cancellableStatuses = [
            self::STATUS_PENDING,
            self::STATUS_ACCEPTED,
            self::STATUS_PAYMENT_AUTHORIZED,
            self::STATUS_PAYMENT_CONFIRMED
        ];

        return in_array($this->status, $cancellableStatuses)
            && ($this->sender_id === $user->id || $this->receiver_id === $user->id);
    }

    public function accept(?float $finalPrice = null): void
    {
        $this->status = self::STATUS_ACCEPTED;
        if ($finalPrice !== null) {
            $this->final_price = $finalPrice;
        }
        $this->save();
    }

    public function cancel(): void
    {
        $this->status = self::STATUS_CANCELLED;
        $this->save();
    }

    public function markAsInProgress(): void
    {
        $this->status = self::STATUS_IN_PROGRESS;
        $this->save();
    }

    public function complete(): void
    {
        $this->status = self::STATUS_COMPLETED;
        $this->save();
    }

    // Nouvelles méthodes pour le système de capture différée
    public function authorizePayment(PaymentAuthorization $authorization): void
    {
        $this->status = self::STATUS_PAYMENT_AUTHORIZED;
        $this->payment_authorization_id = $authorization->id;
        $this->payment_authorized_at = now();
        $this->save();
    }

    public function confirmPayment(): void
    {
        $this->status = self::STATUS_PAYMENT_CONFIRMED;
        $this->payment_confirmed_at = now();
        $this->save();
    }

    public function capturePayment(): void
    {
        $this->status = self::STATUS_PAID;
        $this->payment_captured_at = now();
        $this->save();
    }

    public function markPaymentFailed(): void
    {
        $this->status = self::STATUS_PAYMENT_FAILED;
        $this->save();
    }

    public function markPaymentExpired(): void
    {
        $this->status = self::STATUS_PAYMENT_EXPIRED;
        $this->save();
    }

    public function markPaymentCancelled(): void
    {
        $this->status = self::STATUS_PAYMENT_CANCELLED;
        $this->save();
    }

    public function refund(): void
    {
        $this->status = self::STATUS_REFUNDED;
        $this->save();
    }

    // Méthodes de validation d'état
    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isAccepted(): bool
    {
        return $this->status === self::STATUS_ACCEPTED;
    }

    public function isPaymentAuthorized(): bool
    {
        return $this->status === self::STATUS_PAYMENT_AUTHORIZED;
    }

    public function isPaymentConfirmed(): bool
    {
        return $this->status === self::STATUS_PAYMENT_CONFIRMED;
    }

    public function isPaid(): bool
    {
        return $this->status === self::STATUS_PAID;
    }

    public function isInTransit(): bool
    {
        return $this->status === self::STATUS_IN_TRANSIT;
    }

    public function isDelivered(): bool
    {
        return $this->status === self::STATUS_DELIVERED;
    }

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isCancelled(): bool
    {
        return in_array($this->status, [
            self::STATUS_CANCELLED,
            self::STATUS_PAYMENT_CANCELLED,
            self::STATUS_PAYMENT_EXPIRED,
            self::STATUS_PAYMENT_FAILED
        ]);
    }

    public function isRefunded(): bool
    {
        return $this->status === self::STATUS_REFUNDED;
    }

    public function canBeAccepted(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function canBeRejected(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function canBePaymentAuthorized(): bool
    {
        return $this->status === self::STATUS_ACCEPTED;
    }

    public function canBePaymentConfirmed(): bool
    {
        return $this->status === self::STATUS_PAYMENT_AUTHORIZED;
    }

    public function canBePaymentCaptured(): bool
    {
        return $this->status === self::STATUS_PAYMENT_CONFIRMED;
    }

    public function canBeCancelledWithRefund(): bool
    {
        return in_array($this->status, [
            self::STATUS_ACCEPTED,
            self::STATUS_PAYMENT_AUTHORIZED,
            self::STATUS_PAYMENT_CONFIRMED
        ]);
    }

    public function requiresDeliveryCode(): bool
    {
        return $this->status === self::STATUS_IN_TRANSIT;
    }

    // Méthodes de workflow pour transitions d'état
    public function getAvailableTransitions(): array
    {
        switch ($this->status) {
            case self::STATUS_PENDING:
                return ['accept', 'reject'];
            case self::STATUS_ACCEPTED:
                return ['authorize_payment', 'cancel'];
            case self::STATUS_PAYMENT_AUTHORIZED:
                return ['confirm_payment', 'cancel_payment'];
            case self::STATUS_PAYMENT_CONFIRMED:
                return ['capture_payment', 'cancel_payment'];
            case self::STATUS_PAID:
                return ['start_transit'];
            case self::STATUS_IN_TRANSIT:
                return ['deliver', 'cancel'];
            case self::STATUS_DELIVERED:
                return ['complete'];
            default:
                return [];
        }
    }

    public function getStatusLabel(): string
    {
        $labels = [
            self::STATUS_PENDING => 'En attente',
            self::STATUS_ACCEPTED => 'Acceptée',
            self::STATUS_REJECTED => 'Refusée',
            self::STATUS_PAYMENT_AUTHORIZED => 'Paiement autorisé',
            self::STATUS_PAYMENT_CONFIRMED => 'Paiement confirmé',
            self::STATUS_PAID => 'Payée',
            self::STATUS_IN_TRANSIT => 'En transit',
            self::STATUS_DELIVERED => 'Livrée',
            self::STATUS_COMPLETED => 'Terminée',
            self::STATUS_CANCELLED => 'Annulée',
            self::STATUS_PAYMENT_FAILED => 'Paiement échoué',
            self::STATUS_PAYMENT_EXPIRED => 'Paiement expiré',
            self::STATUS_PAYMENT_CANCELLED => 'Paiement annulé',
            self::STATUS_REFUNDED => 'Remboursée',
            self::STATUS_DISPUTED => 'En litige',
        ];

        return $labels[$this->status] ?? $this->status;
    }

    // Scopes
    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeConfirmed($query)
    {
        return $query->where('status', self::STATUS_CONFIRMED);
    }

    public function scopeAccepted($query)
    {
        return $query->where('status', self::STATUS_ACCEPTED);
    }

    public function scopePaymentAuthorized($query)
    {
        return $query->where('status', self::STATUS_PAYMENT_AUTHORIZED);
    }

    public function scopePaymentConfirmed($query)
    {
        return $query->where('status', self::STATUS_PAYMENT_CONFIRMED);
    }

    public function scopePaid($query)
    {
        return $query->where('status', self::STATUS_PAID);
    }

    public function scopeInTransit($query)
    {
        return $query->where('status', self::STATUS_IN_TRANSIT);
    }

    public function scopeActive($query)
    {
        return $query->whereIn('status', [
            self::STATUS_ACCEPTED,
            self::STATUS_PAYMENT_AUTHORIZED,
            self::STATUS_PAYMENT_CONFIRMED,
            self::STATUS_PAID,
            self::STATUS_IN_TRANSIT,
            self::STATUS_DELIVERED
        ]);
    }

    public function scopeRequiringPaymentAction($query)
    {
        return $query->whereIn('status', [
            self::STATUS_PAYMENT_AUTHORIZED,
            self::STATUS_PAYMENT_CONFIRMED
        ]);
    }

    public function scopeCancelled($query)
    {
        return $query->whereIn('status', [
            self::STATUS_CANCELLED,
            self::STATUS_PAYMENT_CANCELLED,
            self::STATUS_PAYMENT_EXPIRED,
            self::STATUS_PAYMENT_FAILED
        ]);
    }

    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    public function scopeForTrip($query, int $tripId)
    {
        return $query->where('trip_id', $tripId);
    }
}