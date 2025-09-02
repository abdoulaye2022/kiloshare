<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TripFavorite extends Model
{
    protected $table = 'trip_favorites';
    
    // Désactiver les timestamps automatiques car la table n'a pas created_at/updated_at
    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'trip_id',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'trip_id' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    public static function toggleFavorite(int $userId, int $tripId): bool
    {
        $favorite = self::where('user_id', $userId)
                       ->where('trip_id', $tripId)
                       ->first();

        if ($favorite) {
            $favorite->delete();
            return false;
        } else {
            self::create([
                'user_id' => $userId,
                'trip_id' => $tripId,
            ]);
            return true;
        }
    }

    public static function isFavorite(int $userId, int $tripId): bool
    {
        return self::where('user_id', $userId)
                   ->where('trip_id', $tripId)
                   ->exists();
    }
}