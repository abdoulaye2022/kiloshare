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

    protected $appends = ['image_url', 'thumbnail_url'];

    public function trip(): BelongsTo
    {
        return $this->belongsTo(Trip::class);
    }

    // Accesseur pour générer l'URL complète selon l'environnement
    public function getImageUrlAttribute(): ?string
    {
        if (empty($this->url)) {
            return null;
        }

        // Si c'est déjà une URL complète (anciennes données), la retourner telle quelle
        if (str_starts_with($this->url, 'http://') ||
            str_starts_with($this->url, 'https://')) {
            return $this->url;
        }

        // Sinon, générer l'URL via GoogleCloudStorageService
        try {
            $gcs = new \KiloShare\Services\GoogleCloudStorageService();
            return $gcs->getPublicUrl($this->url);
        } catch (\Exception $e) {
            error_log("Error generating trip image URL: " . $e->getMessage());
            return null;
        }
    }

    // Accesseur pour générer l'URL du thumbnail
    public function getThumbnailUrlAttribute(): ?string
    {
        if (empty($this->thumbnail)) {
            return null;
        }

        // Si c'est déjà une URL complète (anciennes données), la retourner telle quelle
        if (str_starts_with($this->thumbnail, 'http://') ||
            str_starts_with($this->thumbnail, 'https://')) {
            return $this->thumbnail;
        }

        // Sinon, générer l'URL via GoogleCloudStorageService
        try {
            $gcs = new \KiloShare\Services\GoogleCloudStorageService();
            return $gcs->getPublicUrl($this->thumbnail);
        } catch (\Exception $e) {
            error_log("Error generating thumbnail URL: " . $e->getMessage());
            return null;
        }
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