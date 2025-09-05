<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Carbon\Carbon;

class User extends Model
{
    use SoftDeletes;

    protected $table = 'users';

    protected $fillable = [
        'uuid',
        'email',
        'phone',
        'password_hash',
        'first_name',
        'last_name',
        'gender',
        'date_of_birth',
        'nationality',
        'bio',
        'website',
        'profession',
        'company',
        'address_line1',
        'address_line2',
        'city',
        'state_province',
        'postal_code',
        'country',
        'preferred_language',
        'timezone',
        'emergency_contact_name',
        'emergency_contact_phone',
        'emergency_contact_relation',
        'profile_visibility',
        'newsletter_subscribed',
        'marketing_emails',
        'profile_picture',
        'status',
        'role',
        'is_verified',
        'email_verified_at',
        'phone_verified_at',
        'last_login_at',
        'social_provider',
        'social_id',
        'cancellation_count',
        'last_cancellation_date',
        'suspension_reason',
        'is_suspended',
    ];

    protected $hidden = [
        'password_hash',
        'remember_token',
    ];

    protected $casts = [
        'is_verified' => 'boolean',
        'newsletter_subscribed' => 'boolean',
        'marketing_emails' => 'boolean',
        'is_suspended' => 'boolean',
        'last_cancellation_date' => 'datetime',
        'date_of_birth' => 'date',
        'email_verified_at' => 'datetime',
        'phone_verified_at' => 'datetime',
        'last_login_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = [
        'email_verified_at',
        'phone_verified_at',
        'last_login_at',
        'created_at',
        'updated_at',
        'deleted_at',
    ];

    // Événements du modèle
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($user) {
            if (empty($user->uuid)) {
                $user->uuid = \Ramsey\Uuid\Uuid::uuid4()->toString();
            }
            if (empty($user->status)) {
                $user->status = 'active';
            }
            if (empty($user->role)) {
                $user->role = 'user';
            }
        });
    }

    // Relations
    public function profile(): HasOne
    {
        return $this->hasOne(UserProfile::class);
    }

    public function trips(): HasMany
    {
        return $this->hasMany(Trip::class);
    }

    public function sentBookings(): HasMany
    {
        return $this->hasMany(Booking::class, 'sender_id');
    }

    public function receivedBookings(): HasMany
    {
        return $this->hasMany(Booking::class, 'receiver_id');
    }

    // Relation pour obtenir tous les bookings de l'utilisateur (envoyés et reçus)
    public function allBookings()
    {
        return Booking::where('sender_id', $this->id)
                     ->orWhere('receiver_id', $this->id);
    }

    public function favorites(): HasMany
    {
        return $this->hasMany(TripFavorite::class);
    }

    public function cancellationReports(): HasMany
    {
        return $this->hasMany(TripCancellationReport::class);
    }

    public function publicCancellationReports(): HasMany
    {
        return $this->hasMany(TripCancellationReport::class)
                    ->where('is_public', true)
                    ->where(function ($query) {
                        $query->whereNull('expires_at')
                              ->orWhere('expires_at', '>', now());
                    });
    }

    public function tokens(): HasMany
    {
        return $this->hasMany(UserToken::class);
    }

    public function sentMessages(): HasMany
    {
        return $this->hasMany(Message::class, 'sender_id');
    }

    public function receivedMessages(): HasMany
    {
        return $this->hasMany(Message::class, 'receiver_id');
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }

    public function givenReviews(): HasMany
    {
        return $this->hasMany(UserReview::class, 'reviewer_id');
    }

    public function receivedReviews(): HasMany
    {
        return $this->hasMany(UserReview::class, 'reviewed_user_id');
    }

    public function reportsMade(): HasMany
    {
        return $this->hasMany(TripReport::class, 'reporter_id');
    }

    // Accesseurs
    public function getFullNameAttribute(): string
    {
        return trim($this->first_name . ' ' . $this->last_name);
    }

    public function getIsAdminAttribute(): bool
    {
        return $this->role === 'admin';
    }

    public function getIsVerifiedAttribute(): bool
    {
        return (bool)($this->attributes['is_verified'] ?? false) && !is_null($this->email_verified_at);
    }

    // Méthodes utilitaires
    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    public function isBlocked(): bool
    {
        return $this->status === 'blocked';
    }

    public function isSuspended(): bool
    {
        return $this->status === 'suspended';
    }

    public function hasRole(string $role): bool
    {
        return $this->role === $role;
    }

    public function markEmailAsVerified(): void
    {
        $this->email_verified_at = Carbon::now();
        $this->is_verified = true;
        $this->save();
    }

    public function markPhoneAsVerified(): void
    {
        $this->phone_verified_at = Carbon::now();
        $this->save();
    }

    public function updateLastLogin(): void
    {
        $this->last_login_at = Carbon::now();
        $this->save();
    }

    public function block(): void
    {
        $this->status = 'blocked';
        $this->save();
    }

    public function unblock(): void
    {
        $this->status = 'active';
        $this->save();
    }

    public function suspend(): void
    {
        $this->status = 'suspended';
        $this->save();
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public function scopeVerified($query)
    {
        return $query->where('is_verified', true);
    }

    public function scopeAdmins($query)
    {
        return $query->where('role', 'admin');
    }

    public function scopeUsers($query)
    {
        return $query->where('role', 'user');
    }

    public function scopeWithEmail($query, string $email)
    {
        return $query->where('email', $email);
    }

    public function scopeWithPhone($query, string $phone)
    {
        return $query->where('phone', $phone);
    }
}