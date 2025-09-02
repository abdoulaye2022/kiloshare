<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class UserReview extends Model
{
    use SoftDeletes;

    protected $table = 'user_reviews';

    protected $fillable = [
        'reviewer_id',
        'reviewed_user_id',
        'booking_id',
        'trip_id',
        'rating',
        'title',
        'comment',
        'is_public',
        'response',
        'response_date',
    ];

    protected $casts = [
        'reviewer_id' => 'integer',
        'reviewed_user_id' => 'integer',
        'booking_id' => 'integer',
        'trip_id' => 'integer',
        'rating' => 'integer',
        'is_public' => 'boolean',
        'response_date' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at', 'response_date'];

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewer_id');
    }

    public function reviewedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_user_id');
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    public function scopePublic($query)
    {
        return $query->where('is_public', true);
    }

    public function scopeByRating($query, int $rating)
    {
        return $query->where('rating', $rating);
    }

    public function scopePositive($query)
    {
        return $query->where('rating', '>=', 4);
    }

    public function scopeNegative($query)
    {
        return $query->where('rating', '<=', 2);
    }

    public function addResponse(string $response): bool
    {
        $this->response = $response;
        $this->response_date = now();
        return $this->save();
    }
}