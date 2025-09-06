<?php

declare(strict_types=1);

namespace KiloShare\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserNotificationPreferences extends Model
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
        'language'
    ];

    protected $casts = [
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
        'updated_at' => 'datetime'
    ];

    /**
     * Relation avec l'utilisateur
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Créer les préférences par défaut pour un utilisateur
     */
    public static function createDefaultForUser(int $userId): self
    {
        return self::create([
            'user_id' => $userId,
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
            'language' => 'fr'
        ]);
    }

    /**
     * Vérifier si l'utilisateur peut recevoir des notifications pendant les heures calmes
     */
    public function canReceiveNotificationNow(): bool
    {
        if (!$this->quiet_hours_enabled) {
            return true;
        }

        try {
            $now = new \DateTime('now', new \DateTimeZone($this->timezone));
            $currentTime = $now->format('H:i:s');
            $startTime = $this->quiet_hours_start;
            $endTime = $this->quiet_hours_end;

            // Si les heures calmes traversent minuit (ex: 22:00 à 08:00)
            if ($startTime > $endTime) {
                return !($currentTime >= $startTime || $currentTime <= $endTime);
            }
            
            // Heures calmes dans la même journée (ex: 14:00 à 18:00)
            return !($currentTime >= $startTime && $currentTime <= $endTime);
        } catch (\Exception $e) {
            // En cas d'erreur avec la timezone, utiliser l'heure locale
            $now = new \DateTime();
            $currentTime = $now->format('H:i:s');
            $startTime = $this->quiet_hours_start;
            $endTime = $this->quiet_hours_end;

            if ($startTime > $endTime) {
                return !($currentTime >= $startTime || $currentTime <= $endTime);
            }
            
            return !($currentTime >= $startTime && $currentTime <= $endTime);
        }
    }

    /**
     * Obtenir les préférences formatées pour l'API
     */
    public function toApiArray(): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'general' => [
                'push_enabled' => $this->push_enabled,
                'email_enabled' => $this->email_enabled,
                'sms_enabled' => $this->sms_enabled,
                'in_app_enabled' => $this->in_app_enabled,
                'marketing_enabled' => $this->marketing_enabled,
                'language' => $this->language,
                'timezone' => $this->timezone
            ],
            'quiet_hours' => [
                'enabled' => $this->quiet_hours_enabled,
                'start' => $this->quiet_hours_start,
                'end' => $this->quiet_hours_end
            ],
            'categories' => [
                'trip_updates' => [
                    'push' => $this->trip_updates_push,
                    'email' => $this->trip_updates_email
                ],
                'booking_updates' => [
                    'push' => $this->booking_updates_push,
                    'email' => $this->booking_updates_email
                ],
                'payment_updates' => [
                    'push' => $this->payment_updates_push,
                    'email' => $this->payment_updates_email
                ],
                'security_alerts' => [
                    'push' => $this->security_alerts_push,
                    'email' => $this->security_alerts_email
                ]
            ],
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString()
        ];
    }
}