<?php

declare(strict_types=1);

namespace KiloShare\Jobs;

use KiloShare\Models\ScheduledJob;
use KiloShare\Models\PaymentAuthorization;
use KiloShare\Services\PaymentAuthorizationService;
use KiloShare\Models\PaymentEventLog;

class PaymentExpiryJob
{
    private PaymentAuthorizationService $paymentService;

    public function __construct(PaymentAuthorizationService $paymentService)
    {
        $this->paymentService = $paymentService;
    }

    /**
     * Exécuter un job d'expiration de paiement
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
            $expiryType = $jobData['expiry_type'] ?? 'unknown';

            // Vérifier si l'autorisation est réellement expirée
            $isExpired = false;
            $reason = '';

            if ($expiryType === 'confirmation') {
                $isExpired = $authorization->isConfirmationExpired();
                $reason = 'Délai de confirmation dépassé';
            } elseif ($expiryType === 'capture') {
                $isExpired = $authorization->isCaptureExpired();
                $reason = 'Délai de capture dépassé';
            } else {
                // Vérifier les deux cas
                if ($authorization->isConfirmationExpired()) {
                    $isExpired = true;
                    $reason = 'Délai de confirmation dépassé';
                } elseif ($authorization->isCaptureExpired()) {
                    $isExpired = true;
                    $reason = 'Délai de capture dépassé';
                }
            }

            if (!$isExpired) {
                // L'autorisation n'est pas encore expirée
                $job->markAsCompleted([
                    'skipped' => true,
                    'reason' => 'Authorization not yet expired',
                    'current_status' => $authorization->status,
                    'expiry_type' => $expiryType,
                ]);
                return true;
            }

            // Si l'autorisation est déjà expirée ou dans un état final, rien à faire
            if ($authorization->isExpired() || $authorization->isCaptured() || $authorization->isCancelled()) {
                $job->markAsCompleted([
                    'skipped' => true,
                    'reason' => 'Authorization already in final state',
                    'current_status' => $authorization->status,
                ]);
                return true;
            }

            // Faire expirer l'autorisation
            $success = $this->paymentService->expireAuthorization($authorization);

            if ($success) {
                $job->markAsCompleted([
                    'expired_authorization_id' => $authorization->id,
                    'expiry_reason' => $reason,
                    'expiry_type' => $expiryType,
                ]);

                PaymentEventLog::create([
                    'payment_authorization_id' => $authorization->id,
                    'booking_id' => $authorization->booking_id,
                    'event_type' => PaymentEventLog::EVENT_AUTHORIZATION_EXPIRED,
                    'success' => true,
                    'event_data' => [
                        'job_id' => $job->id,
                        'expiry_reason' => $reason,
                        'expiry_type' => $expiryType,
                        'execution_type' => 'automatic',
                    ],
                ]);

                return true;
            } else {
                $job->markAsFailed('Failed to expire authorization');
                return false;
            }

        } catch (\Exception $e) {
            $job->markAsFailed($e->getMessage());

            PaymentEventLog::create([
                'payment_authorization_id' => $job->payment_authorization_id,
                'booking_id' => $job->booking_id,
                'event_type' => PaymentEventLog::EVENT_AUTHORIZATION_EXPIRED,
                'success' => false,
                'error_message' => $e->getMessage(),
                'event_data' => [
                    'job_id' => $job->id,
                    'execution_type' => 'automatic',
                ],
            ]);

            return false;
        }
    }

    /**
     * Traiter tous les jobs d'expiration en attente
     */
    public function processAllPendingExpiries(): array
    {
        $jobs = ScheduledJob::readyToExecute()
                           ->where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                           ->take(100) // Traiter plus d'expirations car c'est moins coûteux
                           ->get();

        $results = [
            'processed' => 0,
            'successful' => 0,
            'failed' => 0,
            'skipped' => 0,
        ];

        foreach ($jobs as $job) {
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
                error_log("Erreur lors du traitement du job d'expiration {$job->id}: " . $e->getMessage());
            }
        }

        return $results;
    }

    /**
     * Detecter et traiter les autorisations expirées manuellement
     */
    public function processExpiredAuthorizations(): array
    {
        $results = [
            'confirmation_expired' => 0,
            'capture_expired' => 0,
            'already_processed' => 0,
            'errors' => 0,
        ];

        // Autorisations avec confirmation expirée
        $confirmationExpired = PaymentAuthorization::expired()->get();
        foreach ($confirmationExpired as $auth) {
            try {
                if (!$auth->isExpired()) {
                    $this->paymentService->expireAuthorization($auth);
                    $results['confirmation_expired']++;
                } else {
                    $results['already_processed']++;
                }
            } catch (\Exception $e) {
                $results['errors']++;
                error_log("Erreur expiration confirmation {$auth->id}: " . $e->getMessage());
            }
        }

        // Autorisations confirmées avec capture expirée
        $captureExpired = PaymentAuthorization::expiredConfirmed()->get();
        foreach ($captureExpired as $auth) {
            try {
                if (!$auth->isExpired()) {
                    $this->paymentService->expireAuthorization($auth);
                    $results['capture_expired']++;
                } else {
                    $results['already_processed']++;
                }
            } catch (\Exception $e) {
                $results['errors']++;
                error_log("Erreur expiration capture {$auth->id}: " . $e->getMessage());
            }
        }

        return $results;
    }

    /**
     * Programmer l'expiration pour une autorisation
     */
    public function scheduleExpiry(PaymentAuthorization $authorization): array
    {
        $jobs = [];

        // Job d'expiration de confirmation si nécessaire
        if ($authorization->isPending() && $authorization->confirmation_deadline) {
            $existingJob = ScheduledJob::where('payment_authorization_id', $authorization->id)
                                      ->where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                                      ->where('status', ScheduledJob::STATUS_PENDING)
                                      ->whereJsonContains('job_data->expiry_type', 'confirmation')
                                      ->first();

            if (!$existingJob) {
                $jobs[] = ScheduledJob::schedulePaymentExpiry($authorization);
            }
        }

        // Job d'expiration de capture si nécessaire
        if ($authorization->isConfirmed() && $authorization->expires_at) {
            $existingJob = ScheduledJob::where('payment_authorization_id', $authorization->id)
                                      ->where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                                      ->where('status', ScheduledJob::STATUS_PENDING)
                                      ->whereJsonContains('job_data->expiry_type', 'capture')
                                      ->first();

            if (!$existingJob && !$authorization->expires_at->isPast()) {
                $jobs[] = ScheduledJob::create([
                    'type' => ScheduledJob::TYPE_PAYMENT_EXPIRY,
                    'payment_authorization_id' => $authorization->id,
                    'booking_id' => $authorization->booking_id,
                    'scheduled_at' => $authorization->expires_at,
                    'priority' => 3,
                    'job_data' => [
                        'expiry_type' => 'capture',
                    ],
                ]);
            }
        }

        return array_filter($jobs);
    }

    /**
     * Obtenir les statistiques des expirations
     */
    public function getExpiryStatistics(int $days = 7): array
    {
        $startDate = now()->subDays($days);

        $stats = [
            'total_expiry_jobs' => ScheduledJob::where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                                             ->where('created_at', '>=', $startDate)
                                             ->count(),
            'by_status' => ScheduledJob::where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                                     ->where('created_at', '>=', $startDate)
                                     ->selectRaw('status, COUNT(*) as count')
                                     ->groupBy('status')
                                     ->pluck('count', 'status')
                                     ->toArray(),
            'expired_authorizations' => PaymentAuthorization::where('status', PaymentAuthorization::STATUS_EXPIRED)
                                                           ->where('updated_at', '>=', $startDate)
                                                           ->count(),
            'by_expiry_type' => $this->getExpiryTypeBreakdown($days),
            'upcoming_expiries' => $this->getUpcomingExpiries(),
        ];

        return $stats;
    }

    private function getExpiryTypeBreakdown(int $days): array
    {
        $events = PaymentEventLog::where('event_type', PaymentEventLog::EVENT_AUTHORIZATION_EXPIRED)
                                ->where('created_at', '>=', now()->subDays($days))
                                ->get();

        $breakdown = ['confirmation' => 0, 'capture' => 0, 'unknown' => 0];

        foreach ($events as $event) {
            $expiryType = $event->event_data['expiry_type'] ?? 'unknown';
            $breakdown[$expiryType] = ($breakdown[$expiryType] ?? 0) + 1;
        }

        return $breakdown;
    }

    private function getUpcomingExpiries(): array
    {
        $next24h = ScheduledJob::where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                              ->where('status', ScheduledJob::STATUS_PENDING)
                              ->where('scheduled_at', '>', now())
                              ->where('scheduled_at', '<=', now()->addDay())
                              ->count();

        $nextWeek = ScheduledJob::where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                               ->where('status', ScheduledJob::STATUS_PENDING)
                               ->where('scheduled_at', '>', now()->addDay())
                               ->where('scheduled_at', '<=', now()->addWeek())
                               ->count();

        return [
            'next_24h' => $next24h,
            'next_week' => $nextWeek,
        ];
    }

    /**
     * Nettoyer les anciens jobs d'expiration
     */
    public function cleanupOldJobs(int $daysToKeep = 30): int
    {
        return ScheduledJob::where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                          ->whereIn('status', [ScheduledJob::STATUS_COMPLETED, ScheduledJob::STATUS_CANCELLED])
                          ->where('updated_at', '<', now()->subDays($daysToKeep))
                          ->delete();
    }

    /**
     * Valider les jobs d'expiration programmés
     */
    public function validateExpiryJobs(): array
    {
        $issues = [];

        // Jobs d'expiration dans le passé qui ne sont pas exécutés
        $overdueJobs = ScheduledJob::where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                                  ->where('status', ScheduledJob::STATUS_PENDING)
                                  ->where('scheduled_at', '<', now()->subMinutes(10))
                                  ->get();

        foreach ($overdueJobs as $job) {
            if ($job->paymentAuthorization) {
                // Exécuter immédiatement
                try {
                    $this->execute($job);
                    $issues[] = "Job d'expiration en retard exécuté: {$job->id}";
                } catch (\Exception $e) {
                    $job->markAsFailed('Overdue execution failed: ' . $e->getMessage());
                    $issues[] = "Job d'expiration en retard échoué: {$job->id}";
                }
            } else {
                $job->cancel('Payment authorization not found');
                $issues[] = "Job d'expiration orphelin annulé: {$job->id}";
            }
        }

        // Autorisations expirées sans job correspondant
        $expiredAuths = PaymentAuthorization::where(function ($query) {
                                               $query->where('status', PaymentAuthorization::STATUS_PENDING)
                                                     ->where('confirmation_deadline', '<', now())
                                                     ->orWhere(function ($subQuery) {
                                                         $subQuery->where('status', PaymentAuthorization::STATUS_CONFIRMED)
                                                                  ->where('expires_at', '<', now());
                                                     });
                                           })
                                           ->whereDoesntHave('scheduledJobs', function ($query) {
                                               $query->where('type', ScheduledJob::TYPE_PAYMENT_EXPIRY)
                                                     ->whereIn('status', [ScheduledJob::STATUS_COMPLETED, ScheduledJob::STATUS_RUNNING]);
                                           })
                                           ->get();

        foreach ($expiredAuths as $auth) {
            try {
                $this->paymentService->expireAuthorization($auth);
                $issues[] = "Autorisation expirée manuellement: {$auth->id}";
            } catch (\Exception $e) {
                $issues[] = "Erreur expiration manuelle {$auth->id}: " . $e->getMessage();
            }
        }

        return [
            'issues_found' => count($issues),
            'issues' => $issues,
        ];
    }
}