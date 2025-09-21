<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class TripReport extends Model
{
    use SoftDeletes;

    protected $table = 'trip_reports';

    const STATUS_PENDING = 'pending';
    const STATUS_REVIEWING = 'reviewing';
    const STATUS_RESOLVED = 'resolved';
    const STATUS_DISMISSED = 'dismissed';

    const TYPE_INAPPROPRIATE = 'inappropriate';
    const TYPE_SPAM = 'spam';
    const TYPE_FRAUD = 'fraud';
    const TYPE_ILLEGAL = 'illegal';
    const TYPE_OTHER = 'other';

    protected $fillable = [
        'trip_id',
        'reporter_id',
        'report_type',
        'reason',
        'description',
        'status',
        'admin_notes',
        'resolved_at',
    ];

    protected $casts = [
        'trip_id' => 'integer',
        'reporter_id' => 'integer',
        'resolved_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at', 'resolved_at'];

    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeReviewing($query)
    {
        return $query->where('status', self::STATUS_REVIEWING);
    }

    public function markAsReviewing(?string $adminNotes = null): bool
    {
        $this->status = self::STATUS_REVIEWING;
        if ($adminNotes) {
            $this->admin_notes = $adminNotes;
        }
        return $this->save();
    }

    public function resolve(?string $adminNotes = null): bool
    {
        $this->status = self::STATUS_RESOLVED;
        $this->resolved_at = now();
        if ($adminNotes) {
            $this->admin_notes = $adminNotes;
        }
        return $this->save();
    }

    public function dismiss(?string $adminNotes = null): bool
    {
        $this->status = self::STATUS_DISMISSED;
        $this->resolved_at = now();
        if ($adminNotes) {
            $this->admin_notes = $adminNotes;
        }
        return $this->save();
    }
}