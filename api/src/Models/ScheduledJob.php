<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ScheduledJob extends Model
{
    protected $table = 'scheduled_jobs';

    // Types de jobs
    const TYPE_AUTO_CAPTURE = 'auto_capture';
    const TYPE_PAYMENT_EXPIRY = 'payment_expiry';
    const TYPE_CONFIRMATION_REMINDER = 'confirmation_reminder';
    const TYPE_PAYMENT_REMINDER = 'payment_reminder';

    // Statuts des jobs
    const STATUS_PENDING = 'pending';
    const STATUS_RUNNING = 'running';
    const STATUS_COMPLETED = 'completed';
    const STATUS_FAILED = 'failed';
    const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'type',
        'payment_authorization_id',
        'booking_id',
        'scheduled_at',
        'executed_at',
        'status',
        'priority',
        'attempts',
        'max_attempts',
        'job_data',
        'result',
        'error_message',
    ];

    protected $casts = [
        'payment_authorization_id' => 'integer',
        'booking_id' => 'integer',
        'scheduled_at' => 'datetime',
        'executed_at' => 'datetime',
        'priority' => 'integer',
        'attempts' => 'integer',
        'max_attempts' => 'integer',
        'job_data' => 'array',
        'result' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
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

    // Scopes pour les requêtes
    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function scopeReadyToExecute($query)
    {
        return $query->where('status', self::STATUS_PENDING)
                    ->where('scheduled_at', '<=', now())
                    ->orderBy('priority')
                    ->orderBy('scheduled_at');
    }

    public function scopeByType($query, string $type)
    {
        return $query->where('type', $type);
    }

    public function scopeFailedRetryable($query)
    {
        return $query->where('status', self::STATUS_FAILED)
                    ->whereColumn('attempts', '<', 'max_attempts');
    }

    // Méthodes de statut
    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function isRunning(): bool
    {
        return $this->status === self::STATUS_RUNNING;
    }

    public function isCompleted(): bool
    {
        return $this->status === self::STATUS_COMPLETED;
    }

    public function isFailed(): bool
    {
        return $this->status === self::STATUS_FAILED;
    }

    public function isCancelled(): bool
    {
        return $this->status === self::STATUS_CANCELLED;
    }

    public function canRetry(): bool
    {
        return $this->isFailed() && $this->attempts < $this->max_attempts;
    }

    public function isReadyToExecute(): bool
    {
        return $this->isPending() && $this->scheduled_at->isPast();
    }

    // Méthodes de gestion du cycle de vie
    public function markAsRunning(): bool
    {
        if (!$this->isPending()) {
            return false;
        }

        $this->status = self::STATUS_RUNNING;
        $this->attempts++;
        return $this->save();
    }

    public function markAsCompleted(array $result = []): bool
    {
        if (!$this->isRunning()) {
            return false;
        }

        $this->status = self::STATUS_COMPLETED;
        $this->executed_at = now();
        $this->result = $result;
        return $this->save();
    }

    public function markAsFailed(string $error, bool $canRetry = true): bool
    {
        if (!$this->isRunning()) {
            return false;
        }

        $this->status = self::STATUS_FAILED;
        $this->error_message = $error;

        // Si c'est une défaillance finale ou si on ne peut plus réessayer
        if (!$canRetry || $this->attempts >= $this->max_attempts) {
            $this->executed_at = now();
        } else {
            // Programmer un nouveau essai avec backoff exponentiel
            $this->status = self::STATUS_PENDING;
            $delayMinutes = min(60, pow(2, $this->attempts) * 5); // Backoff: 5, 10, 20, 40, 60 minutes
            $this->scheduled_at = now()->addMinutes($delayMinutes);
        }

        return $this->save();
    }

    public function cancel(?string $reason = null): bool
    {
        if (!in_array($this->status, [self::STATUS_PENDING, self::STATUS_FAILED])) {
            return false;
        }

        $this->status = self::STATUS_CANCELLED;
        $this->executed_at = now();

        if ($reason) {
            $this->error_message = $reason;
        }

        return $this->save();
    }

    // Méthodes statiques pour créer des jobs
    public static function scheduleAutoCapture(PaymentAuthorization $authorization): self
    {
        return self::create([
            'type' => self::TYPE_AUTO_CAPTURE,
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'scheduled_at' => $authorization->auto_capture_at,
            'priority' => 1, // Haute priorité pour les captures
            'job_data' => [
                'payment_intent_id' => $authorization->payment_intent_id,
                'capture_reason' => PaymentAuthorization::CAPTURE_REASON_AUTO_72H,
            ],
        ]);
    }

    public static function schedulePaymentExpiry(PaymentAuthorization $authorization): self
    {
        $expiryTime = $authorization->isPending()
            ? $authorization->confirmation_deadline
            : $authorization->expires_at;

        return self::create([
            'type' => self::TYPE_PAYMENT_EXPIRY,
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'scheduled_at' => $expiryTime,
            'priority' => 3,
            'job_data' => [
                'expiry_type' => $authorization->isPending() ? 'confirmation' : 'capture',
            ],
        ]);
    }

    public static function scheduleConfirmationReminder(PaymentAuthorization $authorization, int $hoursBefore = 2): self
    {
        $reminderTime = $authorization->confirmation_deadline->copy()->subHours($hoursBefore);

        // Ne pas programmer si c'est déjà dans le passé
        if ($reminderTime->isPast()) {
            return null;
        }

        return self::create([
            'type' => self::TYPE_CONFIRMATION_REMINDER,
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'scheduled_at' => $reminderTime,
            'priority' => 5,
            'job_data' => [
                'reminder_type' => 'confirmation',
                'hours_before_expiry' => $hoursBefore,
            ],
        ]);
    }

    public static function schedulePaymentReminder(PaymentAuthorization $authorization, int $hoursBefore = 24): self
    {
        if (!$authorization->auto_capture_at) {
            return null;
        }

        $reminderTime = $authorization->auto_capture_at->copy()->subHours($hoursBefore);

        // Ne pas programmer si c'est déjà dans le passé
        if ($reminderTime->isPast()) {
            return null;
        }

        return self::create([
            'type' => self::TYPE_PAYMENT_REMINDER,
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'scheduled_at' => $reminderTime,
            'priority' => 5,
            'job_data' => [
                'reminder_type' => 'payment',
                'hours_before_capture' => $hoursBefore,
            ],
        ]);
    }

    // Méthodes d'analyse et de nettoyage
    public static function getQueueStats(): array
    {
        return [
            'pending' => self::pending()->count(),
            'running' => self::where('status', self::STATUS_RUNNING)->count(),
            'completed_today' => self::where('status', self::STATUS_COMPLETED)
                                   ->whereDate('executed_at', today())
                                   ->count(),
            'failed_today' => self::where('status', self::STATUS_FAILED)
                                ->whereDate('updated_at', today())
                                ->count(),
            'ready_to_execute' => self::readyToExecute()->count(),
            'retryable' => self::failedRetryable()->count(),
        ];
    }

    public static function cleanupOldJobs(int $daysToKeep = 30): int
    {
        return self::whereIn('status', [self::STATUS_COMPLETED, self::STATUS_CANCELLED])
                   ->where('updated_at', '<', now()->subDays($daysToKeep))
                   ->delete();
    }

    // Méthodes utilitaires
    public function getJobDescription(): string
    {
        $descriptions = [
            self::TYPE_AUTO_CAPTURE => 'Capture automatique du paiement',
            self::TYPE_PAYMENT_EXPIRY => 'Expiration de l\'autorisation de paiement',
            self::TYPE_CONFIRMATION_REMINDER => 'Rappel de confirmation de paiement',
            self::TYPE_PAYMENT_REMINDER => 'Rappel de paiement imminent',
        ];

        return $descriptions[$this->type] ?? 'Job inconnu';
    }

    public function getEstimatedDuration(): int
    {
        // Durée estimée en secondes par type de job
        $durations = [
            self::TYPE_AUTO_CAPTURE => 30,
            self::TYPE_PAYMENT_EXPIRY => 10,
            self::TYPE_CONFIRMATION_REMINDER => 15,
            self::TYPE_PAYMENT_REMINDER => 15,
        ];

        return $durations[$this->type] ?? 10;
    }
}