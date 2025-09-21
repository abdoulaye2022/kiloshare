<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Carbon\Carbon;

class VerificationCode extends Model
{
    protected $table = 'verification_codes';

    protected $fillable = [
        'user_id',
        'booking_id',
        'code',
        'type',
        'expires_at',
        'is_used',
        'attempts'
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'is_used' => 'boolean',
        'attempts' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Types de codes de vérification
    const TYPE_PHONE_VERIFICATION = 'phone_verification';
    const TYPE_EMAIL_VERIFICATION = 'email_verification';
    const TYPE_PASSWORD_RESET = 'password_reset';
    const TYPE_PICKUP_CODE = 'pickup_code';
    const TYPE_DELIVERY_CODE = 'delivery_code';

    // Relations
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    // Méthodes utilitaires
    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    public function isValid(): bool
    {
        return !$this->is_used && !$this->isExpired();
    }

    public function markAsUsed(): void
    {
        $this->update(['is_used' => true]);
    }

    public function incrementAttempts(): void
    {
        $this->increment('attempts');
    }

    /**
     * Générer un nouveau code de vérification
     */
    public static function generate(
        int $userId, 
        string $type, 
        int $length = 6, 
        ?int $bookingId = null,
        ?Carbon $expiresAt = null
    ): self {
        // Générer un code unique
        do {
            $code = str_pad((string)mt_rand(0, pow(10, $length) - 1), $length, '0', STR_PAD_LEFT);
            $exists = self::where('code', $code)
                ->where('type', $type)
                ->where('is_used', false)
                ->exists();
        } while ($exists);

        // Définir l'expiration par défaut si non fournie
        if (!$expiresAt) {
            $expiresAt = match($type) {
                self::TYPE_PICKUP_CODE, self::TYPE_DELIVERY_CODE => Carbon::now()->addDays(30),
                self::TYPE_PASSWORD_RESET => Carbon::now()->addHours(2),
                default => Carbon::now()->addMinutes(10)
            };
        }

        return self::create([
            'user_id' => $userId,
            'booking_id' => $bookingId,
            'code' => $code,
            'type' => $type,
            'expires_at' => $expiresAt,
            'is_used' => false,
            'attempts' => 0
        ]);
    }

    /**
     * Vérifier un code
     */
    public static function verify(string $code, string $type, ?int $bookingId = null): ?self
    {
        $query = self::where('code', $code)
            ->where('type', $type)
            ->where('is_used', false);

        if ($bookingId) {
            $query->where('booking_id', $bookingId);
        }

        $verification = $query->first();

        if (!$verification) {
            return null;
        }

        if ($verification->isExpired()) {
            return null;
        }

        return $verification;
    }

    // Scopes
    public function scopeForBooking($query, int $bookingId)
    {
        return $query->where('booking_id', $bookingId);
    }

    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    public function scopeOfType($query, string $type)
    {
        return $query->where('type', $type);
    }

    public function scopeValid($query)
    {
        return $query->where('is_used', false)
                    ->where(function($q) {
                        $q->whereNull('expires_at')
                          ->orWhere('expires_at', '>', Carbon::now());
                    });
    }
}