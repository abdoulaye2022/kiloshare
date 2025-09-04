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
        'weight_kg',
        'proposed_price',
        'package_description',
        'pickup_address',
        'delivery_address',
        'pickup_date',
        'delivery_date',
        'special_instructions',
    ];

    protected $casts = [
        'weight_kg' => 'decimal:2',
        'proposed_price' => 'decimal:2',
        'final_price' => 'decimal:2',
        'commission_rate' => 'decimal:2',
        'commission_amount' => 'decimal:2',
        'pickup_date' => 'datetime',
        'delivery_date' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Statuts de réservation
    const STATUS_PENDING = 'pending';
    const STATUS_ACCEPTED = 'accepted';  // Changed from confirmed to match database
    const STATUS_CONFIRMED = 'accepted'; // Alias for backwards compatibility
    const STATUS_REJECTED = 'rejected';
    const STATUS_PAYMENT_PENDING = 'payment_pending';
    const STATUS_PAID = 'paid';
    const STATUS_IN_TRANSIT = 'in_transit';
    const STATUS_DELIVERED = 'delivered';
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
        return in_array($this->status, [self::STATUS_PENDING, self::STATUS_ACCEPTED])
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