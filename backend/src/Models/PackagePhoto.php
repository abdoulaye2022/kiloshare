<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class PackagePhoto extends Model
{
    use SoftDeletes;

    protected $table = 'package_photos';

    protected $fillable = [
        'booking_id',
        'image_path',
        'url',
        'thumbnail',
        'description',
        'order',
        'file_size',
        'width',
        'height',
        'mime_type',
    ];

    protected $casts = [
        'booking_id' => 'integer',
        'order' => 'integer',
        'file_size' => 'integer',
        'width' => 'integer',
        'height' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $dates = ['deleted_at'];

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function scopeOrdered($query)
    {
        return $query->orderBy('order', 'asc');
    }
}