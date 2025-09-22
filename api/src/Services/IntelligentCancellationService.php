<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\User;
use KiloShare\Models\Trip;
use KiloShare\Models\Booking;
use KiloShare\Models\UserRating;
use Carbon\Carbon;
use Illuminate\Database\Capsule\Manager as DB;
use Exception;

class IntelligentCancellationService
{
    private const USER_TYPES = [
        'new' => 'new',
        'confirmed' => 'confirmed',
        'expert' => 'expert'
    ];

    private const CANCELLATION_LIMITS = [
        'new' => 1,
        'confirmed' => 2,
        'expert' => 3
    ];

    private const PENALTY_DURATIONS = [
        'light' => 7,  // 7 jours
        'medium' => 30, // 30 jours
        'heavy' => 90   // 90 jours
    ];

    private SmartNotificationService $notificationService;
    private UserReliabilityService $reliabilityService;
    private AutoRefundService $refundService;

    public function __construct(
        SmartNotificationService $notificationService,
        UserReliabilityService $reliabilityService,
        AutoRefundService $refundService
    ) {
        $this->notificationService = $notificationService;
        $this->reliabilityService = $reliabilityService;
        $this->refundService = $refundService;
    }

    /**
     * Analyse intelligente des conditions d'annulation
     */
    public function analyzeCancellationConditions(User $user, Trip $trip): array
    {
        // Vérifications de base
        if (!$trip->isOwner($user)) {
            return [
                'allowed' => false,
                'category' => 'unauthorized',
                'reason' => 'Vous n\'êtes pas le propriétaire de ce voyage',
                'actions' => []
            ];
        }

        if (!in_array($trip->status, [Trip::STATUS_ACTIVE, Trip::STATUS_BOOKED])) {
            return [
                'allowed' => false,
                'category' => 'invalid_status',
                'reason' => 'Ce voyage ne peut plus être annulé',
                'actions' => []
            ];
        }

        // Calcul des délais
        $now = Carbon::now();
        $departureTime = Carbon::parse($trip->departure_date);
        $hoursUntilDeparture = $now->diffInHours($departureTime, false);

        // Analyse des réservations
        $bookingAnalysis = $this->analyzeBookings($trip);

        // Analyse du profil utilisateur
        $userProfile = $this->analyzeUserProfile($user);

        // Détermination de la catégorie d'annulation
        $category = $this->determineCancellationCategory(
            $hoursUntilDeparture,
            $bookingAnalysis,
            $userProfile
        );

        return [
            'allowed' => $category['allowed'],
            'category' => $category['type'],
            'severity' => $category['severity'],
            'hours_until_departure' => max(0, $hoursUntilDeparture),
            'bookings' => $bookingAnalysis,
            'user_profile' => $userProfile,
            'consequences' => $this->calculateConsequences($category, $bookingAnalysis, $userProfile),
            'actions_required' => $this->getRequiredActions($category, $bookingAnalysis),
            'message' => $category['message']
        ];
    }

    /**
     * Analyse des réservations du voyage
     */
    private function analyzeBookings(Trip $trip): array
    {
        $bookings = $trip->bookings()->get();

        $analysis = [
            'total_count' => $bookings->count(),
            'confirmed_count' => 0,
            'paid_count' => 0,
            'pending_count' => 0,
            'total_amount' => 0,
            'affected_users' => [],
            'has_payments' => false
        ];

        foreach ($bookings as $booking) {
            switch ($booking->status) {
                case 'accepted':
                case 'in_progress':
                    $analysis['confirmed_count']++;
                    $analysis['affected_users'][] = $booking->user_id;
                    break;
                case 'paid':
                    $analysis['paid_count']++;
                    $analysis['has_payments'] = true;
                    $analysis['total_amount'] += $booking->total_amount ?? 0;
                    $analysis['affected_users'][] = $booking->user_id;
                    break;
                case 'pending':
                    $analysis['pending_count']++;
                    break;
            }
        }

        $analysis['affected_users'] = array_unique($analysis['affected_users']);
        return $analysis;
    }

    /**
     * Analyse du profil utilisateur
     */
    private function analyzeUserProfile(User $user): array
    {
        // Calcul des statistiques d'annulation du mois
        $monthStart = Carbon::now()->startOfMonth();
        $cancellationsThisMonth = DB::table('cancellation_attempts')
            ->where('user_id', $user->id)
            ->where('attempt_type', 'trip_cancel')
            ->where('is_allowed', true)
            ->where('created_at', '>=', $monthStart)
            ->count();

        // Détermination du type d'utilisateur
        $userType = $this->determineUserType($user);

        // Récupération du score de fiabilité
        $reliabilityScore = $this->reliabilityService->getUserReliabilityScore($user->id);

        return [
            'user_type' => $userType,
            'cancellations_this_month' => $cancellationsThisMonth,
            'max_allowed_cancellations' => self::CANCELLATION_LIMITS[$userType],
            'reliability_score' => $reliabilityScore,
            'is_first_cancellation' => $cancellationsThisMonth === 0,
            'can_cancel_more' => $cancellationsThisMonth < self::CANCELLATION_LIMITS[$userType],
            'total_trips' => $user->trips()->count(),
            'completed_trips' => $user->trips()->where('status', 'completed')->count()
        ];
    }

    /**
     * Détermine le type d'utilisateur
     */
    private function determineUserType(User $user): string
    {
        $completedTrips = $user->trips()->where('status', 'completed')->count();
        $accountAge = Carbon::parse($user->created_at)->diffInMonths(Carbon::now());

        if ($completedTrips >= 10 && $accountAge >= 6) {
            return self::USER_TYPES['expert'];
        } elseif ($completedTrips >= 3 && $accountAge >= 2) {
            return self::USER_TYPES['confirmed'];
        }

        return self::USER_TYPES['new'];
    }

    /**
     * Détermine la catégorie d'annulation selon les règles métier
     */
    private function determineCancellationCategory(float $hoursUntilDeparture, array $bookingAnalysis, array $userProfile): array
    {
        // Vérification des limites d'annulation
        if (!$userProfile['can_cancel_more']) {
            return [
                'allowed' => false,
                'type' => 'limit_exceeded',
                'severity' => 'high',
                'message' => "Limite d'annulations atteinte pour ce mois ({$userProfile['max_allowed_cancellations']} max)"
            ];
        }

        // 1. ANNULATION LIBRE (48h+ avant départ, aucune réservation confirmée)
        if ($hoursUntilDeparture >= 48 && $bookingAnalysis['confirmed_count'] === 0 && $bookingAnalysis['paid_count'] === 0) {
            return [
                'allowed' => true,
                'type' => 'free_cancellation',
                'severity' => 'none',
                'message' => 'Annulation libre sans pénalité'
            ];
        }

        // 2. ANNULATION AVEC IMPACT (24-48h avant, réservations non payées)
        if ($hoursUntilDeparture >= 24 && $hoursUntilDeparture < 48 && $bookingAnalysis['paid_count'] === 0) {
            return [
                'allowed' => true,
                'type' => 'impact_cancellation',
                'severity' => 'medium',
                'message' => 'Annulation avec impact sur les réservations existantes'
            ];
        }

        // 3. ANNULATION CRITIQUE (<24h avant, réservations payées)
        if ($hoursUntilDeparture < 24 && $bookingAnalysis['has_payments']) {
            return [
                'allowed' => true,
                'type' => 'critical_cancellation',
                'severity' => 'high',
                'message' => 'Annulation critique avec remboursements automatiques'
            ];
        }

        // 4. ANNULATION AVEC RÉSERVATIONS (autres cas)
        if ($bookingAnalysis['total_count'] > 0) {
            return [
                'allowed' => true,
                'type' => 'booking_cancellation',
                'severity' => 'medium',
                'message' => 'Annulation avec gestion des réservations existantes'
            ];
        }

        // Cas par défaut
        return [
            'allowed' => true,
            'type' => 'standard_cancellation',
            'severity' => 'low',
            'message' => 'Annulation standard'
        ];
    }

    /**
     * Calcule les conséquences de l'annulation
     */
    private function calculateConsequences(array $category, array $bookingAnalysis, array $userProfile): array
    {
        $consequences = [
            'penalty_duration' => 0,
            'reliability_impact' => 0,
            'restriction_type' => null,
            'refunds_required' => false,
            'notifications_count' => 0,
            'support_ticket' => false
        ];

        switch ($category['type']) {
            case 'free_cancellation':
                // Aucune conséquence
                break;

            case 'impact_cancellation':
                $consequences['penalty_duration'] = self::PENALTY_DURATIONS['light'];
                $consequences['reliability_impact'] = -2;
                $consequences['restriction_type'] = 'publication_restriction';
                $consequences['notifications_count'] = count($bookingAnalysis['affected_users']);
                break;

            case 'critical_cancellation':
                $consequences['penalty_duration'] = self::PENALTY_DURATIONS['medium'];
                $consequences['reliability_impact'] = -5;
                $consequences['restriction_type'] = 'account_suspension';
                $consequences['refunds_required'] = true;
                $consequences['notifications_count'] = count($bookingAnalysis['affected_users']);
                $consequences['support_ticket'] = true;
                break;

            case 'booking_cancellation':
                $consequences['penalty_duration'] = $userProfile['is_first_cancellation'] ? 0 : self::PENALTY_DURATIONS['light'];
                $consequences['reliability_impact'] = $userProfile['is_first_cancellation'] ? 0 : -1;
                $consequences['restriction_type'] = $userProfile['is_first_cancellation'] ? null : 'warning';
                $consequences['notifications_count'] = count($bookingAnalysis['affected_users']);
                break;
        }

        return $consequences;
    }

    /**
     * Détermine les actions requises
     */
    private function getRequiredActions(array $category, array $bookingAnalysis): array
    {
        $actions = [];

        if ($category['type'] === 'critical_cancellation' || $bookingAnalysis['has_payments']) {
            $actions[] = 'provide_reason';
            $actions[] = 'confirm_refunds';
        }

        if ($bookingAnalysis['total_count'] > 0) {
            $actions[] = 'notify_affected_users';
        }

        if (in_array($category['type'], ['impact_cancellation', 'critical_cancellation'])) {
            $actions[] = 'suggest_alternatives';
        }

        return $actions;
    }

    /**
     * Exécute l'annulation intelligente
     */
    public function executeIntelligentCancellation(User $user, Trip $trip, array $data = []): array
    {
        try {
            DB::beginTransaction();

            // Analyser les conditions
            $analysis = $this->analyzeCancellationConditions($user, $trip);

            if (!$analysis['allowed']) {
                throw new Exception($analysis['message']);
            }

            // Enregistrer la tentative d'annulation
            $this->logCancellationAttempt($user, $trip, true, null);

            // Exécuter les actions selon le type d'annulation
            $result = $this->executeCancellationActions($trip, $analysis, $data);

            // Mettre à jour le score de fiabilité
            if ($analysis['consequences']['reliability_impact'] !== 0) {
                $this->reliabilityService->updateUserReliability(
                    $user->id,
                    $analysis['consequences']['reliability_impact'],
                    'trip_cancellation',
                    "Annulation de voyage - Type: {$analysis['category']}"
                );
            }

            // Appliquer les pénalités
            if ($analysis['consequences']['penalty_duration'] > 0) {
                $this->applyUserPenalty($user, $analysis['consequences']);
            }

            DB::commit();

            return [
                'success' => true,
                'message' => 'Voyage annulé avec succès',
                'analysis' => $analysis,
                'actions_executed' => $result
            ];

        } catch (Exception $e) {
            DB::rollBack();

            // Enregistrer la tentative échouée
            $this->logCancellationAttempt($user, $trip, false, $e->getMessage());

            throw $e;
        }
    }

    /**
     * Exécute les actions d'annulation
     */
    private function executeCancellationActions(Trip $trip, array $analysis, array $data): array
    {
        $actions = [];

        // 1. Mettre à jour le statut du voyage
        $trip->status = Trip::STATUS_CANCELLED;
        $trip->cancelled_at = Carbon::now();
        $trip->cancelled_by = 'traveler';
        $trip->cancellation_reason = $data['reason'] ?? 'user_cancelled';
        $trip->save();

        $actions['trip_cancelled'] = true;

        // 2. Traitement des réservations
        if ($analysis['bookings']['total_count'] > 0) {
            $actions['bookings_processed'] = $this->processBookingCancellations($trip, $analysis);
        }

        // 3. Remboursements automatiques
        if ($analysis['consequences']['refunds_required']) {
            $actions['refunds_processed'] = $this->refundService->processAutomaticRefunds($trip);
        }

        // 4. Notifications
        if ($analysis['consequences']['notifications_count'] > 0) {
            $actions['notifications_sent'] = $this->sendCancellationNotifications($trip, $analysis);
        }

        // 5. Génération de ticket support si nécessaire
        if ($analysis['consequences']['support_ticket']) {
            $actions['support_ticket_created'] = $this->createSupportTicket($trip, $analysis);
        }

        return $actions;
    }

    /**
     * Traite les annulations de réservations
     */
    private function processBookingCancellations(Trip $trip, array $analysis): int
    {
        $processed = 0;
        $bookings = $trip->bookings()->whereNotIn('status', ['cancelled', 'completed'])->get();

        foreach ($bookings as $booking) {
            $booking->status = 'cancelled';
            $booking->cancelled_at = Carbon::now();
            $booking->cancellation_type = 'trip_cancelled_by_owner';
            $booking->cancellation_reason = 'Voyage annulé par l\'annonceur';
            $booking->save();
            $processed++;
        }

        return $processed;
    }

    /**
     * Envoie les notifications d'annulation
     */
    private function sendCancellationNotifications(Trip $trip, array $analysis): int
    {
        $sent = 0;
        $affectedUsers = User::whereIn('id', $analysis['bookings']['affected_users'])->get();

        foreach ($affectedUsers as $user) {
            $this->notificationService->sendTripCancelledNotification($user, $trip, [
                'cancellation_type' => $analysis['category'],
                'severity' => $analysis['severity'],
                'refund_applicable' => $analysis['consequences']['refunds_required']
            ]);
            $sent++;
        }

        return $sent;
    }

    /**
     * Crée un ticket de support automatique
     */
    private function createSupportTicket(Trip $trip, array $analysis): bool
    {
        // Implémentation du système de tickets
        // Pour l'instant, on enregistre dans les logs
        error_log("Support ticket created for critical cancellation - Trip ID: {$trip->id}, Category: {$analysis['category']}");
        return true;
    }

    /**
     * Applique les pénalités utilisateur
     */
    private function applyUserPenalty(User $user, array $consequences): void
    {
        if ($consequences['restriction_type'] === 'account_suspension') {
            $user->is_suspended = true;
            $user->suspension_reason = 'Annulation critique de voyage';
            $user->suspended_until = Carbon::now()->addDays($consequences['penalty_duration']);
        } elseif ($consequences['restriction_type'] === 'publication_restriction') {
            $user->publication_restricted_until = Carbon::now()->addDays($consequences['penalty_duration']);
        }

        $user->save();
    }

    /**
     * Enregistre une tentative d'annulation
     */
    private function logCancellationAttempt(User $user, Trip $trip, bool $allowed, ?string $reason): void
    {
        DB::table('cancellation_attempts')->insert([
            'user_id' => $user->id,
            'trip_id' => $trip->id,
            'attempt_type' => 'trip_cancel',
            'is_allowed' => $allowed,
            'denial_reason' => $reason,
            'created_at' => Carbon::now()
        ]);
    }
}