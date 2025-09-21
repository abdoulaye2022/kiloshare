<?php

declare(strict_types=1);

namespace KiloShare\Jobs;

use KiloShare\Models\ScheduledJob;
use KiloShare\Models\PaymentAuthorization;
use KiloShare\Services\PaymentAuthorizationService;
use KiloShare\Models\PaymentEventLog;
use Carbon\Carbon;

class PaymentCaptureJob
{
    private PaymentAuthorizationService $paymentService;

    public function __construct(PaymentAuthorizationService $paymentService)
    {
        $this->paymentService = $paymentService;
    }

    /**
     * Exécuter un job de capture automatique
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

            // Vérifier que l'autorisation peut encore être capturée
            if (!$authorization->canBeCaptured()) {
                $job->markAsCompleted([
                    'skipped' => true,
                    'reason' => 'Authorization cannot be captured anymore',
                    'current_status' => $authorization->status,
                ]);
                return true;
            }

            // Déterminer la raison de capture depuis les données du job
            $jobData = $job->job_data ?? [];
            $captureReason = $jobData['capture_reason'] ?? PaymentAuthorization::CAPTURE_REASON_AUTO_72H;

            // Effectuer la capture
            $success = $this->paymentService->capturePayment($authorization, $captureReason);

            if ($success) {
                $job->markAsCompleted([
                    'captured_amount' => $authorization->amount_cents,
                    'capture_reason' => $captureReason,
                    'authorization_id' => $authorization->id,
                ]);

                PaymentEventLog::create([
                    'payment_authorization_id' => $authorization->id,
                    'booking_id' => $authorization->booking_id,
                    'event_type' => PaymentEventLog::EVENT_CAPTURE_SUCCEEDED,
                    'success' => true,
                    'event_data' => [
                        'job_id' => $job->id,
                        'capture_reason' => $captureReason,
                        'execution_type' => 'automatic',
                    ],
                ]);

                return true;
            } else {
                $job->markAsFailed('Payment capture failed');
                return false;
            }

        } catch (\Exception $e) {
            $job->markAsFailed($e->getMessage());

            PaymentEventLog::create([
                'payment_authorization_id' => $job->payment_authorization_id,
                'booking_id' => $job->booking_id,
                'event_type' => PaymentEventLog::EVENT_CAPTURE_FAILED,
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
     * Traiter tous les jobs de capture en attente
     */
    public function processAllPendingCaptures(): array
    {
        $jobs = ScheduledJob::readyToExecute()
                           ->where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                           ->take(50) // Limiter le nombre de jobs traités en une fois
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
                error_log("Erreur lors du traitement du job {$job->id}: " . $e->getMessage());
            }
        }

        return $results;
    }

    /**
     * Programmer la capture automatique pour une autorisation
     */
    public function scheduleAutomaticCapture(PaymentAuthorization $authorization): ?ScheduledJob
    {
        if (!$authorization->auto_capture_at || $authorization->auto_capture_at->isPast()) {
            return null;
        }

        // Vérifier qu'il n'y a pas déjà un job programmé
        $existingJob = ScheduledJob::where('payment_authorization_id', $authorization->id)
                                  ->where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                  ->where('status', ScheduledJob::STATUS_PENDING)
                                  ->first();

        if ($existingJob) {
            return $existingJob;
        }

        return ScheduledJob::scheduleAutoCapture($authorization);
    }

    /**
     * Reprogrammer un job de capture avec délai
     */
    public function rescheduleCapture(ScheduledJob $job, int $delayMinutes = 30): bool
    {
        if (!$job->canRetry()) {
            return false;
        }

        $job->status = ScheduledJob::STATUS_PENDING;
        $job->scheduled_at = now()->addMinutes($delayMinutes);

        return $job->save();
    }

    /**
     * Obtenir les statistiques des captures automatiques
     */
    public function getCaptureStatistics(int $days = 7): array
    {
        $startDate = now()->subDays($days);

        $stats = [
            'total_jobs' => ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                      ->where('created_at', '>=', $startDate)
                                      ->count(),
            'by_status' => ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                     ->where('created_at', '>=', $startDate)
                                     ->selectRaw('status, COUNT(*) as count')
                                     ->groupBy('status')
                                     ->pluck('count', 'status')
                                     ->toArray(),
            'success_rate' => $this->calculateSuccessRate($days),
            'average_execution_time' => $this->getAverageExecutionTime($days),
            'upcoming_captures' => ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                             ->where('status', ScheduledJob::STATUS_PENDING)
                                             ->where('scheduled_at', '>', now())
                                             ->count(),
        ];

        return $stats;
    }

    private function calculateSuccessRate(int $days): float
    {
        $startDate = now()->subDays($days);

        $total = ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                            ->where('created_at', '>=', $startDate)
                            ->whereIn('status', [ScheduledJob::STATUS_COMPLETED, ScheduledJob::STATUS_FAILED])
                            ->count();

        $successful = ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                 ->where('created_at', '>=', $startDate)
                                 ->where('status', ScheduledJob::STATUS_COMPLETED)
                                 ->count();

        return $total > 0 ? ($successful / $total) * 100 : 0;
    }

    private function getAverageExecutionTime(int $days): ?float
    {
        $jobs = ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                           ->where('created_at', '>=', now()->subDays($days))
                           ->where('status', ScheduledJob::STATUS_COMPLETED)
                           ->whereNotNull('executed_at')
                           ->get();

        if ($jobs->isEmpty()) {
            return null;
        }

        $totalSeconds = $jobs->sum(function ($job) {
            return $job->updated_at->diffInSeconds($job->executed_at);
        });

        return $totalSeconds / $jobs->count();
    }

    /**
     * Nettoyer les anciens jobs complétés
     */
    public function cleanupOldJobs(int $daysToKeep = 30): int
    {
        return ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                          ->whereIn('status', [ScheduledJob::STATUS_COMPLETED, ScheduledJob::STATUS_CANCELLED])
                          ->where('updated_at', '<', now()->subDays($daysToKeep))
                          ->delete();
    }

    /**
     * Valider l'intégrité des jobs programmés
     */
    public function validateScheduledJobs(): array
    {
        $issues = [];

        // Jobs orphelins (sans autorisation de paiement)
        $orphanJobs = ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                 ->where('status', ScheduledJob::STATUS_PENDING)
                                 ->whereDoesntHave('paymentAuthorization')
                                 ->get();

        foreach ($orphanJobs as $job) {
            $job->cancel('Payment authorization not found');
            $issues[] = "Job orphelin annulé: {$job->id}";
        }

        // Jobs programmés dans le passé qui ne sont pas exécutés
        $overdueJobs = ScheduledJob::where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                  ->where('status', ScheduledJob::STATUS_PENDING)
                                  ->where('scheduled_at', '<', now()->subHours(1))
                                  ->get();

        foreach ($overdueJobs as $job) {
            if ($job->paymentAuthorization && $job->paymentAuthorization->canBeCaptured()) {
                // Programmer immédiatement
                $job->scheduled_at = now();
                $job->save();
                $issues[] = "Job en retard reprogrammé: {$job->id}";
            } else {
                $job->cancel('Authorization no longer capturable');
                $issues[] = "Job en retard annulé: {$job->id}";
            }
        }

        // Autorisations confirmées sans job de capture
        $authsWithoutJobs = PaymentAuthorization::confirmed()
                                              ->whereDoesntHave('scheduledJobs', function ($query) {
                                                  $query->where('type', ScheduledJob::TYPE_AUTO_CAPTURE)
                                                        ->where('status', ScheduledJob::STATUS_PENDING);
                                              })
                                              ->whereNotNull('auto_capture_at')
                                              ->where('auto_capture_at', '>', now())
                                              ->get();

        foreach ($authsWithoutJobs as $auth) {
            ScheduledJob::scheduleAutoCapture($auth);
            $issues[] = "Job de capture créé pour l'autorisation: {$auth->id}";
        }

        return [
            'issues_found' => count($issues),
            'issues' => $issues,
        ];
    }
}