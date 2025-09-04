<?php

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class BookingNegotiation extends Model
{
    protected $table = 'booking_negotiations';
    
    protected $fillable = [
        'trip_id',
        'sender_id', 
        'status',
        'proposed_weight',
        'proposed_price',
        'package_description',
        'pickup_address',
        'delivery_address',
        'special_instructions',
        'messages',
        'counter_offer_price',
        'counter_offer_message',
        'expires_at'
    ];

    protected $casts = [
        'proposed_weight' => 'decimal:2',
        'proposed_price' => 'decimal:2',
        'counter_offer_price' => 'decimal:2',
        'messages' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'expires_at' => 'datetime'
    ];

    // Constantes pour les statuts
    const STATUS_PENDING = 'pending';
    const STATUS_ACCEPTED = 'accepted';
    const STATUS_REJECTED = 'rejected';
    const STATUS_COUNTER_PROPOSED = 'counter_proposed';

    /**
     * Relation avec le voyage
     */
    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    /**
     * Relation avec l'expéditeur
     */
    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /**
     * Relation avec la réservation finale (si acceptée)
     */
    public function booking(): HasOne
    {
        return $this->hasOne(Booking::class, 'booking_negotiation_id');
    }

    /**
     * Vérifier si la négociation est expirée
     */
    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    /**
     * Accepter la négociation
     */
    public function accept(): bool
    {
        if ($this->isExpired() || $this->status !== self::STATUS_PENDING) {
            return false;
        }

        $this->update(['status' => self::STATUS_ACCEPTED]);
        
        // Créer automatiquement la réservation
        $this->createBookingFromNegotiation();
        
        return true;
    }

    /**
     * Rejeter la négociation
     */
    public function reject(): bool
    {
        if ($this->isExpired() || $this->status !== self::STATUS_PENDING) {
            return false;
        }

        return $this->update(['status' => self::STATUS_REJECTED]);
    }

    /**
     * Faire une contre-proposition
     */
    public function counterPropose(float $counterPrice, ?string $message = null): bool
    {
        if ($this->isExpired() || $this->status !== self::STATUS_PENDING) {
            return false;
        }

        return $this->update([
            'status' => self::STATUS_COUNTER_PROPOSED,
            'counter_offer_price' => $counterPrice,
            'counter_offer_message' => $message
        ]);
    }

    /**
     * Ajouter un message à la négociation
     */
    public function addMessage(int $senderId, string $message): bool
    {
        $messages = $this->messages ?? [];
        $messages[] = [
            'sender_id' => $senderId,
            'message' => $message,
            'timestamp' => now()->toISOString()
        ];

        return $this->update(['messages' => $messages]);
    }

    /**
     * Créer une réservation à partir de la négociation acceptée
     */
    private function createBookingFromNegotiation(): Booking
    {
        $booking = Booking::create([
            'trip_id' => $this->trip_id,
            'booking_negotiation_id' => $this->id,
            'sender_id' => $this->sender_id,
            'receiver_id' => $this->trip->user_id,
            'package_description' => $this->package_description,
            'weight_kg' => $this->proposed_weight,
            'proposed_price' => $this->proposed_price,
            'final_price' => $this->counter_offer_price ?? $this->proposed_price,
            'status' => Booking::STATUS_CONFIRMED,
            'payment_status' => 'pending',
            'pickup_address' => $this->pickup_address,
            'delivery_address' => $this->delivery_address,
            'special_instructions' => $this->special_instructions
        ]);

        // Mettre à jour le statut du trip
        $this->trip->update(['status' => Trip::STATUS_BOOKED]);

        return $booking;
    }

    /**
     * Scope pour les négociations actives
     */
    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_PENDING)
                    ->where(function($q) {
                        $q->whereNull('expires_at')
                          ->orWhere('expires_at', '>', now());
                    });
    }

    /**
     * Scope pour les négociations d'un voyage spécifique
     */
    public function scopeForTrip($query, int $tripId)
    {
        return $query->where('trip_id', $tripId);
    }

    /**
     * Scope pour les négociations d'un expéditeur spécifique
     */
    public function scopeFromSender($query, int $senderId)
    {
        return $query->where('sender_id', $senderId);
    }
}