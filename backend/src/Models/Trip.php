<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Carbon\Carbon;

class Trip extends Model
{
    use SoftDeletes;

    protected $table = 'trips';

    protected $fillable = [
        'user_id',
        'uuid',
        'title',
        'description',
        'departure_city',
        'departure_country',
        'departure_date',
        'arrival_city',
        'arrival_country',
        'arrival_date',
        'transport_type',
        'available_weight_kg',
        'price_per_kg',
        'total_reward',
        'currency',
        'status',
        'is_domestic',
        'restrictions',
        'special_notes',
        'published_at',
        'expires_at',
    ];

    protected $casts = [
        'departure_date' => 'datetime',
        'arrival_date' => 'datetime',
        'published_at' => 'datetime',
        'expires_at' => 'datetime',
        'available_weight_kg' => 'decimal:2',
        'price_per_kg' => 'decimal:2',
        'total_reward' => 'decimal:2',
        'is_domestic' => 'boolean',
        'restrictions' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = [
        'departure_date',
        'arrival_date',
        'published_at',
        'expires_at',
        'created_at',
        'updated_at',
        'deleted_at',
    ];

    // Statuts possibles
    const STATUS_DRAFT = 'draft';
    const STATUS_PENDING_APPROVAL = 'pending_review';
    const STATUS_PUBLISHED = 'published';
    const STATUS_ACTIVE = 'active';
    const STATUS_REJECTED = 'rejected';
    const STATUS_PAUSED = 'paused';
    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_COMPLETED = 'completed';
    const STATUS_CANCELLED = 'cancelled';
    const STATUS_EXPIRED = 'expired';

    // Types de transport
    const TRANSPORT_PLANE = 'plane';
    const TRANSPORT_TRAIN = 'train';
    const TRANSPORT_BUS = 'bus';
    const TRANSPORT_CAR = 'car';

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($trip) {
            if (empty($trip->uuid)) {
                $trip->uuid = \Ramsey\Uuid\Uuid::uuid4()->toString();
            }
            if (empty($trip->status)) {
                $trip->status = self::STATUS_DRAFT;
            }
            if (empty($trip->currency)) {
                $trip->currency = 'EUR';
            }
        });
    }

    // Relations
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function bookings(): HasMany
    {
        return $this->hasMany(Booking::class);
    }

    public function images(): HasMany
    {
        return $this->hasMany(TripImage::class)->ordered();
    }

    public function favorites(): HasMany
    {
        return $this->hasMany(TripFavorite::class);
    }

    public function reports(): HasMany
    {
        return $this->hasMany(TripReport::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(UserReview::class);
    }

    // Accesseurs
    public function getRouteAttribute(): string
    {
        return $this->departure_city . ' → ' . $this->arrival_city;
    }

    public function getDurationAttribute(): ?int
    {
        if (!$this->departure_date || !$this->arrival_date) {
            return null;
        }
        
        return $this->departure_date->diffInMinutes($this->arrival_date);
    }

    public function getIsExpiredAttribute(): bool
    {
        return $this->expires_at && $this->expires_at->isPast();
    }

    public function getIsActiveAttribute(): bool
    {
        return in_array($this->status, [
            self::STATUS_PUBLISHED,
            self::STATUS_IN_PROGRESS
        ]);
    }

    public function getAvailableWeightAttribute(): float
    {
        // Temporaire : retourner available_weight_kg si pas de colonne weight dans bookings
        try {
            $bookedWeight = $this->bookings()
                ->whereIn('status', ['confirmed', 'in_progress', 'completed'])
                ->sum('weight');
            return max(0.0, (float)$this->available_weight_kg - (float)$bookedWeight);
        } catch (\Exception $e) {
            // Si erreur SQL, retourner available_weight_kg par défaut
            return (float)($this->available_weight_kg ?? 0);
        }
    }

    // Méthodes utilitaires
    public function isOwner(User $user): bool
    {
        return $this->user_id === $user->id;
    }

    public function canBeBookedBy(User $user): bool
    {
        return $this->status === self::STATUS_PUBLISHED
            && !$this->isExpired
            && $this->user_id !== $user->id
            && $this->available_weight > 0;
    }

    public function publish(): void
    {
        $this->status = self::STATUS_PUBLISHED;
        $this->published_at = Carbon::now();
        
        if (!$this->expires_at) {
            $this->expires_at = Carbon::now()->addDays(30);
        }
        
        $this->save();
    }

    public function pause(): void
    {
        if ($this->status === self::STATUS_PUBLISHED) {
            $this->status = self::STATUS_PAUSED;
            $this->save();
        }
    }

    public function resume(): void
    {
        if ($this->status === self::STATUS_PAUSED) {
            $this->status = self::STATUS_PUBLISHED;
            $this->save();
        }
    }

    public function cancel(): void
    {
        $this->status = self::STATUS_CANCELLED;
        $this->save();
    }

    public function complete(): void
    {
        $this->status = self::STATUS_COMPLETED;
        $this->save();
    }

    public function markAsExpired(): void
    {
        $this->status = self::STATUS_EXPIRED;
        $this->save();
    }

    // Scopes
    public function scopePublished($query)
    {
        return $query->where('status', self::STATUS_PUBLISHED);
    }

    public function scopeActive($query)
    {
        return $query->whereIn('status', [
            self::STATUS_PUBLISHED,
            self::STATUS_IN_PROGRESS
        ]);
    }

    public function scopeNotExpired($query)
    {
        return $query->where(function ($q) {
            $q->whereNull('expires_at')
              ->orWhere('expires_at', '>', Carbon::now());
        });
    }

    public function scopeWithAvailableSpace($query)
    {
        return $query->where('available_weight_kg', '>', 0);
    }

    public function scopeByRoute($query, string $departure, string $arrival)
    {
        return $query->where('departure_city', 'like', "%{$departure}%")
                    ->where('arrival_city', 'like', "%{$arrival}%");
    }

    public function scopeByTransport($query, string $transport)
    {
        return $query->where('transport_type', $transport);
    }

    public function scopeByDateRange($query, Carbon $from, Carbon $to)
    {
        return $query->whereBetween('departure_date', [$from, $to]);
    }

    public function scopeOrderByRelevance($query)
    {
        return $query->orderBy('published_at', 'desc')
                    ->orderBy('departure_date', 'asc');
    }
}