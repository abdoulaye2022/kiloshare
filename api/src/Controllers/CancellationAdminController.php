<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Trip;
use KiloShare\Models\User;
use KiloShare\Utils\Response;
use KiloShare\Services\UserReliabilityService;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Illuminate\Database\Capsule\Manager as DB;
use Carbon\Carbon;
use Exception;

class CancellationAdminController
{
    private UserReliabilityService $reliabilityService;

    public function __construct()
    {
        $this->reliabilityService = new UserReliabilityService();
    }

    /**
     * Dashboard des annulations pour l'admin
     * GET /api/v1/admin/cancellations/dashboard
     */
    public function getCancellationDashboard(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $queryParams = $request->getQueryParams();
            $period = $queryParams['period'] ?? '30'; // 30 derniers jours par défaut

            $startDate = Carbon::now()->subDays((int)$period);

            // Statistiques générales
            $stats = [
                'total_cancellations' => $this->getTotalCancellations($startDate),
                'cancellations_by_type' => $this->getCancellationsByType($startDate),
                'cancellations_by_severity' => $this->getCancellationsBySeverity($startDate),
                'affected_users' => $this->getAffectedUsersCount($startDate),
                'refunds_processed' => $this->getRefundsProcessed($startDate),
                'penalties_applied' => $this->getPenaltiesApplied($startDate),
                'reliability_trends' => $this->getReliabilityTrends($startDate)
            ];

            // Utilisateurs avec le plus d'annulations
            $problematicUsers = $this->getProblematicUsers($startDate);

            // Tickets de support automatiques
            $autoTickets = $this->getAutoSupportTickets();

            return Response::success([
                'period_days' => (int)$period,
                'period_start' => $startDate->toISOString(),
                'statistics' => $stats,
                'problematic_users' => $problematicUsers,
                'auto_support_tickets' => $autoTickets
            ], 'Cancellation dashboard data retrieved');

        } catch (Exception $e) {
            error_log("CancellationAdminController::getCancellationDashboard Error: " . $e->getMessage());
            return Response::error('Failed to retrieve dashboard data', [], 500);
        }
    }

    /**
     * Liste des tickets de support automatiques
     * GET /api/v1/admin/cancellations/support-tickets
     */
    public function getAutoSupportTickets(ServerRequestInterface $request = null): array
    {
        $queryParams = $request ? $request->getQueryParams() : [];
        $status = $queryParams['status'] ?? 'open';
        $limit = min((int)($queryParams['limit'] ?? 20), 100);

        return DB::table('auto_support_tickets')
            ->leftJoin('trips', 'auto_support_tickets.trip_id', '=', 'trips.id')
            ->leftJoin('users', 'auto_support_tickets.user_id', '=', 'users.id')
            ->select([
                'auto_support_tickets.*',
                'trips.title as trip_title',
                'trips.departure_city',
                'trips.arrival_city',
                'users.first_name',
                'users.last_name',
                'users.email'
            ])
            ->where('auto_support_tickets.status', $status)
            ->orderBy('auto_support_tickets.priority', 'desc')
            ->orderBy('auto_support_tickets.created_at', 'desc')
            ->limit($limit)
            ->get()
            ->toArray();
    }

    /**
     * Traiter un ticket de support
     * POST /api/v1/admin/cancellations/support-tickets/{id}/resolve
     */
    public function resolveSupportTicket(ServerRequestInterface $request): ResponseInterface
    {
        $ticketId = (int) $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true) ?? [];

        try {
            $ticket = DB::table('auto_support_tickets')->where('id', $ticketId)->first();

            if (!$ticket) {
                return Response::notFound('Support ticket not found');
            }

            $resolutionNotes = $data['resolution_notes'] ?? '';
            $status = $data['status'] ?? 'resolved';

            DB::table('auto_support_tickets')
                ->where('id', $ticketId)
                ->update([
                    'status' => $status,
                    'resolution_notes' => $resolutionNotes,
                    'resolved_at' => Carbon::now(),
                    'updated_at' => Carbon::now()
                ]);

            return Response::success([
                'ticket_id' => $ticketId,
                'status' => $status,
                'resolved_at' => Carbon::now()->toISOString()
            ], 'Support ticket resolved');

        } catch (Exception $e) {
            error_log("CancellationAdminController::resolveSupportTicket Error: " . $e->getMessage());
            return Response::error('Failed to resolve support ticket', [], 500);
        }
    }

    /**
     * Gérer les exceptions d'annulation
     * POST /api/v1/admin/cancellations/exceptions
     */
    public function handleCancellationException(ServerRequestInterface $request): ResponseInterface
    {
        $data = json_decode($request->getBody()->getContents(), true) ?? [];

        try {
            $userId = $data['user_id'] ?? null;
            $exceptionType = $data['exception_type'] ?? null; // 'force_majeure', 'technical_issue', 'first_time_user'
            $reason = $data['reason'] ?? '';
            $action = $data['action'] ?? null; // 'remove_penalty', 'restore_reliability', 'manual_refund'

            if (!$userId || !$exceptionType || !$action) {
                return Response::error('Missing required fields: user_id, exception_type, action', [], 400);
            }

            $user = User::find($userId);
            if (!$user) {
                return Response::notFound('User not found');
            }

            $result = $this->processException($user, $exceptionType, $action, $reason);

            return Response::success($result, 'Exception processed successfully');

        } catch (Exception $e) {
            error_log("CancellationAdminController::handleCancellationException Error: " . $e->getMessage());
            return Response::error('Failed to process exception', [], 500);
        }
    }

    /**
     * Réinitialiser le score de fiabilité d'un utilisateur
     * POST /api/v1/admin/users/{id}/reset-reliability
     */
    public function resetUserReliability(ServerRequestInterface $request): ResponseInterface
    {
        $userId = (int) $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true) ?? [];

        try {
            $user = User::find($userId);
            if (!$user) {
                return Response::notFound('User not found');
            }

            $newScore = $data['new_score'] ?? 100;
            $reason = $data['reason'] ?? 'Admin reset';

            // Mise à jour du score de fiabilité
            $this->reliabilityService->updateUserReliability(
                $userId,
                $newScore - ($user->reliability_score ?? 100),
                'admin_reset',
                $reason
            );

            // Suppression des restrictions si applicable
            if ($data['remove_restrictions'] ?? false) {
                DB::table('users')
                    ->where('id', $userId)
                    ->update([
                        'is_suspended' => false,
                        'suspension_reason' => null,
                        'suspended_until' => null,
                        'publication_restricted_until' => null
                    ]);
            }

            return Response::success([
                'user_id' => $userId,
                'new_reliability_score' => $newScore,
                'restrictions_removed' => $data['remove_restrictions'] ?? false
            ], 'User reliability reset successfully');

        } catch (Exception $e) {
            error_log("CancellationAdminController::resetUserReliability Error: " . $e->getMessage());
            return Response::error('Failed to reset user reliability', [], 500);
        }
    }

    /**
     * Rapport détaillé des annulations
     * GET /api/v1/admin/cancellations/detailed-report
     */
    public function getDetailedCancellationReport(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $queryParams = $request->getQueryParams();
            $startDate = $queryParams['start_date'] ?? Carbon::now()->subDays(30)->toDateString();
            $endDate = $queryParams['end_date'] ?? Carbon::now()->toDateString();
            $userId = $queryParams['user_id'] ?? null;

            $query = DB::table('cancellation_attempts')
                ->leftJoin('trips', 'cancellation_attempts.trip_id', '=', 'trips.id')
                ->leftJoin('users', 'cancellation_attempts.user_id', '=', 'users.id')
                ->select([
                    'cancellation_attempts.*',
                    'trips.title as trip_title',
                    'trips.departure_city',
                    'trips.arrival_city',
                    'trips.departure_date',
                    'trips.status as trip_status',
                    'users.first_name',
                    'users.last_name',
                    'users.email',
                    'users.reliability_score'
                ])
                ->whereBetween('cancellation_attempts.created_at', [$startDate, $endDate]);

            if ($userId) {
                $query->where('cancellation_attempts.user_id', $userId);
            }

            $cancellations = $query->orderBy('cancellation_attempts.created_at', 'desc')
                ->get()
                ->toArray();

            // Enrichir avec les données de remboursement
            foreach ($cancellations as &$cancellation) {
                if ($cancellation->trip_id) {
                    $refunds = DB::table('transactions')
                        ->where('trip_id', $cancellation->trip_id)
                        ->where('type', 'refund')
                        ->sum('amount');

                    $cancellation->total_refunds = (float) $refunds;
                }
            }

            return Response::success([
                'report_period' => [
                    'start_date' => $startDate,
                    'end_date' => $endDate
                ],
                'total_cancellations' => count($cancellations),
                'cancellations' => $cancellations
            ], 'Detailed cancellation report generated');

        } catch (Exception $e) {
            error_log("CancellationAdminController::getDetailedCancellationReport Error: " . $e->getMessage());
            return Response::error('Failed to generate detailed report', [], 500);
        }
    }

    // Méthodes privées pour les statistiques

    private function getTotalCancellations(Carbon $startDate): int
    {
        return DB::table('cancellation_attempts')
            ->where('is_allowed', true)
            ->where('created_at', '>=', $startDate)
            ->count();
    }

    private function getCancellationsByType(Carbon $startDate): array
    {
        return DB::table('cancellation_attempts')
            ->select('attempt_type', DB::raw('COUNT(*) as count'))
            ->where('is_allowed', true)
            ->where('created_at', '>=', $startDate)
            ->groupBy('attempt_type')
            ->get()
            ->pluck('count', 'attempt_type')
            ->toArray();
    }

    private function getCancellationsBySeverity(Carbon $startDate): array
    {
        // Approximation basée sur les jours avant départ
        return DB::table('cancellation_attempts')
            ->leftJoin('trips', 'cancellation_attempts.trip_id', '=', 'trips.id')
            ->select(
                DB::raw('
                    CASE
                        WHEN TIMESTAMPDIFF(HOUR, cancellation_attempts.created_at, trips.departure_date) < 24 THEN "critical"
                        WHEN TIMESTAMPDIFF(HOUR, cancellation_attempts.created_at, trips.departure_date) < 48 THEN "high"
                        ELSE "low"
                    END as severity
                '),
                DB::raw('COUNT(*) as count')
            )
            ->where('cancellation_attempts.is_allowed', true)
            ->where('cancellation_attempts.created_at', '>=', $startDate)
            ->groupBy('severity')
            ->get()
            ->pluck('count', 'severity')
            ->toArray();
    }

    private function getAffectedUsersCount(Carbon $startDate): int
    {
        return DB::table('cancellation_attempts')
            ->distinct('user_id')
            ->where('is_allowed', true)
            ->where('created_at', '>=', $startDate)
            ->count();
    }

    private function getRefundsProcessed(Carbon $startDate): array
    {
        $refunds = DB::table('transactions')
            ->where('type', 'refund')
            ->where('auto_processed', true)
            ->where('created_at', '>=', $startDate)
            ->selectRaw('COUNT(*) as count, SUM(amount) as total_amount')
            ->first();

        return [
            'count' => $refunds->count ?? 0,
            'total_amount' => (float) ($refunds->total_amount ?? 0)
        ];
    }

    private function getPenaltiesApplied(Carbon $startDate): array
    {
        $suspended = DB::table('users')
            ->where('is_suspended', true)
            ->where('suspended_until', '>=', $startDate)
            ->count();

        $restricted = DB::table('users')
            ->where('publication_restricted_until', '>=', $startDate)
            ->count();

        return [
            'account_suspensions' => $suspended,
            'publication_restrictions' => $restricted
        ];
    }

    private function getReliabilityTrends(Carbon $startDate): array
    {
        return DB::table('user_reliability_history')
            ->select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('AVG(new_score) as avg_score'),
                DB::raw('COUNT(*) as changes_count')
            )
            ->where('created_at', '>=', $startDate)
            ->groupBy('date')
            ->orderBy('date')
            ->get()
            ->toArray();
    }

    private function getProblematicUsers(Carbon $startDate): array
    {
        return DB::table('cancellation_attempts')
            ->leftJoin('users', 'cancellation_attempts.user_id', '=', 'users.id')
            ->select([
                'users.id',
                'users.first_name',
                'users.last_name',
                'users.email',
                'users.reliability_score',
                DB::raw('COUNT(*) as cancellation_count')
            ])
            ->where('cancellation_attempts.is_allowed', true)
            ->where('cancellation_attempts.created_at', '>=', $startDate)
            ->groupBy('users.id', 'users.first_name', 'users.last_name', 'users.email', 'users.reliability_score')
            ->having('cancellation_count', '>', 1)
            ->orderBy('cancellation_count', 'desc')
            ->limit(10)
            ->get()
            ->toArray();
    }

    private function processException(User $user, string $exceptionType, string $action, string $reason): array
    {
        $result = ['actions_taken' => []];

        switch ($action) {
            case 'remove_penalty':
                DB::table('users')
                    ->where('id', $user->id)
                    ->update([
                        'is_suspended' => false,
                        'suspension_reason' => null,
                        'suspended_until' => null,
                        'publication_restricted_until' => null
                    ]);
                $result['actions_taken'][] = 'Penalties removed';
                break;

            case 'restore_reliability':
                $this->reliabilityService->updateUserReliability(
                    $user->id,
                    10, // Bonus pour exception
                    'admin_exception',
                    "Exception granted: $exceptionType - $reason"
                );
                $result['actions_taken'][] = 'Reliability score restored';
                break;

            case 'manual_refund':
                // Logique de remboursement manuel (à implémenter selon besoins)
                $result['actions_taken'][] = 'Manual refund processed';
                break;
        }

        // Enregistrer l'exception dans les logs
        DB::table('user_reliability_history')->insert([
            'user_id' => $user->id,
            'action' => 'admin_exception',
            'impact' => 0,
            'previous_score' => $user->reliability_score ?? 100,
            'new_score' => $user->reliability_score ?? 100,
            'description' => "Exception: $exceptionType - Action: $action - Reason: $reason",
            'created_at' => Carbon::now()
        ]);

        return $result;
    }
}