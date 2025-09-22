<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Trip;
use KiloShare\Models\User;
use KiloShare\Utils\Response;
use KiloShare\Services\IntelligentCancellationService;
use KiloShare\Services\UserReliabilityService;
use KiloShare\Services\AutoRefundService;
use KiloShare\Services\SmartNotificationService;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Exception;

class IntelligentCancellationController
{
    private IntelligentCancellationService $cancellationService;
    private UserReliabilityService $reliabilityService;

    public function __construct()
    {
        $notificationService = new SmartNotificationService();
        $this->reliabilityService = new UserReliabilityService();
        $refundService = new AutoRefundService($notificationService);

        $this->cancellationService = new IntelligentCancellationService(
            $notificationService,
            $this->reliabilityService,
            $refundService
        );
    }

    /**
     * Analyse intelligente des conditions d'annulation
     * GET /api/v1/trips/{id}/intelligent-cancellation-check
     */
    public function analyzeIntelligentCancellation(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = (int) $request->getAttribute('id');

        try {
            $trip = Trip::find($tripId);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            $analysis = $this->cancellationService->analyzeCancellationConditions($user, $trip);

            return Response::success([
                'analysis' => $analysis,
                'trip_info' => [
                    'id' => $trip->id,
                    'title' => $trip->title,
                    'departure_date' => $trip->departure_date,
                    'status' => $trip->status
                ]
            ], 'Cancellation analysis completed');

        } catch (Exception $e) {
            error_log("IntelligentCancellationController::analyzeIntelligentCancellation Error: " . $e->getMessage());
            return Response::error('Failed to analyze cancellation conditions', [], 500);
        }
    }

    /**
     * Exécute l'annulation intelligente
     * POST /api/v1/trips/{id}/intelligent-cancel
     */
    public function executeIntelligentCancellation(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = (int) $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true) ?? [];

        try {
            $trip = Trip::find($tripId);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            // Validation des données requises
            $validationResult = $this->validateCancellationData($data, $user, $trip);
            if (!$validationResult['valid']) {
                return Response::error($validationResult['message'], $validationResult['errors'], 400);
            }

            // Exécution de l'annulation intelligente
            $result = $this->cancellationService->executeIntelligentCancellation($user, $trip, $data);

            return Response::success($result, 'Cancellation executed successfully');

        } catch (Exception $e) {
            error_log("IntelligentCancellationController::executeIntelligentCancellation Error: " . $e->getMessage());
            return Response::error($e->getMessage(), [], 500);
        }
    }

    /**
     * Obtient le score de fiabilité d'un utilisateur
     * GET /api/v1/user/reliability-score
     */
    public function getUserReliabilityScore(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            $scoreData = $this->reliabilityService->getUserReliabilityScore($user->id);
            $recommendations = $this->reliabilityService->getReliabilityRecommendations($user->id);

            return Response::success([
                'reliability' => $scoreData,
                'recommendations' => $recommendations,
                'user_info' => [
                    'id' => $user->id,
                    'user_type' => $user->user_type ?? 'new',
                    'member_since' => $user->created_at
                ]
            ], 'Reliability score retrieved');

        } catch (Exception $e) {
            error_log("IntelligentCancellationController::getUserReliabilityScore Error: " . $e->getMessage());
            return Response::error('Failed to retrieve reliability score', [], 500);
        }
    }

    /**
     * Obtient l'historique des annulations intelligentes
     * GET /api/v1/user/intelligent-cancellation-history
     */
    public function getIntelligentCancellationHistory(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $queryParams = $request->getQueryParams();
        $page = (int) ($queryParams['page'] ?? 1);
        $limit = min((int) ($queryParams['limit'] ?? 10), 50);
        $offset = ($page - 1) * $limit;

        try {
            // Récupération de l'historique d'annulation
            $history = \Illuminate\Database\Capsule\Manager::table('cancellation_attempts')
                ->where('user_id', $user->id)
                ->orderBy('created_at', 'desc')
                ->offset($offset)
                ->limit($limit)
                ->get();

            $total = \Illuminate\Database\Capsule\Manager::table('cancellation_attempts')
                ->where('user_id', $user->id)
                ->count();

            // Enrichissement avec les informations des voyages
            $enrichedHistory = [];
            foreach ($history as $attempt) {
                $trip = null;
                if ($attempt->trip_id) {
                    $trip = Trip::find($attempt->trip_id);
                }

                $enrichedHistory[] = [
                    'id' => $attempt->id,
                    'attempt_type' => $attempt->attempt_type,
                    'is_allowed' => (bool) $attempt->is_allowed,
                    'denial_reason' => $attempt->denial_reason,
                    'created_at' => $attempt->created_at,
                    'trip' => $trip ? [
                        'id' => $trip->id,
                        'title' => $trip->title,
                        'departure_city' => $trip->departure_city,
                        'arrival_city' => $trip->arrival_city,
                        'departure_date' => $trip->departure_date,
                        'status' => $trip->status
                    ] : null
                ];
            }

            return Response::success([
                'history' => $enrichedHistory,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit)
                ]
            ], 'Cancellation history retrieved');

        } catch (Exception $e) {
            error_log("IntelligentCancellationController::getIntelligentCancellationHistory Error: " . $e->getMessage());
            return Response::error('Failed to retrieve cancellation history', [], 500);
        }
    }

    /**
     * Obtient les alternatives suggérées pour un voyage annulé
     * GET /api/v1/trips/{id}/alternatives
     */
    public function getTripAlternatives(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = (int) $request->getAttribute('id');

        try {
            // Récupération des alternatives suggérées
            $alternatives = \Illuminate\Database\Capsule\Manager::table('trip_alternatives')
                ->join('trips', 'trip_alternatives.suggested_trip_id', '=', 'trips.id')
                ->join('users', 'trips.user_id', '=', 'users.id')
                ->where('trip_alternatives.cancelled_trip_id', $tripId)
                ->where('trip_alternatives.affected_user_id', $user->id)
                ->select([
                    'trip_alternatives.*',
                    'trips.title',
                    'trips.departure_city',
                    'trips.arrival_city',
                    'trips.departure_date',
                    'trips.price_per_kg',
                    'trips.available_weight_kg',
                    'users.first_name',
                    'users.last_name'
                ])
                ->orderBy('trip_alternatives.relevance_score', 'desc')
                ->get();

            $formattedAlternatives = [];
            foreach ($alternatives as $alt) {
                $formattedAlternatives[] = [
                    'id' => $alt->id,
                    'suggestion_type' => $alt->suggestion_type,
                    'relevance_score' => (float) $alt->relevance_score,
                    'is_accepted' => $alt->is_accepted,
                    'suggested_at' => $alt->suggested_at,
                    'trip' => [
                        'id' => $alt->suggested_trip_id,
                        'title' => $alt->title,
                        'departure_city' => $alt->departure_city,
                        'arrival_city' => $alt->arrival_city,
                        'departure_date' => $alt->departure_date,
                        'price_per_kg' => (float) $alt->price_per_kg,
                        'available_weight_kg' => (float) $alt->available_weight_kg,
                        'traveler_name' => trim($alt->first_name . ' ' . $alt->last_name)
                    ]
                ];
            }

            return Response::success([
                'alternatives' => $formattedAlternatives,
                'total_suggestions' => count($formattedAlternatives)
            ], 'Trip alternatives retrieved');

        } catch (Exception $e) {
            error_log("IntelligentCancellationController::getTripAlternatives Error: " . $e->getMessage());
            return Response::error('Failed to retrieve trip alternatives', [], 500);
        }
    }

    /**
     * Répond à une suggestion d'alternative
     * POST /api/v1/trip-alternatives/{id}/respond
     */
    public function respondToAlternative(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $alternativeId = (int) $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true) ?? [];

        try {
            $accepted = $data['accepted'] ?? null;
            if ($accepted === null || !is_bool($accepted)) {
                return Response::error('Field "accepted" is required and must be boolean', [], 400);
            }

            // Vérification que l'alternative appartient à l'utilisateur
            $alternative = \Illuminate\Database\Capsule\Manager::table('trip_alternatives')
                ->where('id', $alternativeId)
                ->where('affected_user_id', $user->id)
                ->first();

            if (!$alternative) {
                return Response::notFound('Alternative not found');
            }

            // Mise à jour de la réponse
            \Illuminate\Database\Capsule\Manager::table('trip_alternatives')
                ->where('id', $alternativeId)
                ->update([
                    'is_accepted' => $accepted,
                    'responded_at' => \Carbon\Carbon::now()
                ]);

            $message = $accepted ? 'Alternative accepted' : 'Alternative declined';

            return Response::success([
                'alternative_id' => $alternativeId,
                'accepted' => $accepted,
                'responded_at' => \Carbon\Carbon::now()->toISOString()
            ], $message);

        } catch (Exception $e) {
            error_log("IntelligentCancellationController::respondToAlternative Error: " . $e->getMessage());
            return Response::error('Failed to respond to alternative', [], 500);
        }
    }

    /**
     * Validation des données d'annulation
     */
    private function validateCancellationData(array $data, User $user, Trip $trip): array
    {
        $errors = [];

        // Analyse préliminaire des conditions
        $analysis = $this->cancellationService->analyzeCancellationConditions($user, $trip);

        if (!$analysis['allowed']) {
            return [
                'valid' => false,
                'message' => $analysis['message'],
                'errors' => ['cancellation' => 'Cancellation not allowed']
            ];
        }

        // Vérification si une raison est requise
        if (in_array('provide_reason', $analysis['actions_required']) && empty($data['reason'])) {
            $errors['reason'] = 'Cancellation reason is required for this type of cancellation';
        }

        // Vérification de la confirmation des remboursements
        if (in_array('confirm_refunds', $analysis['actions_required']) && !($data['confirm_refunds'] ?? false)) {
            $errors['confirm_refunds'] = 'You must confirm understanding of refund implications';
        }

        return [
            'valid' => empty($errors),
            'message' => empty($errors) ? 'Validation passed' : 'Validation failed',
            'errors' => $errors
        ];
    }
}