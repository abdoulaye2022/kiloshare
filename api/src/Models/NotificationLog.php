<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationLog extends Model
{
    protected $table = 'notification_logs';

    protected $fillable = [
        'notification_id',
        'user_id',
        'type',
        'channel',
        'recipient',
        'title',
        'message',
        'data',
        'status',
        'sent_at',
        'delivered_at',
        'opened_at',
        'failed_at',
        'error_message',
        'retry_count',
        'retry_after',
        'provider',
        'provider_message_id',
        'cost_cents',
    ];

    protected $casts = [
        'notification_id' => 'integer',
        'user_id' => 'integer',
        'data' => 'array',
        'sent_at' => 'datetime',
        'delivered_at' => 'datetime',
        'opened_at' => 'datetime',
        'failed_at' => 'datetime',
        'retry_count' => 'integer',
        'retry_after' => 'datetime',
        'cost_cents' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Relations
    public function notification(): BelongsTo
    {
        return $this->belongsTo(Notification::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeByChannel($query, string $channel)
    {
        return $query->where('channel', $channel);
    }

    public function scopeByStatus($query, string $status)
    {
        return $query->where('status', $status);
    }

    public function scopeByProvider($query, string $provider)
    {
        return $query->where('provider', $provider);
    }

    public function scopeSentToday($query)
    {
        return $query->whereDate('sent_at', today());
    }

    public function scopeFailedRetries($query)
    {
        return $query->where('status', 'failed')
                    ->whereNotNull('retry_after')
                    ->where('retry_after', '<=', now());
    }

    // Methods
    public function markAsSent(): bool
    {
        return $this->update([
            'status' => 'sent',
            'sent_at' => now(),
        ]);
    }

    public function markAsDelivered(): bool
    {
        return $this->update([
            'status' => 'delivered',
            'delivered_at' => now(),
        ]);
    }

    public function markAsOpened(): bool
    {
        return $this->update([
            'status' => 'opened',
            'opened_at' => now(),
        ]);
    }

    public function markAsFailed(string $errorMessage, bool $shouldRetry = true): bool
    {
        $data = [
            'status' => 'failed',
            'failed_at' => now(),
            'error_message' => $errorMessage,
            'retry_count' => $this->retry_count + 1,
        ];

        if ($shouldRetry && $this->retry_count < 3) {
            // Délai exponentiel : 1min, 5min, 30min
            $delayMinutes = pow(5, $this->retry_count);
            $data['retry_after'] = now()->addMinutes($delayMinutes);
        }

        return $this->update($data);
    }

    public function canRetry(): bool
    {
        return $this->status === 'failed' 
            && $this->retry_count < 3 
            && $this->retry_after 
            && $this->retry_after->isPast();
    }

    public function getCostInEuros(): float
    {
        return $this->cost_cents / 100;
    }

    public function getDeliveryTime(): ?int
    {
        if (!$this->sent_at || !$this->delivered_at) {
            return null;
        }

        return $this->sent_at->diffInSeconds($this->delivered_at);
    }

    // Static methods
    public static function createForNotification(
        Notification $notification,
        string $channel,
        string $recipient,
        array $data = []
    ): self {
        return self::create([
            'notification_id' => $notification->id,
            'user_id' => $notification->user_id,
            'type' => $notification->type,
            'channel' => $channel,
            'recipient' => $recipient,
            'title' => $notification->title,
            'message' => $notification->message,
            'data' => array_merge($notification->data ?? [], $data),
            'status' => 'pending',
        ]);
    }

    public static function getStatsByChannel(int $days = 30): array
    {
        return self::selectRaw('
            channel,
            COUNT(*) as total,
            COUNT(CASE WHEN status = "sent" THEN 1 END) as sent,
            COUNT(CASE WHEN status = "delivered" THEN 1 END) as delivered,
            COUNT(CASE WHEN status = "opened" THEN 1 END) as opened,
            COUNT(CASE WHEN status = "failed" THEN 1 END) as failed,
            ROUND(AVG(CASE WHEN sent_at IS NOT NULL AND delivered_at IS NOT NULL 
                     THEN TIMESTAMPDIFF(SECOND, sent_at, delivered_at) END), 2) as avg_delivery_time_seconds
        ')
        ->where('created_at', '>=', now()->subDays($days))
        ->groupBy('channel')
        ->get()
        ->toArray();
    }

    // Constants
    public const CHANNELS = [
        'push' => 'push',
        'email' => 'email',
        'sms' => 'sms',
        'in_app' => 'in_app',
    ];

    public const STATUSES = [
        'pending' => 'pending',
        'sent' => 'sent',
        'delivered' => 'delivered',
        'opened' => 'opened',
        'failed' => 'failed',
        'cancelled' => 'cancelled',
    ];

    public const PROVIDERS = [
        'firebase' => 'firebase',
        'sendgrid' => 'sendgrid',
        'twilio' => 'twilio',
        'brevo' => 'brevo',
    ];
}