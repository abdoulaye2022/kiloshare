<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use KiloShare\Models\ReviewModel;
use KiloShare\Utils\Database;
use KiloShare\Utils\ResponseHelper;
use KiloShare\Utils\JWTHelper;

class ReviewController
{
    private ReviewModel $reviewModel;

    public function __construct()
    {
        $db = Database::getConnection();
        $this->reviewModel = new ReviewModel($db);
    }

    /**
     * Créer une nouvelle review
     * POST /api/reviews
     */
    public function createReview(Request $request, Response $response): Response
    {
        try {
            // Récupérer l'utilisateur connecté
            $userId = JWTHelper::getUserIdFromRequest($request);
            if (!$userId) {
                return ResponseHelper::error($response, 'Non autorisé', 401);
            }

            $data = json_decode($request->getBody()->getContents(), true);
            
            // Validation des données
            if (!isset($data['booking_id']) || !isset($data['rating'])) {
                return ResponseHelper::error($response, 'booking_id et rating sont requis', 400);
            }
            
            $bookingId = (int) $data['booking_id'];
            $rating = (int) $data['rating'];
            $comment = $data['comment'] ?? null;
            
            // Validation du rating
            if ($rating < 1 || $rating > 5) {
                return ResponseHelper::error($response, 'Le rating doit être entre 1 et 5', 400);
            }
            
            // Validation du commentaire
            if ($comment && strlen($comment) > 500) {
                return ResponseHelper::error($response, 'Le commentaire ne peut dépasser 500 caractères', 400);
            }
            
            // Vérifier si l'utilisateur peut créer cette review
            $canReview = $this->reviewModel->canUserReviewBooking($userId, $bookingId);
            if (!$canReview['can_review']) {
                $messages = [
                    'booking_not_found' => 'Réservation non trouvée',
                    'not_participant' => 'Vous ne participez pas à cette réservation',
                    'not_delivered' => 'La réservation n\'est pas encore livrée',
                    'too_early' => 'Vous devez attendre 24h après la livraison pour évaluer',
                    'already_reviewed' => 'Vous avez déjà évalué cette réservation'
                ];
                
                $message = $messages[$canReview['reason']] ?? 'Impossible de créer cette évaluation';
                return ResponseHelper::error($response, $message, 400);
            }
            
            // Créer la review
            $reviewData = [
                'booking_id' => $bookingId,
                'reviewer_id' => $userId,
                'reviewed_id' => $canReview['reviewed_id'],
                'rating' => $rating,
                'comment' => $comment
            ];
            
            $reviewId = $this->reviewModel->create($reviewData);
            
            return ResponseHelper::success($response, [
                'message' => 'Évaluation créée avec succès',
                'review_id' => $reviewId
            ], 201);
            
        } catch (\Exception $e) {
            return ResponseHelper::error($response, 'Erreur lors de la création de l\'évaluation: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Récupérer les reviews d'un utilisateur
     * GET /api/users/{id}/reviews
     */
    public function getUserReviews(Request $request, Response $response, array $args): Response
    {
        try {
            $userId = (int) $args['id'];
            $page = (int) ($request->getQueryParams()['page'] ?? 1);
            $limit = min((int) ($request->getQueryParams()['limit'] ?? 10), 50);
            $offset = ($page - 1) * $limit;
            
            $reviews = $this->reviewModel->getUserReviews($userId, $limit, $offset);
            $userRating = $this->reviewModel->getUserRating($userId);
            
            return ResponseHelper::success($response, [
                'user_rating' => $userRating,
                'reviews' => $reviews,
                'pagination' => [
                    'page' => $page,
                    'limit' => $limit,
                    'has_more' => count($reviews) === $limit
                ]
            ]);
            
        } catch (\Exception $e) {
            return ResponseHelper::error($response, 'Erreur lors de la récupération des évaluations: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Récupérer le rating global d'un utilisateur
     * GET /api/users/{id}/rating
     */
    public function getUserRating(Request $request, Response $response, array $args): Response
    {
        try {
            $userId = (int) $args['id'];
            $userRating = $this->reviewModel->getUserRating($userId);
            
            if (!$userRating) {
                return ResponseHelper::error($response, 'Utilisateur non trouvé', 404);
            }
            
            // Récupérer les 3 derniers commentaires
            $recentReviews = $this->reviewModel->getUserReviews($userId, 3, 0);
            $recentComments = array_filter(array_column($recentReviews, 'comment'));
            
            // Déterminer le statut et les badges
            $status = 'normal';
            $badges = [];
            
            if ($userRating['average_rating'] >= 4.5 && $userRating['total_reviews'] >= 5) {
                $status = 'super_traveler';
                $badges[] = 'Super Voyageur';
            } elseif ($userRating['average_rating'] < 2.5 && $userRating['total_reviews'] >= 3) {
                $status = 'suspended';
                $badges[] = 'Compte Suspendu';
            } elseif ($userRating['average_rating'] < 3.0 && $userRating['total_reviews'] >= 3) {
                $status = 'warning';
                $badges[] = 'Attention';
            }
            
            return ResponseHelper::success($response, [
                'user_id' => $userId,
                'average_rating' => (float) $userRating['average_rating'],
                'total_reviews' => (int) $userRating['total_reviews'],
                'as_traveler_rating' => (float) $userRating['as_traveler_rating'],
                'as_traveler_count' => (int) $userRating['as_traveler_count'],
                'as_sender_rating' => (float) $userRating['as_sender_rating'],
                'as_sender_count' => (int) $userRating['as_sender_count'],
                'status' => $status,
                'badges' => $badges,
                'recent_comments' => array_slice($recentComments, 0, 3),
                'last_updated' => $userRating['last_calculated_at']
            ]);
            
        } catch (\Exception $e) {
            return ResponseHelper::error($response, 'Erreur lors de la récupération du rating: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Vérifier si l'utilisateur peut créer une review pour une booking
     * GET /api/reviews/check/{booking_id}
     */
    public function checkReviewEligibility(Request $request, Response $response, array $args): Response
    {
        try {
            $userId = JWTHelper::getUserIdFromRequest($request);
            if (!$userId) {
                return ResponseHelper::error($response, 'Non autorisé', 401);
            }
            
            $bookingId = (int) $args['booking_id'];
            $canReview = $this->reviewModel->canUserReviewBooking($userId, $bookingId);
            
            return ResponseHelper::success($response, [
                'can_review' => $canReview['can_review'],
                'reason' => $canReview['reason'] ?? null,
                'user_role' => $canReview['user_role'] ?? null,
                'booking_info' => $canReview['booking'] ?? null
            ]);
            
        } catch (\Exception $e) {
            return ResponseHelper::error($response, 'Erreur lors de la vérification: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Récupérer les bookings en attente de review pour l'utilisateur connecté
     * GET /api/reviews/pending
     */
    public function getPendingReviews(Request $request, Response $response): Response
    {
        try {
            $userId = JWTHelper::getUserIdFromRequest($request);
            if (!$userId) {
                return ResponseHelper::error($response, 'Non autorisé', 401);
            }
            
            // Récupérer toutes les bookings éligibles
            $eligibleBookings = $this->reviewModel->getEligibleBookingsForReview();
            
            // Filtrer pour l'utilisateur connecté
            $userPendingReviews = [];
            foreach ($eligibleBookings as $booking) {
                // Vérifier si l'utilisateur est impliqué et n'a pas encore reviewé
                $canReview = $this->reviewModel->canUserReviewBooking($userId, (int) $booking['booking_id']);
                if ($canReview['can_review']) {
                    $userPendingReviews[] = [
                        'booking_id' => $booking['booking_id'],
                        'user_role' => $canReview['user_role'],
                        'route' => $booking['departure_city'] . ' → ' . $booking['arrival_city'],
                        'delivered_at' => $booking['delivered_at']
                    ];
                }
            }
            
            return ResponseHelper::success($response, [
                'pending_reviews' => $userPendingReviews,
                'count' => count($userPendingReviews)
            ]);
            
        } catch (\Exception $e) {
            return ResponseHelper::error($response, 'Erreur lors de la récupération des évaluations en attente: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Endpoint admin pour forcer le recalcul des ratings
     * POST /api/admin/reviews/recalculate
     */
    public function recalculateRatings(Request $request, Response $response): Response
    {
        try {
            // TODO: Ajouter vérification admin
            
            // Forcer le recalcul pour tous les utilisateurs ayant des reviews
            $db = Database::getConnection();
            
            $sql = "SELECT DISTINCT reviewed_id FROM reviews WHERE is_visible = TRUE";
            $stmt = $db->prepare($sql);
            $stmt->execute();
            $userIds = $stmt->fetchAll(\PDO::FETCH_COLUMN);
            
            $recalculatedCount = 0;
            foreach ($userIds as $userId) {
                $callSql = "CALL CalculateUserRating(:user_id)";
                $callStmt = $db->prepare($callSql);
                $callStmt->execute(['user_id' => $userId]);
                $recalculatedCount++;
            }
            
            return ResponseHelper::success($response, [
                'message' => 'Recalcul des ratings terminé',
                'users_updated' => $recalculatedCount
            ]);
            
        } catch (\Exception $e) {
            return ResponseHelper::error($response, 'Erreur lors du recalcul: ' . $e->getMessage(), 500);
        }
    }

    /**
     * Endpoint admin pour publier automatiquement les reviews en attente
     * POST /api/admin/reviews/auto-publish
     */
    public function autoPublishReviews(Request $request, Response $response): Response
    {
        try {
            // TODO: Ajouter vérification admin
            
            $publishedCount = $this->reviewModel->autoPublishPendingReviews();
            
            return ResponseHelper::success($response, [
                'message' => 'Publication automatique terminée',
                'reviews_published' => $publishedCount
            ]);
            
        } catch (\Exception $e) {
            return ResponseHelper::error($response, 'Erreur lors de la publication automatique: ' . $e->getMessage(), 500);
        }
    }
}