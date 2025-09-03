<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Carbon\Carbon;

class EmailVerification extends Model
{
    protected $table = 'email_verifications';
    public $timestamps = false; // Disable automatic timestamps
    
    protected $fillable = [
        'user_id',
        'token',
        'is_used',
        'expires_at',
        'used_at'
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
        'is_used' => 'boolean',
    ];

    /**
     * Générer un code de vérification unique
     */
    public static function generateCode(): string
    {
        return bin2hex(random_bytes(32)); // 64 caractères hexadécimaux
    }

    /**
     * Créer une nouvelle vérification d'email
     */
    public static function createForUser(int $userId): self
    {
        // Supprimer les anciennes vérifications non utilisées
        self::where('user_id', $userId)
            ->where('is_used', false)
            ->delete();

        return self::create([
            'user_id' => $userId,
            'token' => self::generateCode(),
            'is_used' => false,
            'expires_at' => Carbon::now()->addHours(24), // Expire dans 24h
        ]);
    }

    /**
     * Vérifier si le code est valide et non expiré
     */
    public function isValid(): bool
    {
        return !$this->is_used && 
               $this->expires_at->isFuture();
    }

    /**
     * Marquer comme vérifié
     */
    public function markAsVerified(): void
    {
        $this->update([
            'is_used' => true,
            'used_at' => Carbon::now()
        ]);
    }

    /**
     * Relation avec l'utilisateur
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Trouver une vérification valide par code
     */
    public static function findValidByCode(string $code): ?self
    {
        return self::where('token', $code)
            ->where('is_used', false)
            ->where('expires_at', '>', Carbon::now())
            ->first();
    }

    /**
     * Accessor for code (compatibility)
     */
    public function getCodeAttribute(): string
    {
        return $this->token;
    }
}