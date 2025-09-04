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
    const STATUS_BOOKED = 'booked';
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
        try {
            $bookedWeight = $this->bookings()
                ->whereIn('status', ['confirmed', 'in_progress', 'completed'])
                ->sum('weight_kg');
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
        $bookableStatuses = [
            self::STATUS_PUBLISHED,
            self::STATUS_ACTIVE,
        ];
        
        return in_array($this->status, $bookableStatuses)
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
        if ($this->status !== self::STATUS_ACTIVE) {
            throw new \Exception('Only active trips can be paused');
        }
        $this->status = self::STATUS_PAUSED;
        $this->paused_at = Carbon::now();
        $this->save();
    }

    public function resume(): void
    {
        if ($this->status !== self::STATUS_PAUSED) {
            throw new \Exception('Only paused trips can be resumed');
        }
        $this->status = self::STATUS_ACTIVE;
        $this->paused_at = null;
        $this->save();
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

    // === STATE TRANSITION ACTIONS ===

    /**
     * Submit draft for review (draft → pending_review)
     */
    public function submitForReview(): void
    {
        if ($this->status !== self::STATUS_DRAFT) {
            throw new \Exception('Only draft trips can be submitted for review');
        }
        $this->status = self::STATUS_PENDING_APPROVAL;
        $this->save();
    }

    /**
     * Approve pending review (pending_review → active)
     */
    public function approve(): void
    {
        if ($this->status !== self::STATUS_PENDING_APPROVAL) {
            throw new \Exception('Only trips pending review can be approved');
        }
        $this->status = self::STATUS_ACTIVE;
        $this->published_at = Carbon::now();
        
        if (!$this->expires_at) {
            $this->expires_at = Carbon::now()->addDays(30);
        }
        
        $this->save();
    }

    /**
     * Reject pending review (pending_review → rejected)
     */
    public function reject(?string $reason = null): void
    {
        if ($this->status !== self::STATUS_PENDING_APPROVAL) {
            throw new \Exception('Only trips pending review can be rejected');
        }
        $this->status = self::STATUS_REJECTED;
        if ($reason) {
            $this->rejection_reason = $reason;
        }
        $this->save();
    }

    /**
     * Modify rejected trip back to draft (rejected → draft)
     */
    public function backToDraft(): void
    {
        if ($this->status !== self::STATUS_REJECTED) {
            throw new \Exception('Only rejected trips can be sent back to draft');
        }
        $this->status = self::STATUS_DRAFT;
        $this->rejection_reason = null;
        $this->save();
    }

    /**
     * Mark as booked (active → booked)
     */
    public function markAsBooked(): void
    {
        if ($this->status !== self::STATUS_ACTIVE) {
            throw new \Exception('Only active trips can be marked as booked');
        }
        $this->status = self::STATUS_BOOKED;
        $this->save();
    }

    /**
     * Start trip journey (booked → in_progress)
     */
    public function startJourney(): void
    {
        if ($this->status !== self::STATUS_BOOKED) {
            throw new \Exception('Only booked trips can start their journey');
        }
        $this->status = self::STATUS_IN_PROGRESS;
        $this->save();
    }

    /**
     * Complete trip delivery (in_progress → completed)
     */
    public function completeDelivery(): void
    {
        if ($this->status !== self::STATUS_IN_PROGRESS) {
            throw new \Exception('Only trips in progress can be completed');
        }
        $this->status = self::STATUS_COMPLETED;
        $this->save();
    }

    /**
     * Reactivate paused trip (paused → active)
     */
    public function reactivate(): void
    {
        if ($this->status !== self::STATUS_PAUSED) {
            throw new \Exception('Only paused trips can be reactivated');
        }
        $this->status = self::STATUS_ACTIVE;
        $this->paused_at = null;
        $this->save();
    }

    /**
     * Get available actions based on current status
     */
    public function getAvailableActions(): array
    {
        $actions = [];

        switch ($this->status) {
            case self::STATUS_DRAFT:
                $actions = ['submit_for_review'];
                break;

            case self::STATUS_PENDING_APPROVAL:
                $actions = ['approve', 'reject'];
                break;

            case self::STATUS_REJECTED:
                $actions = ['back_to_draft'];
                break;

            case self::STATUS_ACTIVE:
                $actions = ['pause', 'cancel', 'mark_as_booked'];
                // Check if expired
                if ($this->is_expired) {
                    $actions[] = 'mark_as_expired';
                }
                break;

            case self::STATUS_PAUSED:
                $actions = ['reactivate'];
                break;

            case self::STATUS_BOOKED:
                $actions = ['start_journey', 'cancel'];
                break;

            case self::STATUS_IN_PROGRESS:
                $actions = ['complete_delivery'];
                break;

            case self::STATUS_COMPLETED:
            case self::STATUS_CANCELLED:
            case self::STATUS_EXPIRED:
                $actions = []; // Terminal states
                break;
        }

        return $actions;
    }

    /**
     * Check if a specific action is allowed
     */
    public function canPerformAction(string $action): bool
    {
        return in_array($action, $this->getAvailableActions());
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
            self::STATUS_ACTIVE,
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