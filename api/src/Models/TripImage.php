<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class TripImage extends Model
{
    use SoftDeletes;

    protected $table = 'trip_images';

    protected $fillable = [
        'trip_id',
        'image_path',
        'url',
        'thumbnail',
        'alt_text',
        'is_primary',
        'order',
        'file_size',
        'width',
        'height',
        'mime_type',
        'image_name',
    ];

    protected $casts = [
        'is_primary' => 'boolean',
        'order' => 'integer',
        'file_size' => 'integer',
        'width' => 'integer',
        'height' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at'];

    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    public function scopePrimary($query)
    {
        return $query->where('is_primary', true);
    }

    public function scopeOrdered($query)
    {
        return $query->orderBy('order', 'asc');
    }
}