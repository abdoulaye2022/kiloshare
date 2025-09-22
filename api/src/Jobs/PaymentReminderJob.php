<?php

declare(strict_types=1);

namespace KiloShare\Jobs;

use KiloShare\Models\ScheduledJob;
use KiloShare\Models\PaymentAuthorization;
use KiloShare\Services\SmartNotificationService;
use KiloShare\Models\PaymentEventLog;

class PaymentReminderJob
{
    private SmartNotificationService $notificationService;

    public function __construct(SmartNotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    /**
     * Exécuter un job de rappel de paiement
     */
    public function execute(ScheduledJob $job): bool
    {
        if (!$job->isPending()) {
            return false;
        }

        // Marquer le job comme en cours d'exécution
        $job->markAsRunning();

        try {
            $authorization = $job->paymentAuthorization;

            if (!$authorization) {
                $job->markAsFailed('Autorisation de paiement non trouvée');
                return false;
            }

            $jobData = $job->job_data ?? [];
            $reminderType = $jobData['reminder_type'] ?? 'unknown';

            // Vérifier si le rappel est encore pertinent
            if (!$this->isReminderRelevant($authorization, $reminderType)) {
                $job->markAsCompleted([
                    'skipped' => true,
                    'reason' => 'Reminder no longer relevant',
                    'current_status' => $authorization->status,
                    'reminder_type' => $reminderType,
                ]);
                return true;
            }

            // Envoyer le rappel approprié
            $success = $this->sendReminder($authorization, $reminderType, $jobData);

            if ($success) {
                $job->markAsCompleted([
                    'reminder_sent' => true,
                    'reminder_type' => $reminderType,
                    'authorization_id' => $authorization->id,
                    'recipient' => $this->getRecipientInfo($authorization, $reminderType),
                ]);

                PaymentEventLog::logNotificationSent($authorization, null, [
                    'job_id' => $job->id,
                    'reminder_type' => $reminderType,
                    'notification_method' => 'automatic_reminder',
                ]);

                return true;
            } else {
                $job->markAsFailed('Failed to send reminder notification');
                return false;
            }

        } catch (\Exception $e) {
            $job->markAsFailed($e->getMessage());

            PaymentEventLog::create([
                'payment_authorization_id' => $job->payment_authorization_id,
                'booking_id' => $job->booking_id,
                'event_type' => PaymentEventLog::EVENT_NOTIFICATION_SENT,
                'success' => false,
                'error_message' => $e->getMessage(),
                'event_data' => [
                    'job_id' => $job->id,
                    'execution_type' => 'automatic_reminder',
                ],
            ]);

            return false;
        }
    }

    /**
     * Traiter tous les jobs de rappel en attente
     */
    public function processAllPendingReminders(): array
    {
        $reminderJobs = ScheduledJob::readyToExecute()
                                   ->whereIn('type', [
                                       ScheduledJob::TYPE_CONFIRMATION_REMINDER,
                                       ScheduledJob::TYPE_PAYMENT_REMINDER
                                   ])
                                   ->take(50)
                                   ->get();

        $results = [
            'processed' => 0,
            'successful' => 0,
            'failed' => 0,
            'skipped' => 0,
        ];

        foreach ($reminderJobs as $job) {
            $results['processed']++;

            try {
                $success = $this->execute($job);

                if ($success) {
                    $jobResult = $job->fresh()->result ?? [];
                    if (isset($jobResult['skipped']) && $jobResult['skipped']) {
                        $results['skipped']++;
                    } else {
                        $results['successful']++;
                    }
                } else {
                    $results['failed']++;
                }
            } catch (\Exception $e) {
                $results['failed']++;
                error_log("Erreur lors du traitement du job de rappel {$job->id}: " . $e->getMessage());
            }
        }

        return $results;
    }

    /**
     * Programmer les rappels pour une autorisation
     */
    public function scheduleReminders(PaymentAuthorization $authorization): array
    {
        $jobs = [];

        // Rappel de confirmation si en attente
        if ($authorization->isPending() && $authorization->confirmation_deadline) {
            $reminderTime = $authorization->confirmation_deadline->copy()->subHours(2);

            if ($reminderTime->isFuture()) {
                $existingJob = ScheduledJob::where('payment_authorization_id', $authorization->id)
                                          ->where('type', ScheduledJob::TYPE_CONFIRMATION_REMINDER)
                                          ->where('status', ScheduledJob::STATUS_PENDING)
                                          ->first();

                if (!$existingJob) {
                    $jobs[] = ScheduledJob::scheduleConfirmationReminder($authorization, 2);
                }
            }
        }

        // Rappel de capture imminente si confirmé
        if ($authorization->isConfirmed() && $authorization->auto_capture_at) {
            $reminderTime = $authorization->auto_capture_at->copy()->subHours(24);

            if ($reminderTime->isFuture()) {
                $existingJob = ScheduledJob::where('payment_authorization_id', $authorization->id)
                                          ->where('type', ScheduledJob::TYPE_PAYMENT_REMINDER)
                                          ->where('status', ScheduledJob::STATUS_PENDING)
                                          ->first();

                if (!$existingJob) {
                    $jobs[] = ScheduledJob::schedulePaymentReminder($authorization, 24);
                }
            }
        }

        return array_filter($jobs);
    }

    /**
     * Vérifier si un rappel est encore pertinent
     */
    private function isReminderRelevant(PaymentAuthorization $authorization, string $reminderType): bool
    {
        switch ($reminderType) {
            case 'confirmation':
                // Pertinent seulement si encore en attente et pas expiré
                return $authorization->isPending() && !$authorization->isConfirmationExpired();

            case 'payment':
                // Pertinent seulement si confirmé et pas encore capturé
                return $authorization->isConfirmed() && !$authorization->isCaptureExpired();

            default:
                return false;
        }
    }

    /**
     * Envoyer le rappel approprié
     */
    private function sendReminder(PaymentAuthorization $authorization, string $reminderType, array $jobData): bool
    {
        try {
            switch ($reminderType) {
                case 'confirmation':
                    return $this->sendConfirmationReminder($authorization, $jobData);

                case 'payment':
                    return $this->sendPaymentReminder($authorization, $jobData);

                default:
                    throw new \Exception("Type de rappel inconnu: {$reminderType}");
            }
        } catch (\Exception $e) {
            error_log("Erreur envoi rappel {$reminderType} pour autorisation {$authorization->id}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer un rappel de confirmation
     */
    private function sendConfirmationReminder(PaymentAuthorization $authorization, array $jobData): bool
    {
        $booking = $authorization->booking;
        $sender = $booking->sender;

        $hoursRemaining = $authorization->getRemainingConfirmationTime() / 60; // Convertir en heures

        $data = [
            'authorization' => $authorization,
            'booking' => $booking,
            'hours_remaining' => max(0, round($hoursRemaining, 1)),
            'confirmation_url' => $this->generateConfirmationUrl($authorization),
            'reminder_type' => 'confirmation',
        ];

        return $this->notificationService->sendPaymentConfirmationReminder($sender, $data);
    }

    /**
     * Envoyer un rappel de capture imminente
     */
    private function sendPaymentReminder(PaymentAuthorization $authorization, array $jobData): bool
    {
        $booking = $authorization->booking;
        $sender = $booking->sender;
        $transporter = $booking->trip->user;

        $hoursUntilCapture = $jobData['hours_before_capture'] ?? 24;

        $data = [
            'authorization' => $authorization,
            'booking' => $booking,
            'hours_until_capture' => $hoursUntilCapture,
            'capture_date' => $authorization->auto_capture_at,
            'reminder_type' => 'payment',
        ];

        // Notifier l'expéditeur et le transporteur
        $senderSuccess = $this->notificationService->sendPaymentCaptureReminder($sender, $data, 'sender');
        $transporterSuccess = $this->notificationService->sendPaymentCaptureReminder($transporter, $data, 'transporter');

        return $senderSuccess && $transporterSuccess;
    }

    /**
     * Obtenir les informations du destinataire
     */
    private function getRecipientInfo(PaymentAuthorization $authorization, string $reminderType): array
    {
        $booking = $authorization->booking;

        switch ($reminderType) {
            case 'confirmation':
                return [
                    'user_id' => $booking->sender_id,
                    'role' => 'sender',
                    'email' => $booking->sender->email ?? null,
                ];

            case 'payment':
                return [
                    'sender' => [
                        'user_id' => $booking->sender_id,
                        'email' => $booking->sender->email ?? null,
                    ],
                    'transporter' => [
                        'user_id' => $booking->trip->user_id,
                        'email' => $booking->trip->user->email ?? null,
                    ],
                ];

            default:
                return [];
        }
    }

    /**
     * Générer l'URL de confirmation
     */
    private function generateConfirmationUrl(PaymentAuthorization $authorization): string
    {
        $baseUrl = config('app.frontend_url', 'https://kiloshare.com');
        return "{$baseUrl}/booking/{$authorization->booking_id}/confirm-payment";
    }

    /**
     * Obtenir les statistiques des rappels
     */
    public function getReminderStatistics(int $days = 7): array
    {
        $startDate = now()->subDays($days);

        $stats = [
            'total_reminder_jobs' => ScheduledJob::whereIn('type', [
                                                   ScheduledJob::TYPE_CONFIRMATION_REMINDER,
                                                   ScheduledJob::TYPE_PAYMENT_REMINDER
                                               ])
                                               ->where('created_at', '>=', $startDate)
                                               ->count(),
            'by_type' => ScheduledJob::whereIn('type', [
                                      ScheduledJob::TYPE_CONFIRMATION_REMINDER,
                                      ScheduledJob::TYPE_PAYMENT_REMINDER
                                  ])
                                  ->where('created_at', '>=', $startDate)
                                  ->selectRaw('type, COUNT(*) as count')
                                  ->groupBy('type')
                                  ->pluck('count', 'type')
                                  ->toArray(),
            'by_status' => ScheduledJob::whereIn('type', [
                                       ScheduledJob::TYPE_CONFIRMATION_REMINDER,
                                       ScheduledJob::TYPE_PAYMENT_REMINDER
                                   ])
                                   ->where('created_at', '>=', $startDate)
                                   ->selectRaw('status, COUNT(*) as count')
                                   ->groupBy('status')
                                   ->pluck('count', 'status')
                                   ->toArray(),
            'effectiveness' => $this->calculateReminderEffectiveness($days),
            'upcoming_reminders' => $this->getUpcomingReminders(),
        ];

        return $stats;
    }

    private function calculateReminderEffectiveness(int $days): array
    {
        $startDate = now()->subDays($days);

        // Rappels de confirmation envoyés
        $confirmationReminders = ScheduledJob::where('type', ScheduledJob::TYPE_CONFIRMATION_REMINDER)
                                            ->where('status', ScheduledJob::STATUS_COMPLETED)
                                            ->where('executed_at', '>=', $startDate)
                                            ->get();

        $confirmationSuccessRate = 0;
        if ($confirmationReminders->count() > 0) {
            $successfulConfirmations = $confirmationReminders->filter(function ($job) {
                $auth = $job->paymentAuthorization;
                return $auth && $auth->isConfirmed();
            })->count();

            $confirmationSuccessRate = ($successfulConfirmations / $confirmationReminders->count()) * 100;
        }

        return [
            'confirmation_reminder_success_rate' => round($confirmationSuccessRate, 1),
            'total_confirmation_reminders' => $confirmationReminders->count(),
            'payment_reminders_sent' => ScheduledJob::where('type', ScheduledJob::TYPE_PAYMENT_REMINDER)
                                                   ->where('status', ScheduledJob::STATUS_COMPLETED)
                                                   ->where('executed_at', '>=', $startDate)
                                                   ->count(),
        ];
    }

    private function getUpcomingReminders(): array
    {
        $next24h = ScheduledJob::whereIn('type', [
                                ScheduledJob::TYPE_CONFIRMATION_REMINDER,
                                ScheduledJob::TYPE_PAYMENT_REMINDER
                            ])
                            ->where('status', ScheduledJob::STATUS_PENDING)
                            ->where('scheduled_at', '>', now())
                            ->where('scheduled_at', '<=', now()->addDay())
                            ->selectRaw('type, COUNT(*) as count')
                            ->groupBy('type')
                            ->pluck('count', 'type')
                            ->toArray();

        return $next24h;
    }

    /**
     * Nettoyer les anciens jobs de rappel
     */
    public function cleanupOldJobs(int $daysToKeep = 30): int
    {
        return ScheduledJob::whereIn('type', [
                              ScheduledJob::TYPE_CONFIRMATION_REMINDER,
                              ScheduledJob::TYPE_PAYMENT_REMINDER
                          ])
                          ->whereIn('status', [ScheduledJob::STATUS_COMPLETED, ScheduledJob::STATUS_CANCELLED])
                          ->where('updated_at', '<', now()->subDays($daysToKeep))
                          ->delete();
    }

    /**
     * Envoyer manuellement un rappel
     */
    public function sendManualReminder(PaymentAuthorization $authorization, string $type): bool
    {
        try {
            switch ($type) {
                case 'confirmation':
                    if (!$authorization->isPending()) {
                        throw new \Exception('Cette autorisation ne nécessite plus de confirmation');
                    }
                    return $this->sendConfirmationReminder($authorization, []);

                case 'payment':
                    if (!$authorization->isConfirmed()) {
                        throw new \Exception('Cette autorisation n\'est pas confirmée');
                    }
                    return $this->sendPaymentReminder($authorization, ['hours_before_capture' => 'immédiat']);

                default:
                    throw new \Exception("Type de rappel invalide: {$type}");
            }
        } catch (\Exception $e) {
            error_log("Erreur rappel manuel {$type} pour autorisation {$authorization->id}: " . $e->getMessage());
            return false;
        }
    }
}