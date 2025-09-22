<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;

class PaymentConfiguration extends Model
{
    protected $table = 'payment_configurations';

    protected $fillable = [
        'config_key',
        'config_value',
        'value_type',
        'category',
        'description',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public $timestamps = true;
}