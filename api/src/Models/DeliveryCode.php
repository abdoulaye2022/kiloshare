<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Carbon\Carbon;

class DeliveryCode extends Model
{
    protected $table = 'delivery_codes';

    protected $fillable = [
        'booking_id',
        'code',
        'status',
        'attempts_count',
        'max_attempts',
        'generated_by',
        'generated_at',
        'expires_at',
        'used_at',
        'used_by',
        'delivery_latitude',
        'delivery_longitude',
        'delivery_photos',
        'verification_photos',
    ];

    protected $casts = [
        'generated_at' => 'datetime',
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
        'delivery_latitude' => 'decimal:8',
        'delivery_longitude' => 'decimal:8',
        'delivery_photos' => 'array',
        'verification_photos' => 'array',
        'attempts_count' => 'integer',
        'max_attempts' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Statuts possibles
    const STATUS_ACTIVE = 'active';
    const STATUS_USED = 'used';
    const STATUS_EXPIRED = 'expired';
    const STATUS_REGENERATED = 'regenerated';

    // Actions pour l'historique
    const ACTION_GENERATED = 'generated';
    const ACTION_REGENERATED = 'regenerated';
    const ACTION_EXPIRED = 'expired';
    const ACTION_USED = 'used';

    // Configuration par défaut
    const DEFAULT_MAX_ATTEMPTS = 3;
    const EXPIRY_HOURS_AFTER_ARRIVAL = 48;
    const CODE_LENGTH = 6;

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($deliveryCode) {
            if (empty($deliveryCode->code)) {
                $deliveryCode->code = self::generateSecureCode();
            }
            if (empty($deliveryCode->max_attempts)) {
                $deliveryCode->max_attempts = self::DEFAULT_MAX_ATTEMPTS;
            }
            if (empty($deliveryCode->generated_at)) {
                $deliveryCode->generated_at = Carbon::now();
            }
        });
    }

    // Relations
    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    // Méthodes utilitaires
    public static function generateSecureCode(): string
    {
        // Génération d'un code à 6 chiffres sécurisé
        $code = '';
        for ($i = 0; $i < self::CODE_LENGTH; $i++) {
            $code .= random_int(0, 9);
        }

        // Vérifier que le code n'existe pas déjà (très improbable mais sécurité)
        if (self::where('code', $code)->where('status', self::STATUS_ACTIVE)->exists()) {
            return self::generateSecureCode(); // Récursion en cas de conflit
        }

        return $code;
    }

    public function generateExpiryDate(): Carbon
    {
        // Expiration 48h après l'arrivée du voyage
        $trip = $this->booking->trip;
        $arrivalDate = Carbon::parse($trip->arrival_date);
        return $arrivalDate->addHours(self::EXPIRY_HOURS_AFTER_ARRIVAL);
    }

    public function setExpiryBasedOnTrip(): void
    {
        $this->expires_at = $this->generateExpiryDate();
        $this->save();
    }

    public function isValid(): bool
    {
        return $this->status === self::STATUS_ACTIVE &&
               $this->attempts_count < $this->max_attempts &&
               ($this->expires_at === null || $this->expires_at->isFuture());
    }

    public function isExpired(): bool
    {
        return $this->status === self::STATUS_EXPIRED ||
               ($this->expires_at !== null && $this->expires_at->isPast());
    }

    public function hasReachedMaxAttempts(): bool
    {
        return $this->attempts_count >= $this->max_attempts;
    }

    public function incrementAttempts(): void
    {
        $this->attempts_count++;

        if ($this->hasReachedMaxAttempts()) {
            $this->status = self::STATUS_EXPIRED;
        }

        $this->save();
    }

    public function markAsUsed(?float $latitude = null, ?float $longitude = null, array $photos = []): void
    {
        $this->status = self::STATUS_USED;
        $this->used_at = Carbon::now();

        if ($latitude !== null) {
            $this->delivery_latitude = $latitude;
        }
        if ($longitude !== null) {
            $this->delivery_longitude = $longitude;
        }
        if (!empty($photos)) {
            $this->verification_photos = $photos;
        }

        $this->save();

        // Marquer la réservation comme livrée
        $this->booking->delivery_confirmed_at = Carbon::now();
        $this->booking->save();
    }

    public function regenerate(?int $userId = null, ?string $reason = null): self
    {
        // Marquer l'ancien code comme régénéré
        $this->status = self::STATUS_REGENERATED;
        $this->save();

        // Créer un nouveau code
        $newDeliveryCode = new self([
            'booking_id' => $this->booking_id,
            'code' => self::generateSecureCode(),
            'status' => self::STATUS_ACTIVE,
            'max_attempts' => self::DEFAULT_MAX_ATTEMPTS,
            'attempts_count' => 0,
            'generated_at' => Carbon::now(),
        ]);

        $newDeliveryCode->setExpiryBasedOnTrip();
        $newDeliveryCode->save();

        return $newDeliveryCode;
    }

    public function validateAttempt(string $inputCode): array
    {
        // Vérifier si le code est encore valide
        if (!$this->isValid()) {
            $errorMessage = $this->isExpired() ? 'Code expiré' : 'Code invalide';
            return [
                'success' => false,
                'error' => $errorMessage,
                'attempts_remaining' => max(0, $this->max_attempts - $this->attempts_count),
            ];
        }

        // Vérifier le code
        if ($inputCode !== $this->code) {
            $this->incrementAttempts();

            return [
                'success' => false,
                'error' => 'Code incorrect',
                'attempts_remaining' => max(0, $this->max_attempts - $this->attempts_count),
            ];
        }

        // Code correct
        return [
            'success' => true,
            'message' => 'Code validé avec succès',
        ];
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopeValid($query)
    {
        return $query->where('status', self::STATUS_ACTIVE)
                    ->where('attempts_count', '<', 'max_attempts')
                    ->where(function ($q) {
                        $q->whereNull('expires_at')
                          ->orWhere('expires_at', '>', Carbon::now());
                    });
    }

    public function scopeForBooking($query, int $bookingId)
    {
        return $query->where('booking_id', $bookingId);
    }

    public function scopeExpired($query)
    {
        return $query->where(function ($q) {
            $q->where('status', self::STATUS_EXPIRED)
              ->orWhere('expires_at', '<=', Carbon::now())
              ->orWhereRaw('attempts_count >= max_attempts');
        });
    }

    // Méthodes de nettoyage automatique
    public static function cleanExpiredCodes(): int
    {
        $expiredCount = self::where('status', self::STATUS_ACTIVE)
            ->where(function ($query) {
                $query->where('expires_at', '<=', Carbon::now())
                      ->orWhereRaw('attempts_count >= max_attempts');
            })
            ->update(['status' => self::STATUS_EXPIRED]);

        return $expiredCount;
    }

    // Accesseurs
    public function getRemainingAttemptsAttribute(): int
    {
        return max(0, $this->max_attempts - $this->attempts_count);
    }

    public function getIsValidAttribute(): bool
    {
        return $this->isValid();
    }

    public function getIsExpiredAttribute(): bool
    {
        return $this->isExpired();
    }
}