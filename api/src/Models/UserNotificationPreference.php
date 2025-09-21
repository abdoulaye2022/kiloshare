<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserNotificationPreference extends Model
{
    protected $table = 'user_notification_preferences';

    protected $fillable = [
        'user_id',
        'push_enabled',
        'email_enabled',
        'sms_enabled',
        'in_app_enabled',
        'marketing_enabled',
        'quiet_hours_enabled',
        'quiet_hours_start',
        'quiet_hours_end',
        'timezone',
        'trip_updates_push',
        'trip_updates_email',
        'booking_updates_push',
        'booking_updates_email',
        'payment_updates_push',
        'payment_updates_email',
        'security_alerts_push',
        'security_alerts_email',
        'language',
    ];

    protected $casts = [
        'user_id' => 'integer',
        'push_enabled' => 'boolean',
        'email_enabled' => 'boolean',
        'sms_enabled' => 'boolean',
        'in_app_enabled' => 'boolean',
        'marketing_enabled' => 'boolean',
        'quiet_hours_enabled' => 'boolean',
        'trip_updates_push' => 'boolean',
        'trip_updates_email' => 'boolean',
        'booking_updates_push' => 'boolean',
        'booking_updates_email' => 'boolean',
        'payment_updates_push' => 'boolean',
        'payment_updates_email' => 'boolean',
        'security_alerts_push' => 'boolean',
        'security_alerts_email' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    // Relations
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    // Methods
    public function canReceiveChannel(string $channel): bool
    {
        switch ($channel) {
            case 'push':
                return $this->push_enabled;
            case 'email':
                return $this->email_enabled;
            case 'sms':
                return $this->sms_enabled;
            case 'in_app':
                return $this->in_app_enabled;
            default:
                return false;
        }
    }

    public function canReceiveNotificationType(string $type, string $channel): bool
    {
        // Vérifier d'abord si le canal est activé
        if (!$this->canReceiveChannel($channel)) {
            return false;
        }

        // Vérifier les préférences spécifiques par type
        $typeCategory = $this->getNotificationTypeCategory($type);
        
        switch ($typeCategory) {
            case 'trip':
                return $channel === 'push' ? $this->trip_updates_push : $this->trip_updates_email;
            case 'booking':
                return $channel === 'push' ? $this->booking_updates_push : $this->booking_updates_email;
            case 'payment':
                return $channel === 'push' ? $this->payment_updates_push : $this->payment_updates_email;
            case 'security':
                return $channel === 'push' ? $this->security_alerts_push : $this->security_alerts_email;
            default:
                return $this->canReceiveChannel($channel);
        }
    }

    public function isInQuietHours(): bool
    {
        if (!$this->quiet_hours_enabled) {
            return false;
        }

        $now = now($this->timezone)->format('H:i:s');
        $start = $this->quiet_hours_start;
        $end = $this->quiet_hours_end;

        if ($start <= $end) {
            // Même journée (ex: 22:00 - 06:00 le lendemain)
            return $now >= $start && $now <= $end;
        } else {
            // Chevauche minuit (ex: 22:00 - 06:00)
            return $now >= $start || $now <= $end;
        }
    }

    private function getNotificationTypeCategory(string $type): string
    {
        $tripTypes = ['trip_submitted', 'trip_approved', 'trip_rejected', 'trip_started', 'trip_cancelled'];
        $bookingTypes = ['new_booking_request', 'booking_accepted', 'booking_rejected', 'negotiation_message'];
        $paymentTypes = ['payment_received', 'payment_confirmed', 'payment_released'];
        $securityTypes = ['suspicious_login', 'account_suspended', 'security_alert'];

        if (in_array($type, $tripTypes)) return 'trip';
        if (in_array($type, $bookingTypes)) return 'booking';
        if (in_array($type, $paymentTypes)) return 'payment';
        if (in_array($type, $securityTypes)) return 'security';

        return 'general';
    }

    public static function getDefaultPreferences(): array
    {
        return [
            'push_enabled' => true,
            'email_enabled' => true,
            'sms_enabled' => true,
            'in_app_enabled' => true,
            'marketing_enabled' => false,
            'quiet_hours_enabled' => true,
            'quiet_hours_start' => '22:00:00',
            'quiet_hours_end' => '08:00:00',
            'timezone' => 'Europe/Paris',
            'trip_updates_push' => true,
            'trip_updates_email' => true,
            'booking_updates_push' => true,
            'booking_updates_email' => true,
            'payment_updates_push' => true,
            'payment_updates_email' => true,
            'security_alerts_push' => true,
            'security_alerts_email' => true,
            'language' => 'fr',
        ];
    }

    public static function createForUser(int $userId): self
    {
        return self::create(array_merge(
            ['user_id' => $userId],
            self::getDefaultPreferences()
        ));
    }
}