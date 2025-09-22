<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\User;
use KiloShare\Models\UserRating;
use Carbon\Carbon;
use Illuminate\Database\Capsule\Manager as DB;

class UserReliabilityService
{
    private const BASE_SCORE = 100;
    private const MIN_SCORE = 0;
    private const MAX_SCORE = 100;

    // Poids des différents facteurs
    private const WEIGHTS = [
        'trip_completion' => 0.3,    // 30% - Voyages complétés
        'cancellation_rate' => 0.25, // 25% - Taux d'annulation
        'booking_reliability' => 0.2, // 20% - Fiabilité des réservations
        'user_feedback' => 0.15,     // 15% - Évaluations utilisateurs
        'account_age' => 0.1         // 10% - Ancienneté du compte
    ];

    /**
     * Calcule le score de fiabilité global d'un utilisateur
     */
    public function getUserReliabilityScore(int $userId): array
    {
        $user = User::find($userId);
        if (!$user) {
            return ['score' => 0, 'level' => 'unknown', 'factors' => []];
        }

        // Calcul des différents facteurs
        $factors = [
            'trip_completion' => $this->calculateTripCompletionScore($user),
            'cancellation_rate' => $this->calculateCancellationScore($user),
            'booking_reliability' => $this->calculateBookingReliabilityScore($user),
            'user_feedback' => $this->calculateUserFeedbackScore($user),
            'account_age' => $this->calculateAccountAgeScore($user)
        ];

        // Calcul du score pondéré
        $weightedScore = 0;
        foreach ($factors as $factor => $score) {
            $weightedScore += $score * self::WEIGHTS[$factor];
        }

        $finalScore = max(self::MIN_SCORE, min(self::MAX_SCORE, round($weightedScore)));

        return [
            'score' => $finalScore,
            'level' => $this->getReliabilityLevel($finalScore),
            'factors' => $factors,
            'last_updated' => Carbon::now()->toISOString()
        ];
    }

    /**
     * Met à jour le score de fiabilité suite à une action
     */
    public function updateUserReliability(int $userId, int $impact, string $action, string $description = ''): void
    {
        // Récupérer ou créer l'enregistrement de rating
        $rating = UserRating::firstOrCreate(
            ['user_id' => $userId],
            [
                'reliability_score' => self::BASE_SCORE,
                'total_ratings' => 0,
                'average_rating' => 0,
                'last_updated' => Carbon::now()
            ]
        );

        // Appliquer l'impact
        $newScore = max(self::MIN_SCORE, min(self::MAX_SCORE, $rating->reliability_score + $impact));
        $rating->reliability_score = $newScore;
        $rating->last_updated = Carbon::now();
        $rating->save();

        // Enregistrer l'historique
        DB::table('user_reliability_history')->insert([
            'user_id' => $userId,
            'action' => $action,
            'impact' => $impact,
            'previous_score' => $rating->reliability_score - $impact,
            'new_score' => $newScore,
            'description' => $description,
            'created_at' => Carbon::now()
        ]);

        error_log("User $userId reliability updated: $action (impact: $impact) -> score: $newScore");
    }

    /**
     * Score basé sur le taux de completion des voyages
     */
    private function calculateTripCompletionScore(User $user): float
    {
        $totalTrips = $user->trips()->whereIn('status', ['completed', 'cancelled'])->count();

        if ($totalTrips === 0) {
            return self::BASE_SCORE; // Nouveau utilisateur = score neutre
        }

        $completedTrips = $user->trips()->where('status', 'completed')->count();
        $completionRate = $completedTrips / $totalTrips;

        // Score de 0 à 100 basé sur le taux de completion
        return $completionRate * 100;
    }

    /**
     * Score basé sur le taux d'annulation
     */
    private function calculateCancellationScore(User $user): float
    {
        $totalTrips = $user->trips()->count();

        if ($totalTrips === 0) {
            return self::BASE_SCORE;
        }

        // Compter les annulations des 6 derniers mois
        $sixMonthsAgo = Carbon::now()->subMonths(6);
        $cancellations = DB::table('cancellation_attempts')
            ->where('user_id', $user->id)
            ->where('attempt_type', 'trip_cancel')
            ->where('is_allowed', true)
            ->where('created_at', '>=', $sixMonthsAgo)
            ->count();

        $cancellationRate = $cancellations / $totalTrips;

        // Score inversé : moins d'annulations = meilleur score
        return max(0, 100 - ($cancellationRate * 200)); // Pénalité forte pour annulations
    }

    /**
     * Score basé sur la fiabilité des réservations (côté expéditeur)
     */
    private function calculateBookingReliabilityScore(User $user): float
    {
        $totalBookings = $user->bookings()->count();

        if ($totalBookings === 0) {
            return self::BASE_SCORE;
        }

        // Réservations complétées avec succès
        $successfulBookings = $user->bookings()->where('status', 'completed')->count();

        // Réservations annulées par l'utilisateur
        $cancelledBookings = $user->bookings()->where('status', 'cancelled')
            ->where('cancelled_by', 'sender')->count();

        $reliabilityRate = ($successfulBookings / $totalBookings) - ($cancelledBookings / $totalBookings * 0.5);

        return max(0, min(100, $reliabilityRate * 100));
    }

    /**
     * Score basé sur les évaluations des autres utilisateurs
     */
    private function calculateUserFeedbackScore(User $user): float
    {
        $rating = $user->rating;

        if (!$rating || $rating->total_ratings === 0) {
            return self::BASE_SCORE; // Pas d'évaluations = score neutre
        }

        // Convertir la note moyenne (1-5) en score (0-100)
        return ($rating->average_rating / 5) * 100;
    }

    /**
     * Score basé sur l'ancienneté du compte
     */
    private function calculateAccountAgeScore(User $user): float
    {
        $accountAge = Carbon::parse($user->created_at)->diffInMonths(Carbon::now());

        // Score progressif :
        // - Nouveau compte (0-1 mois) : 50
        // - Compte récent (1-6 mois) : 70
        // - Compte établi (6-12 mois) : 85
        // - Compte ancien (12+ mois) : 100

        if ($accountAge < 1) {
            return 50;
        } elseif ($accountAge < 6) {
            return 50 + (($accountAge / 6) * 20); // 50-70
        } elseif ($accountAge < 12) {
            return 70 + ((($accountAge - 6) / 6) * 15); // 70-85
        } else {
            return 100;
        }
    }

    /**
     * Détermine le niveau de fiabilité
     */
    private function getReliabilityLevel(int $score): string
    {
        if ($score >= 90) {
            return 'excellent';
        } elseif ($score >= 75) {
            return 'good';
        } elseif ($score >= 60) {
            return 'average';
        } elseif ($score >= 40) {
            return 'poor';
        } else {
            return 'very_poor';
        }
    }

    /**
     * Obtient les recommandations pour améliorer le score
     */
    public function getReliabilityRecommendations(int $userId): array
    {
        $scoreData = $this->getUserReliabilityScore($userId);
        $recommendations = [];

        foreach ($scoreData['factors'] as $factor => $score) {
            if ($score < 70) {
                switch ($factor) {
                    case 'trip_completion':
                        $recommendations[] = [
                            'type' => 'trip_completion',
                            'message' => 'Complétez plus de voyages pour améliorer votre fiabilité',
                            'priority' => 'high'
                        ];
                        break;
                    case 'cancellation_rate':
                        $recommendations[] = [
                            'type' => 'cancellation_rate',
                            'message' => 'Évitez les annulations de dernière minute',
                            'priority' => 'high'
                        ];
                        break;
                    case 'booking_reliability':
                        $recommendations[] = [
                            'type' => 'booking_reliability',
                            'message' => 'Honorez vos réservations pour améliorer votre réputation',
                            'priority' => 'medium'
                        ];
                        break;
                    case 'user_feedback':
                        $recommendations[] = [
                            'type' => 'user_feedback',
                            'message' => 'Améliorez la qualité de vos services pour obtenir de meilleures évaluations',
                            'priority' => 'medium'
                        ];
                        break;
                }
            }
        }

        return $recommendations;
    }

    /**
     * Vérifie si un utilisateur peut effectuer certaines actions basées sur son score
     */
    public function canUserPerformAction(int $userId, string $action): array
    {
        $scoreData = $this->getUserReliabilityScore($userId);
        $score = $scoreData['score'];

        $permissions = [
            'create_trip' => $score >= 30,
            'book_trip' => $score >= 20,
            'cancel_trip' => $score >= 40,
            'multiple_bookings' => $score >= 60,
            'premium_features' => $score >= 80
        ];

        $allowed = $permissions[$action] ?? false;

        return [
            'allowed' => $allowed,
            'current_score' => $score,
            'required_score' => $this->getRequiredScoreForAction($action),
            'message' => $allowed ?
                "Action autorisée" :
                "Score de fiabilité insuffisant pour cette action"
        ];
    }

    /**
     * Score requis pour chaque action
     */
    private function getRequiredScoreForAction(string $action): int
    {
        $requirements = [
            'create_trip' => 30,
            'book_trip' => 20,
            'cancel_trip' => 40,
            'multiple_bookings' => 60,
            'premium_features' => 80
        ];

        return $requirements[$action] ?? 50;
    }
}