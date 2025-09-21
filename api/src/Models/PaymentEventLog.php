<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PaymentEventLog extends Model
{
    protected $table = 'payment_events_log';

    // Types d'événements
    const EVENT_AUTHORIZATION_CREATED = 'authorization_created';
    const EVENT_AUTHORIZATION_CONFIRMED = 'authorization_confirmed';
    const EVENT_AUTHORIZATION_CANCELLED = 'authorization_cancelled';
    const EVENT_AUTHORIZATION_EXPIRED = 'authorization_expired';
    const EVENT_CAPTURE_SCHEDULED = 'capture_scheduled';
    const EVENT_CAPTURE_ATTEMPTED = 'capture_attempted';
    const EVENT_CAPTURE_SUCCEEDED = 'capture_succeeded';
    const EVENT_CAPTURE_FAILED = 'capture_failed';
    const EVENT_REFUND_INITIATED = 'refund_initiated';
    const EVENT_REFUND_COMPLETED = 'refund_completed';
    const EVENT_WEBHOOK_RECEIVED = 'webhook_received';
    const EVENT_NOTIFICATION_SENT = 'notification_sent';

    protected $fillable = [
        'payment_authorization_id',
        'booking_id',
        'user_id',
        'event_type',
        'event_data',
        'stripe_event_id',
        'ip_address',
        'user_agent',
        'success',
        'error_message',
        'processing_time_ms',
    ];

    protected $casts = [
        'payment_authorization_id' => 'integer',
        'booking_id' => 'integer',
        'user_id' => 'integer',
        'event_data' => 'array',
        'success' => 'boolean',
        'processing_time_ms' => 'integer',
        'created_at' => 'datetime',
    ];

    // Relations
    public function paymentAuthorization(): BelongsTo
    {
        return $this->belongsTo(PaymentAuthorization::class, 'payment_authorization_id');
    }

    public function booking(): BelongsTo
    {
        return $this->belongsTo(Booking::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeSuccessful($query)
    {
        return $query->where('success', true);
    }

    public function scopeFailed($query)
    {
        return $query->where('success', false);
    }

    public function scopeByEventType($query, string $eventType)
    {
        return $query->where('event_type', $eventType);
    }

    public function scopeByPaymentAuthorization($query, int $paymentAuthorizationId)
    {
        return $query->where('payment_authorization_id', $paymentAuthorizationId);
    }

    public function scopeByBooking($query, int $bookingId)
    {
        return $query->where('booking_id', $bookingId);
    }

    // Méthodes statiques pour créer des logs facilement
    public static function logAuthorizationCreated(PaymentAuthorization $authorization, ?User $user = null, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'user_id' => $user?->id,
            'event_type' => self::EVENT_AUTHORIZATION_CREATED,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    public static function logAuthorizationConfirmed(PaymentAuthorization $authorization, User $user, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'user_id' => $user->id,
            'event_type' => self::EVENT_AUTHORIZATION_CONFIRMED,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    public static function logAuthorizationCancelled(PaymentAuthorization $authorization, ?User $user = null, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'user_id' => $user?->id,
            'event_type' => self::EVENT_AUTHORIZATION_CANCELLED,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    public static function logAuthorizationExpired(PaymentAuthorization $authorization, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'event_type' => self::EVENT_AUTHORIZATION_EXPIRED,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    public static function logCaptureAttempted(PaymentAuthorization $authorization, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'event_type' => self::EVENT_CAPTURE_ATTEMPTED,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    public static function logCaptureSucceeded(PaymentAuthorization $authorization, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'event_type' => self::EVENT_CAPTURE_SUCCEEDED,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    public static function logCaptureFailed(PaymentAuthorization $authorization, string $error, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'event_type' => self::EVENT_CAPTURE_FAILED,
            'event_data' => $data,
            'error_message' => $error,
            'success' => false,
        ]);
    }

    public static function logWebhookReceived(string $stripeEventId, ?int $paymentAuthorizationId = null, ?int $bookingId = null, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $paymentAuthorizationId,
            'booking_id' => $bookingId,
            'event_type' => self::EVENT_WEBHOOK_RECEIVED,
            'stripe_event_id' => $stripeEventId,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    public static function logNotificationSent(PaymentAuthorization $authorization, ?User $user = null, array $data = []): self
    {
        return self::createLog([
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'user_id' => $user?->id,
            'event_type' => self::EVENT_NOTIFICATION_SENT,
            'event_data' => $data,
            'success' => true,
        ]);
    }

    private static function createLog(array $data): self
    {
        // Ajouter les informations de contexte si disponibles
        if (isset($_SERVER['REMOTE_ADDR'])) {
            $data['ip_address'] = $_SERVER['REMOTE_ADDR'];
        }
        if (isset($_SERVER['HTTP_USER_AGENT'])) {
            $data['user_agent'] = $_SERVER['HTTP_USER_AGENT'];
        }

        return self::create($data);
    }

    // Méthodes d'analyse
    public static function getEventStatistics(int $paymentAuthorizationId): array
    {
        $logs = self::where('payment_authorization_id', $paymentAuthorizationId)->get();

        $stats = [
            'total_events' => $logs->count(),
            'successful_events' => $logs->where('success', true)->count(),
            'failed_events' => $logs->where('success', false)->count(),
            'events_by_type' => $logs->groupBy('event_type')->map->count()->toArray(),
            'timeline' => $logs->sortBy('created_at')->map(function ($log) {
                return [
                    'event_type' => $log->event_type,
                    'success' => $log->success,
                    'created_at' => $log->created_at->toISOString(),
                    'error_message' => $log->error_message,
                ];
            })->values()->toArray(),
        ];

        return $stats;
    }

    // Désactiver les timestamps automatiques updated_at
    public $timestamps = false;
    protected $dates = ['created_at'];

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($model) {
            $model->created_at = now();
        });
    }
}