<?php

declare(strict_types=1);

namespace KiloShare\Jobs;

use KiloShare\Models\ScheduledJob;
use KiloShare\Models\PaymentAuthorization;
use KiloShare\Services\PaymentAuthorizationService;
use KiloShare\Services\SmartNotificationService;

class JobScheduler
{
    private PaymentCaptureJob $captureJob;
    private PaymentExpiryJob $expiryJob;
    private PaymentReminderJob $reminderJob;
    private PaymentAuthorizationService $paymentService;
    private SmartNotificationService $notificationService;

    public function __construct(
        PaymentCaptureJob $captureJob,
        PaymentExpiryJob $expiryJob,
        PaymentReminderJob $reminderJob,
        PaymentAuthorizationService $paymentService,
        SmartNotificationService $notificationService
    ) {
        $this->captureJob = $captureJob;
        $this->expiryJob = $expiryJob;
        $this->reminderJob = $reminderJob;
        $this->paymentService = $paymentService;
        $this->notificationService = $notificationService;
    }

    /**
     * Exécuter tous les jobs en attente
     */
    public function processAllJobs(): array
    {
        $startTime = microtime(true);
        $results = [
            'execution_time' => 0,
            'total_processed' => 0,
            'capture_jobs' => ['processed' => 0, 'successful' => 0, 'failed' => 0, 'skipped' => 0],
            'expiry_jobs' => ['processed' => 0, 'successful' => 0, 'failed' => 0, 'skipped' => 0],
            'reminder_jobs' => ['processed' => 0, 'successful' => 0, 'failed' => 0, 'skipped' => 0],
            'errors' => [],
        ];

        try {
            // Traiter les jobs de capture
            $captureResults = $this->captureJob->processAllPendingCaptures();
            $results['capture_jobs'] = $captureResults;
            $results['total_processed'] += $captureResults['processed'];

        } catch (\Exception $e) {
            $results['errors'][] = 'Capture jobs error: ' . $e->getMessage();
        }

        try {
            // Traiter les jobs d'expiration
            $expiryResults = $this->expiryJob->processAllPendingExpiries();
            $results['expiry_jobs'] = $expiryResults;
            $results['total_processed'] += $expiryResults['processed'];

        } catch (\Exception $e) {
            $results['errors'][] = 'Expiry jobs error: ' . $e->getMessage();
        }

        try {
            // Traiter les jobs de rappel
            $reminderResults = $this->reminderJob->processAllPendingReminders();
            $results['reminder_jobs'] = $reminderResults;
            $results['total_processed'] += $reminderResults['processed'];

        } catch (\Exception $e) {
            $results['errors'][] = 'Reminder jobs error: ' . $e->getMessage();
        }

        $results['execution_time'] = round((microtime(true) - $startTime) * 1000, 2);

        return $results;
    }

    /**
     * Programmer tous les jobs pour une autorisation de paiement
     */
    public function scheduleAllJobsForAuthorization(PaymentAuthorization $authorization): array
    {
        $scheduledJobs = [];

        try {
            // Job d'expiration selon le statut
            $expiryJobs = $this->expiryJob->scheduleExpiry($authorization);
            $scheduledJobs = array_merge($scheduledJobs, $expiryJobs);

            // Job de capture automatique si confirmé
            if ($authorization->isConfirmed() && $authorization->auto_capture_at) {
                $captureJob = $this->captureJob->scheduleAutomaticCapture($authorization);
                if ($captureJob) {
                    $scheduledJobs[] = $captureJob;
                }
            }

            // Jobs de rappel
            $reminderJobs = $this->reminderJob->scheduleReminders($authorization);
            $scheduledJobs = array_merge($scheduledJobs, $reminderJobs);

        } catch (\Exception $e) {
            error_log("Erreur lors de la programmation des jobs pour l'autorisation {$authorization->id}: " . $e->getMessage());
        }

        return $scheduledJobs;
    }

    /**
     * Annuler tous les jobs en attente pour une autorisation
     */
    public function cancelAllJobsForAuthorization(PaymentAuthorization $authorization, string $reason = 'Authorization processed'): int
    {
        return ScheduledJob::where('payment_authorization_id', $authorization->id)
                          ->where('status', ScheduledJob::STATUS_PENDING)
                          ->update([
                              'status' => ScheduledJob::STATUS_CANCELLED,
                              'error_message' => $reason,
                              'executed_at' => now(),
                          ]);
    }

    /**
     * Obtenir le statut de la queue des jobs
     */
    public function getQueueStatus(): array
    {
        $stats = ScheduledJob::getQueueStats();

        // Ajouter des détails par type
        $stats['by_type'] = ScheduledJob::where('status', ScheduledJob::STATUS_PENDING)
                                       ->selectRaw('type, COUNT(*) as count')
                                       ->groupBy('type')
                                       ->pluck('count', 'type')
                                       ->toArray();

        // Jobs en retard
        $stats['overdue'] = ScheduledJob::where('status', ScheduledJob::STATUS_PENDING)
                                       ->where('scheduled_at', '<', now()->subMinutes(5))
                                       ->count();

        // Prochains jobs à exécuter
        $nextJobs = ScheduledJob::where('status', ScheduledJob::STATUS_PENDING)
                               ->where('scheduled_at', '>', now())
                               ->orderBy('scheduled_at')
                               ->take(5)
                               ->get(['id', 'type', 'scheduled_at', 'priority']);

        $stats['upcoming'] = $nextJobs->map(function ($job) {
            return [
                'id' => $job->id,
                'type' => $job->type,
                'scheduled_at' => $job->scheduled_at->toISOString(),
                'priority' => $job->priority,
                'minutes_until_execution' => $job->scheduled_at->diffInMinutes(now()),
            ];
        })->toArray();

        return $stats;
    }

    /**
     * Nettoyer tous les anciens jobs
     */
    public function cleanupAllOldJobs(int $daysToKeep = 30): array
    {
        return [
            'capture_jobs_deleted' => $this->captureJob->cleanupOldJobs($daysToKeep),
            'expiry_jobs_deleted' => $this->expiryJob->cleanupOldJobs($daysToKeep),
            'reminder_jobs_deleted' => $this->reminderJob->cleanupOldJobs($daysToKeep),
        ];
    }

    /**
     * Valider l'intégrité de tous les jobs
     */
    public function validateAllJobs(): array
    {
        $results = [
            'total_issues' => 0,
            'capture_validation' => [],
            'expiry_validation' => [],
            'general_validation' => [],
        ];

        try {
            $captureValidation = $this->captureJob->validateScheduledJobs();
            $results['capture_validation'] = $captureValidation;
            $results['total_issues'] += $captureValidation['issues_found'];
        } catch (\Exception $e) {
            $results['capture_validation'] = ['error' => $e->getMessage()];
        }

        try {
            $expiryValidation = $this->expiryJob->validateExpiryJobs();
            $results['expiry_validation'] = $expiryValidation;
            $results['total_issues'] += $expiryValidation['issues_found'];
        } catch (\Exception $e) {
            $results['expiry_validation'] = ['error' => $e->getMessage()];
        }

        // Validations générales
        $generalIssues = $this->performGeneralValidation();
        $results['general_validation'] = $generalIssues;
        $results['total_issues'] += count($generalIssues['issues']);

        return $results;
    }

    private function performGeneralValidation(): array
    {
        $issues = [];

        // Jobs en cours depuis trop longtemps
        $stuckJobs = ScheduledJob::where('status', ScheduledJob::STATUS_RUNNING)
                                ->where('updated_at', '<', now()->subMinutes(30))
                                ->get();

        foreach ($stuckJobs as $job) {
            $job->markAsFailed('Job stuck in running state');
            $issues[] = "Job bloqué réinitialisé: {$job->id}";
        }

        // Autorisations sans jobs programmés appropriés
        $authsNeedingJobs = PaymentAuthorization::whereIn('status', [
                                                   PaymentAuthorization::STATUS_PENDING,
                                                   PaymentAuthorization::STATUS_CONFIRMED
                                               ])
                                               ->whereDoesntHave('scheduledJobs', function ($query) {
                                                   $query->where('status', ScheduledJob::STATUS_PENDING);
                                               })
                                               ->get();

        foreach ($authsNeedingJobs as $auth) {
            try {
                $this->scheduleAllJobsForAuthorization($auth);
                $issues[] = "Jobs programmés pour l'autorisation: {$auth->id}";
            } catch (\Exception $e) {
                $issues[] = "Erreur programmation jobs pour {$auth->id}: " . $e->getMessage();
            }
        }

        return [
            'issues_found' => count($issues),
            'issues' => $issues,
        ];
    }

    /**
     * Obtenir les statistiques complètes du système de jobs
     */
    public function getSystemStatistics(): array
    {
        return [
            'queue_status' => $this->getQueueStatus(),
            'capture_stats' => $this->captureJob->getCaptureStatistics(),
            'expiry_stats' => $this->expiryJob->getExpiryStatistics(),
            'reminder_stats' => $this->reminderJob->getReminderStatistics(),
            'performance_metrics' => $this->getPerformanceMetrics(),
        ];
    }

    private function getPerformanceMetrics(): array
    {
        $last24h = now()->subDay();

        return [
            'jobs_processed_24h' => ScheduledJob::where('executed_at', '>=', $last24h)->count(),
            'average_queue_time' => $this->getAverageQueueTime(),
            'success_rate_24h' => $this->getSuccessRate24h(),
            'peak_queue_size' => $this->getPeakQueueSize(),
        ];
    }

    private function getAverageQueueTime(): ?float
    {
        $jobs = ScheduledJob::whereIn('status', [ScheduledJob::STATUS_COMPLETED, ScheduledJob::STATUS_FAILED])
                           ->whereNotNull('executed_at')
                           ->where('executed_at', '>=', now()->subDay())
                           ->get();

        if ($jobs->isEmpty()) {
            return null;
        }

        $totalMinutes = $jobs->sum(function ($job) {
            return $job->scheduled_at->diffInMinutes($job->executed_at);
        });

        return $totalMinutes / $jobs->count();
    }

    private function getSuccessRate24h(): float
    {
        $last24h = now()->subDay();
        $total = ScheduledJob::whereIn('status', [ScheduledJob::STATUS_COMPLETED, ScheduledJob::STATUS_FAILED])
                            ->where('executed_at', '>=', $last24h)
                            ->count();

        $successful = ScheduledJob::where('status', ScheduledJob::STATUS_COMPLETED)
                                 ->where('executed_at', '>=', $last24h)
                                 ->count();

        return $total > 0 ? ($successful / $total) * 100 : 0;
    }

    private function getPeakQueueSize(): int
    {
        // Estimation basée sur les jobs créés vs traités
        return ScheduledJob::where('status', ScheduledJob::STATUS_PENDING)->count();
    }

    /**
     * Redémarrer les jobs échoués qui peuvent être retentés
     */
    public function retryFailedJobs(): array
    {
        $retryableJobs = ScheduledJob::failedRetryable()->get();
        $results = ['retried' => 0, 'skipped' => 0, 'errors' => []];

        foreach ($retryableJobs as $job) {
            try {
                if ($job->canRetry()) {
                    $job->status = ScheduledJob::STATUS_PENDING;
                    $delayMinutes = min(60, pow(2, $job->attempts) * 5);
                    $job->scheduled_at = now()->addMinutes($delayMinutes);
                    $job->save();
                    $results['retried']++;
                } else {
                    $results['skipped']++;
                }
            } catch (\Exception $e) {
                $results['errors'][] = "Erreur retry job {$job->id}: " . $e->getMessage();
            }
        }

        return $results;
    }
}