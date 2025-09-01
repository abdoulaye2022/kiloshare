<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use PDO;
use Psr\Log\LoggerInterface;
use Exception;

/**
 * Contrôleur pour la gestion des favoris utilisateurs
 */
class FavoriteController
{
    private PDO $db;
    private LoggerInterface $logger;

    public function __construct(PDO $db, LoggerInterface $logger)
    {
        $this->db = $db;
        $this->logger = $logger;
    }

    /**
     * Ajouter un voyage aux favoris
     * POST /trips/{id}/favorite
     */
    public function addToFavorites(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Authentification requise'
                ], 401);
            }

            // Vérifier que le voyage existe et n'est pas le sien
            $stmt = $this->db->prepare("SELECT id, user_id FROM trips WHERE id = ? AND status IN ('active', 'published') AND is_approved = 1");
            $stmt->execute([$tripId]);
            $trip = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$trip) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Voyage non trouvé ou non disponible'
                ], 404);
            }

            if ($trip['user_id'] == $userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Vous ne pouvez pas ajouter votre propre voyage aux favoris'
                ], 400);
            }

            // Vérifier si déjà en favoris
            $stmt = $this->db->prepare("SELECT id FROM user_trip_favorites WHERE user_id = ? AND trip_id = ?");
            $stmt->execute([$userId, $tripId]);
            $existing = $stmt->fetch();
            
            if ($existing) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Voyage déjà en favoris'
                ], 409);
            }

            // Ajouter aux favoris
            $stmt = $this->db->prepare("INSERT INTO user_trip_favorites (user_id, trip_id) VALUES (?, ?)");
            $stmt->execute([$userId, $tripId]);

            $this->logger->info('[FavoriteController] Voyage ajouté aux favoris', [
                'user_id' => $userId,
                'trip_id' => $tripId
            ]);

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Voyage ajouté aux favoris'
            ]);

        } catch (Exception $e) {
            $this->logger->error('[FavoriteController] Erreur ajout favoris', [
                'error' => $e->getMessage(),
                'user_id' => $userId ?? null,
                'trip_id' => $tripId ?? null
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de l\'ajout aux favoris'
            ], 500);
        }
    }

    /**
     * Retirer un voyage des favoris
     * DELETE /trips/{id}/favorite
     */
    public function removeFromFavorites(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Authentification requise'
                ], 401);
            }

            $stmt = $this->db->prepare("DELETE FROM user_trip_favorites WHERE user_id = ? AND trip_id = ?");
            $stmt->execute([$userId, $tripId]);

            if ($stmt->rowCount() === 0) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Voyage non trouvé dans les favoris'
                ], 404);
            }

            $this->logger->info('[FavoriteController] Voyage retiré des favoris', [
                'user_id' => $userId,
                'trip_id' => $tripId
            ]);

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Voyage retiré des favoris'
            ]);

        } catch (Exception $e) {
            $this->logger->error('[FavoriteController] Erreur suppression favoris', [
                'error' => $e->getMessage(),
                'user_id' => $userId ?? null,
                'trip_id' => $tripId ?? null
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la suppression des favoris'
            ], 500);
        }
    }

    /**
     * Vérifier le statut favoris d'un voyage
     * GET /trips/{id}/favorite/status
     */
    public function getFavoriteStatus(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Authentification requise'
                ], 401);
            }

            $stmt = $this->db->prepare("SELECT COUNT(*) as count FROM user_trip_favorites WHERE user_id = ? AND trip_id = ?");
            $stmt->execute([$userId, $tripId]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);

            return $this->jsonResponse($response, [
                'success' => true,
                'is_favorite' => $result['count'] > 0
            ]);

        } catch (Exception $e) {
            $this->logger->error('[FavoriteController] Erreur statut favoris', [
                'error' => $e->getMessage(),
                'user_id' => $userId ?? null,
                'trip_id' => $tripId ?? null
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la vérification du statut'
            ], 500);
        }
    }

    /**
     * Récupérer tous les voyages favoris de l'utilisateur
     * GET /trips/favorites
     */
    public function getUserFavorites(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Authentification requise'
                ], 401);
            }

            $stmt = $this->db->prepare("
                SELECT t.id, t.uuid, t.user_id, 
                       t.departure_city, t.departure_country, t.departure_airport_code, t.departure_date,
                       t.arrival_city, t.arrival_country, t.arrival_airport_code, t.arrival_date,
                       t.available_weight_kg, t.price_per_kg, t.currency,
                       t.flight_number, t.airline, t.status, t.description, t.special_notes,
                       t.is_approved, t.created_at, t.updated_at, t.published_at,
                       u.email as user_email,
                       false as user_verified,
                       f.created_at as favorited_at
                FROM user_trip_favorites f
                INNER JOIN trips t ON f.trip_id = t.id
                LEFT JOIN users u ON t.user_id = u.id
                WHERE f.user_id = ? 
                  AND t.status IN ('active', 'published')
                  AND t.is_approved = 1
                  AND t.deleted_at IS NULL
                ORDER BY f.created_at DESC
            ");
            $stmt->execute([$userId]);
            $favorites = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // Formater les voyages selon le modèle Trip attendu par le mobile
            $formattedTrips = array_map(function($trip) {
                return [
                    'id' => (int)$trip['id'],
                    'uuid' => $trip['uuid'],
                    'user_id' => (int)$trip['user_id'],
                    'transport_type' => 'flight', // Default pour les favoris
                    'departure_city' => $trip['departure_city'],
                    'departure_country' => $trip['departure_country'],
                    'departure_airport_code' => $trip['departure_airport_code'],
                    'departure_date' => $trip['departure_date'],
                    'arrival_city' => $trip['arrival_city'],
                    'arrival_country' => $trip['arrival_country'],
                    'arrival_airport_code' => $trip['arrival_airport_code'],
                    'arrival_date' => $trip['arrival_date'],
                    'available_weight_kg' => (float)$trip['available_weight_kg'],
                    'price_per_kg' => (float)$trip['price_per_kg'],
                    'currency' => $trip['currency'],
                    'flight_number' => $trip['flight_number'],
                    'airline' => $trip['airline'],
                    'ticket_verified' => false, // Default
                    'ticket_verification_date' => null,
                    'status' => $trip['status'],
                    'description' => $trip['description'],
                    'special_notes' => $trip['special_notes'],
                    'is_approved' => (bool)$trip['is_approved'],
                    'created_at' => $trip['created_at'],
                    'updated_at' => $trip['updated_at'],
                    'published_at' => $trip['published_at'],
                    'favorited_at' => $trip['favorited_at'],
                    'user_verified' => (bool)$trip['user_verified']
                ];
            }, $favorites);

            return $this->jsonResponse($response, [
                'success' => true,
                'data' => $formattedTrips,
                'count' => count($formattedTrips)
            ]);

        } catch (Exception $e) {
            $this->logger->error('[FavoriteController] Erreur récupération favoris', [
                'error' => $e->getMessage(),
                'user_id' => $userId ?? null
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la récupération des favoris'
            ], 500);
        }
    }

    private function jsonResponse(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withStatus($status)->withHeader('Content-Type', 'application/json');
    }
}