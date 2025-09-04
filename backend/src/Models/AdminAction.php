<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminAction extends Model
{
    protected $table = 'admin_actions';

    protected $fillable = [
        'admin_id',
        'target_type',
        'target_id',
        'action',
        'reason',
        'metadata',
        'ip_address',
        'user_agent',
    ];

    protected $casts = [
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    // Target types
    const TARGET_TRIP = 'trip';
    const TARGET_USER = 'user';
    const TARGET_BOOKING = 'booking';
    const TARGET_PAYMENT = 'payment';

    // Actions
    const ACTION_APPROVE = 'approve';
    const ACTION_REJECT = 'reject';
    const ACTION_SUSPEND = 'suspend';
    const ACTION_ACTIVATE = 'activate';
    const ACTION_MANUAL_RELEASE = 'manual_release';
    const ACTION_FLAG_SUSPICIOUS = 'flag_suspicious';

    // Relations
    public function admin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_id');
    }

    // Helper methods
    public static function log(
        int $adminId,
        string $targetType,
        int $targetId,
        string $action,
        ?string $reason = null,
        ?array $metadata = null,
        ?string $ipAddress = null,
        ?string $userAgent = null
    ): self {
        return self::create([
            'admin_id' => $adminId,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'action' => $action,
            'reason' => $reason,
            'metadata' => $metadata,
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
        ]);
    }
}