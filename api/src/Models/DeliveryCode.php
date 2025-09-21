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
        'generated_at',
        'expires_at',
        'used_at',
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

        static::created(function ($deliveryCode) {
            // Enregistrer dans l'historique
            $deliveryCode->recordHistory(self::ACTION_GENERATED);
        });
    }

    // Relations
    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function attempts(): HasMany
    {
        return $this->hasMany(DeliveryCodeAttempt::class);
    }

    public function history(): HasMany
    {
        return $this->hasMany(DeliveryCodeHistory::class, 'booking_id', 'booking_id');
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
            $this->recordHistory(self::ACTION_EXPIRED, null, 'Nombre maximum de tentatives atteint');
        }

        $this->save();
    }

    public function markAsUsed(float $latitude = null, float $longitude = null, array $photos = []): void
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
        $this->recordHistory(self::ACTION_USED);

        // Marquer la réservation comme livrée
        $this->booking->delivery_confirmed_at = Carbon::now();
        $this->booking->save();
    }

    public function regenerate(int $userId = null, string $reason = null): self
    {
        // Marquer l'ancien code comme régénéré
        $oldCode = $this->code;
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

        // Enregistrer dans l'historique
        DeliveryCodeHistory::create([
            'booking_id' => $this->booking_id,
            'old_code' => $oldCode,
            'new_code' => $newDeliveryCode->code,
            'action' => self::ACTION_REGENERATED,
            'triggered_by_user_id' => $userId,
            'reason' => $reason ?? 'Code régénéré sur demande',
        ]);

        return $newDeliveryCode;
    }

    public function recordHistory(string $action, int $userId = null, string $reason = null): void
    {
        DeliveryCodeHistory::create([
            'booking_id' => $this->booking_id,
            'old_code' => null,
            'new_code' => $this->code,
            'action' => $action,
            'triggered_by_user_id' => $userId,
            'reason' => $reason,
        ]);
    }

    public function validateAttempt(string $inputCode, int $userId, float $latitude = null, float $longitude = null): array
    {
        // Enregistrer la tentative
        $attempt = DeliveryCodeAttempt::create([
            'delivery_code_id' => $this->id,
            'attempted_code' => $inputCode,
            'user_id' => $userId,
            'attempt_latitude' => $latitude,
            'attempt_longitude' => $longitude,
            'success' => false,
        ]);

        // Vérifier si le code est encore valide
        if (!$this->isValid()) {
            $errorMessage = $this->isExpired() ? 'Code expiré' : 'Code invalide';
            $attempt->update([
                'error_message' => $errorMessage,
            ]);
            return [
                'success' => false,
                'error' => $errorMessage,
                'attempts_remaining' => max(0, $this->max_attempts - $this->attempts_count),
            ];
        }

        // Vérifier le code
        if ($inputCode !== $this->code) {
            $this->incrementAttempts();
            $attempt->update([
                'error_message' => 'Code incorrect',
            ]);

            return [
                'success' => false,
                'error' => 'Code incorrect',
                'attempts_remaining' => max(0, $this->max_attempts - $this->attempts_count),
            ];
        }

        // Code correct
        $attempt->update(['success' => true]);

        return [
            'success' => true,
            'message' => 'Code validé avec succès',
            'attempt_id' => $attempt->id,
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