<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\PaymentConfiguration;
use Illuminate\Support\Facades\Cache;

class PaymentConfigurationService
{
    private const CACHE_PREFIX = 'payment_config_';
    private const CACHE_TTL = 3600; // 1 heure

    /**
     * Récupérer une configuration
     */
    public function get(string $key, $default = null)
    {
        $cacheKey = self::CACHE_PREFIX . $key;

        return Cache::remember($cacheKey, self::CACHE_TTL, function () use ($key, $default) {
            $config = PaymentConfiguration::where('config_key', $key)
                                         ->where('is_active', true)
                                         ->first();

            if (!$config) {
                return $default;
            }

            return $this->castValue($config->config_value, $config->value_type);
        });
    }

    /**
     * Définir une configuration
     */
    public function set(string $key, $value, string $type = 'string', string $category = 'authorization'): bool
    {
        $stringValue = $this->valueToString($value, $type);

        $config = PaymentConfiguration::updateOrCreate(
            ['config_key' => $key],
            [
                'config_value' => $stringValue,
                'value_type' => $type,
                'category' => $category,
                'is_active' => true,
            ]
        );

        // Invalider le cache
        Cache::forget(self::CACHE_PREFIX . $key);

        return (bool) $config;
    }

    /**
     * Récupérer toutes les configurations d'une catégorie
     */
    public function getByCategory(string $category): array
    {
        $configs = PaymentConfiguration::where('category', $category)
                                      ->where('is_active', true)
                                      ->get();

        $result = [];
        foreach ($configs as $config) {
            $result[$config->config_key] = $this->castValue($config->config_value, $config->value_type);
        }

        return $result;
    }

    /**
     * Récupérer toutes les configurations actives
     */
    public function getAll(): array
    {
        $configs = PaymentConfiguration::where('is_active', true)->get();

        $result = [];
        foreach ($configs as $config) {
            $result[$config->config_key] = [
                'value' => $this->castValue($config->config_value, $config->value_type),
                'type' => $config->value_type,
                'category' => $config->category,
                'description' => $config->description,
            ];
        }

        return $result;
    }

    /**
     * Désactiver une configuration
     */
    public function disable(string $key): bool
    {
        $config = PaymentConfiguration::where('config_key', $key)->first();

        if (!$config) {
            return false;
        }

        $config->is_active = false;
        $result = $config->save();

        // Invalider le cache
        Cache::forget(self::CACHE_PREFIX . $key);

        return $result;
    }

    /**
     * Vider le cache des configurations
     */
    public function clearCache(): void
    {
        $configs = PaymentConfiguration::pluck('config_key');

        foreach ($configs as $key) {
            Cache::forget(self::CACHE_PREFIX . $key);
        }
    }

    /**
     * Convertir une valeur string vers son type approprié
     */
    private function castValue(string $value, string $type)
    {
        switch ($type) {
            case 'integer':
                return (int) $value;
            case 'float':
                return (float) $value;
            case 'boolean':
                return filter_var($value, FILTER_VALIDATE_BOOLEAN);
            case 'json':
                return json_decode($value, true);
            case 'string':
            default:
                return $value;
        }
    }

    /**
     * Convertir une valeur vers string pour stockage
     */
    private function valueToString($value, string $type): string
    {
        switch ($type) {
            case 'boolean':
                return $value ? 'true' : 'false';
            case 'json':
                return json_encode($value);
            case 'integer':
            case 'float':
            case 'string':
            default:
                return (string) $value;
        }
    }

    // Méthodes de raccourci pour les configurations communes

    /**
     * Délai de confirmation en heures
     */
    public function getConfirmationDeadlineHours(): int
    {
        return $this->get('confirmation_deadline_hours', 4);
    }

    /**
     * Heures avant le départ pour capture automatique
     */
    public function getAutoCaptureHoursBeforeTrip(): int
    {
        return $this->get('auto_capture_hours_before_trip', 72);
    }

    /**
     * Nombre maximum de tentatives de capture
     */
    public function getMaxCaptureAttempts(): int
    {
        return $this->get('max_capture_attempts', 3);
    }

    /**
     * Délai entre les tentatives en minutes
     */
    public function getRetryDelayMinutes(): int
    {
        return $this->get('retry_delay_minutes', 30);
    }

    /**
     * Pourcentage des frais de plateforme
     */
    public function getPlatformFeePercentage(): float
    {
        return $this->get('platform_fee_percentage', 5.0);
    }

    /**
     * Frais minimum de plateforme en centimes
     */
    public function getMinimumPlatformFeeCents(): int
    {
        return $this->get('minimum_platform_fee_cents', 50);
    }

    /**
     * Envoyer des rappels de confirmation
     */
    public function shouldSendConfirmationReminders(): bool
    {
        return $this->get('send_confirmation_reminders', true);
    }

    /**
     * Heures avant expiration pour envoyer un rappel
     */
    public function getReminderHoursBeforeExpiry(): int
    {
        return $this->get('reminder_hours_before_expiry', 2);
    }

    /**
     * Remboursement automatique en cas d'annulation
     */
    public function shouldAutoRefundOnCancellation(): bool
    {
        return $this->get('auto_refund_on_cancellation', true);
    }

    /**
     * Frais de traitement pour les remboursements en centimes
     */
    public function getRefundProcessingFeeCents(): int
    {
        return $this->get('refund_processing_fee_cents', 30);
    }

    /**
     * Activer la capture automatique
     */
    public function isAutoCaptureEnabled(): bool
    {
        return $this->get('enable_auto_capture', true);
    }

    /**
     * Capturer lors de la confirmation de récupération
     */
    public function shouldCaptureOnPickupConfirmation(): bool
    {
        return $this->get('capture_on_pickup_confirmation', true);
    }

    /**
     * Exiger 3D Secure pour les gros montants
     */
    public function shouldRequire3DSForLargeAmounts(): bool
    {
        return $this->get('require_3ds_for_large_amounts', true);
    }

    /**
     * Seuil en centimes pour considérer un montant comme important
     */
    public function getLargeAmountThresholdCents(): int
    {
        return $this->get('large_amount_threshold_cents', 50000);
    }

    /**
     * Valider qu'un montant nécessite 3D Secure
     */
    public function requiresThreeDSecure(int $amountCents): bool
    {
        return $this->shouldRequire3DSForLargeAmounts() &&
               $amountCents >= $this->getLargeAmountThresholdCents();
    }

    /**
     * Calculer la deadline de confirmation
     */
    public function calculateConfirmationDeadline(): \DateTime
    {
        $hours = $this->getConfirmationDeadlineHours();
        return (new \DateTime())->modify("+{$hours} hours");
    }

    /**
     * Calculer le moment de capture automatique basé sur la date de voyage
     */
    public function calculateAutoCaptureTime(\DateTime $tripDate): \DateTime
    {
        $hours = $this->getAutoCaptureHoursBeforeTrip();
        return (clone $tripDate)->modify("-{$hours} hours");
    }

    /**
     * Statistiques d'utilisation des configurations
     */
    public function getUsageStats(): array
    {
        return [
            'total_configurations' => PaymentConfiguration::count(),
            'active_configurations' => PaymentConfiguration::where('is_active', true)->count(),
            'by_category' => PaymentConfiguration::where('is_active', true)
                                                 ->selectRaw('category, COUNT(*) as count')
                                                 ->groupBy('category')
                                                 ->pluck('count', 'category')
                                                 ->toArray(),
            'recently_modified' => PaymentConfiguration::where('updated_at', '>=', now()->subDays(7))
                                                       ->count(),
        ];
    }
}