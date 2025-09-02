<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Carbon\Carbon;

class UserToken extends Model
{
    protected $table = 'user_tokens';

    protected $fillable = [
        'user_id',
        'token',
        'type',
        'expires_at',
        'used_at',
        'revoked_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
        'revoked_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    const TYPE_ACCESS = 'access';
    const TYPE_REFRESH = 'refresh';
    const TYPE_EMAIL_VERIFICATION = 'email_verification';
    const TYPE_PASSWORD_RESET = 'password_reset';

    // Relations
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // Méthodes utilitaires
    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    public function isValid(): bool
    {
        return !$this->isExpired() && !$this->used_at && !$this->revoked_at;
    }

    public function markAsUsed(): void
    {
        $this->used_at = Carbon::now();
        $this->save();
    }

    public function revoke(): void
    {
        $this->revoked_at = Carbon::now();
        $this->save();
    }

    // Scopes
    public function scopeValid($query)
    {
        return $query->where('expires_at', '>', Carbon::now())
                    ->whereNull('used_at')
                    ->whereNull('revoked_at');
    }

    public function scopeOfType($query, string $type)
    {
        return $query->where('type', $type);
    }

    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }
}