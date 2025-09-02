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
        'weight',
        'price_per_kg',
        'total_price',
        'currency',
        'package_description',
        'pickup_address',
        'delivery_address',
        'pickup_notes',
        'delivery_notes',
        'requested_pickup_date',
        'requested_delivery_date',
        'confirmed_pickup_date',
        'confirmed_delivery_date',
        'payment_status',
        'payment_intent_id',
        'commission_rate',
        'commission_amount',
        'traveler_amount',
    ];

    protected $casts = [
        'weight' => 'decimal:2',
        'price_per_kg' => 'decimal:2',
        'total_price' => 'decimal:2',
        'commission_rate' => 'decimal:4',
        'commission_amount' => 'decimal:2',
        'traveler_amount' => 'decimal:2',
        'requested_pickup_date' => 'datetime',
        'requested_delivery_date' => 'datetime',
        'confirmed_pickup_date' => 'datetime',
        'confirmed_delivery_date' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Statuts de réservation
    const STATUS_PENDING = 'pending';
    const STATUS_CONFIRMED = 'confirmed';
    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_COMPLETED = 'completed';
    const STATUS_CANCELLED = 'cancelled';
    const STATUS_DISPUTED = 'disputed';

    // Statuts de paiement
    const PAYMENT_PENDING = 'pending';
    const PAYMENT_AUTHORIZED = 'authorized';
    const PAYMENT_CAPTURED = 'captured';
    const PAYMENT_FAILED = 'failed';
    const PAYMENT_REFUNDED = 'refunded';

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
            if (empty($booking->payment_status)) {
                $booking->payment_status = self::PAYMENT_PENDING;
            }
            if (empty($booking->currency)) {
                $booking->currency = 'EUR';
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

    public function negotiations(): HasMany
    {
        return $this->hasMany(BookingNegotiation::class);
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

    // Méthodes utilitaires
    public function canBeAcceptedBy(User $user): bool
    {
        return $this->status === self::STATUS_PENDING 
            && $this->trip->user_id === $user->id;
    }

    public function canBeCancelledBy(User $user): bool
    {
        return in_array($this->status, [self::STATUS_PENDING, self::STATUS_CONFIRMED])
            && ($this->user_id === $user->id || $this->trip->user_id === $user->id);
    }

    public function accept(): void
    {
        $this->status = self::STATUS_CONFIRMED;
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

    // Scopes
    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeConfirmed($query)
    {
        return $query->where('status', self::STATUS_CONFIRMED);
    }

    public function scopeActive($query)
    {
        return $query->whereIn('status', [
            self::STATUS_CONFIRMED,
            self::STATUS_IN_PROGRESS
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