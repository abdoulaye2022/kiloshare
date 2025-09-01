<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use KiloShare\Modules\Booking\Models\Booking;
use KiloShare\Modules\Booking\Models\Transaction;
use Exception;
use PDO;

class BookingController
{
    private PDO $db;
    private Booking $bookingModel;
    private Transaction $transactionModel;

    public function __construct(PDO $db)
    {
        $this->db = $db;
        $this->bookingModel = new Booking($db);
        $this->transactionModel = new Transaction($db);
    }

    /**
     * Créer une nouvelle demande de réservation
     */
    public function createBookingRequest(Request $request, Response $response): Response
    {
        try {
            $data = json_decode($request->getBody()->getContents(), true);
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            
            // Validation des données requises
            $requiredFields = ['trip_id', 'receiver_id', 'package_description', 'weight_kg', 'proposed_price'];
            foreach ($requiredFields as $field) {
                if (!isset($data[$field]) || empty($data[$field])) {
                    $response->getBody()->write(json_encode([
                        'success' => false,
                        'error' => "Le champ '$field' est requis"
                    ]));
                    return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
                }
            }

            // Vérifier que l'utilisateur ne fait pas une demande sur son propre voyage
            if ($userId == $data['receiver_id']) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Vous ne pouvez pas faire une demande sur votre propre voyage'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $bookingData = [
                'trip_id' => (int)$data['trip_id'],
                'sender_id' => $userId,
                'receiver_id' => (int)$data['receiver_id'],
                'package_description' => $data['package_description'],
                'weight_kg' => (float)$data['weight_kg'],
                'dimensions_cm' => $data['dimensions_cm'] ?? null,
                'proposed_price' => (float)$data['proposed_price'],
                'pickup_address' => $data['pickup_address'] ?? null,
                'delivery_address' => $data['delivery_address'] ?? null,
                'special_instructions' => $data['special_instructions'] ?? null
            ];

            $booking = $this->bookingModel->create($bookingData);

            $response->getBody()->write(json_encode([
                'success' => true,
                'booking' => $booking,
                'message' => 'Demande de réservation créée avec succès'
            ]));

            return $response->withStatus(201)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::createBookingRequest: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la création de la réservation'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Récupérer les réservations de l'utilisateur
     */
    public function getUserBookings(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            $queryParams = $request->getQueryParams();
            $role = $queryParams['role'] ?? 'all'; // 'sender', 'receiver', 'all'
            
            $bookings = $this->bookingModel->getUserBookings($userId, $role);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'bookings' => $bookings
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::getUserBookings: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la récupération des réservations'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Récupérer une réservation spécifique
     */
    public function getBooking(Request $request, Response $response, array $args): Response
    {
        try {
            $bookingId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            
            $booking = $this->bookingModel->getById($bookingId);
            
            // Vérifier que l'utilisateur a accès à cette réservation
            if ($booking['sender_id'] != $userId && $booking['receiver_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Accès non autorisé à cette réservation'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'booking' => $booking
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::getBooking: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la récupération de la réservation'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Accepter une demande de réservation
     */
    public function acceptBooking(Request $request, Response $response, array $args): Response
    {
        try {
            $bookingId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            $data = json_decode($request->getBody()->getContents(), true);
            
            $booking = $this->bookingModel->getById($bookingId);
            
            // Vérifier que l'utilisateur est le propriétaire du voyage
            if ($booking['receiver_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Seul le propriétaire du voyage peut accepter cette réservation'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier que la réservation est en attente
            if ($booking['status'] !== 'pending') {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Cette réservation ne peut plus être acceptée'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $finalPrice = isset($data['final_price']) ? (float)$data['final_price'] : null;
            
            $this->bookingModel->accept($bookingId, $finalPrice);
            
            $updatedBooking = $this->bookingModel->getById($bookingId);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'booking' => $updatedBooking,
                'message' => 'Réservation acceptée avec succès'
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::acceptBooking: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de l\'acceptation de la réservation'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Rejeter une demande de réservation
     */
    public function rejectBooking(Request $request, Response $response, array $args): Response
    {
        try {
            $bookingId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            
            $booking = $this->bookingModel->getById($bookingId);
            
            // Vérifier que l'utilisateur est le propriétaire du voyage
            if ($booking['receiver_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Seul le propriétaire du voyage peut rejeter cette réservation'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier que la réservation est en attente
            if ($booking['status'] !== 'pending') {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Cette réservation ne peut plus être rejetée'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $this->bookingModel->reject($bookingId);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Réservation rejetée avec succès'
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::rejectBooking: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors du rejet de la réservation'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Ajouter une négociation de prix
     */
    public function addNegotiation(Request $request, Response $response, array $args): Response
    {
        try {
            $bookingId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            $data = json_decode($request->getBody()->getContents(), true);
            
            if (!isset($data['amount']) || $data['amount'] <= 0) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Montant invalide pour la négociation'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $booking = $this->bookingModel->getById($bookingId);
            
            // Vérifier que l'utilisateur fait partie de cette réservation
            if ($booking['sender_id'] != $userId && $booking['receiver_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Accès non autorisé à cette réservation'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier que la réservation permet encore les négociations
            if (!in_array($booking['status'], ['pending', 'accepted'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Cette réservation ne permet plus de négociations'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $negotiationId = $this->bookingModel->addNegotiation(
                $bookingId,
                $userId,
                (float)$data['amount'],
                $data['message'] ?? null
            );
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'negotiation_id' => $negotiationId,
                'message' => 'Négociation ajoutée avec succès'
            ]));

            return $response->withStatus(201)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::addNegotiation: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de l\'ajout de la négociation'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Marquer une réservation comme prête pour le paiement
     */
    public function markPaymentReady(Request $request, Response $response, array $args): Response
    {
        try {
            $bookingId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            
            $booking = $this->bookingModel->getById($bookingId);
            
            // Seul le propriétaire du voyage peut marquer comme prêt pour paiement
            if ($booking['receiver_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Seul le propriétaire du voyage peut marquer comme prêt pour le paiement'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier que la réservation est acceptée
            if ($booking['status'] !== 'accepted') {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'La réservation doit être acceptée avant le paiement'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $this->bookingModel->updateStatus($bookingId, 'payment_pending');
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Réservation marquée comme prête pour le paiement'
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::markPaymentReady: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la mise à jour du statut'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Ajouter une photo de colis
     */
    public function addPackagePhoto(Request $request, Response $response, array $args): Response
    {
        try {
            $bookingId = (int)$args['id'];
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            $data = json_decode($request->getBody()->getContents(), true);
            
            $booking = $this->bookingModel->getById($bookingId);
            
            // Vérifier que l'utilisateur fait partie de cette réservation
            if ($booking['sender_id'] != $userId && $booking['receiver_id'] != $userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Accès non autorisé à cette réservation'
                ]));
                return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            }
            
            if (!isset($data['photo_url']) || empty($data['photo_url'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'URL de la photo requise'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            $photoId = $this->bookingModel->addPackagePhoto(
                $bookingId,
                $userId,
                $data['photo_url'],
                $data['photo_type'] ?? 'package',
                $data['cloudinary_id'] ?? null
            );
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'photo_id' => $photoId,
                'message' => 'Photo ajoutée avec succès'
            ]));

            return $response->withStatus(201)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur BookingController::addPackagePhoto: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de l\'ajout de la photo'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
}