<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\User;
use KiloShare\Services\SmartNotificationService;
use Carbon\Carbon;
use PDO;

class SimpleTrackingService
{
    private PDO $db;
    private MessagingService $messagingService;
    private SmartNotificationService $notificationService;

    public function __construct()
    {
        $this->db = \KiloShare\Database\Connection::getInstance();
        $this->messagingService = new MessagingService();
        $this->notificationService = new SmartNotificationService();
    }

    /**
     * Pickup simplifié - photo obligatoire, code optionnel
     */
    public function confirmPickup(int $bookingId, int $carrierId, string $photoUrl, ?string $pickupCode = null): array
    {
        try {
            $this->db->beginTransaction();

            // Vérifier que le booking existe et que le carrier est correct
            $booking = $this->getBooking($bookingId);
            if (!$booking || $booking['carrier_id'] !== $carrierId) {
                throw new \Exception('Booking not found or unauthorized');
            }

            if ($booking['status'] !== 'confirmed') {
                throw new \Exception('Booking must be confirmed before pickup');
            }

            // Vérifier le code de pickup si fourni
            if (!empty($booking['pickup_code']) && $pickupCode !== $booking['pickup_code']) {
                throw new \Exception('Invalid pickup code');
            }

            // Mettre à jour le booking avec la photo
            $stmt = $this->db->prepare("
                UPDATE bookings 
                SET pickup_photo_url = ?, updated_at = NOW() 
                WHERE id = ?
            ");
            $stmt->execute([$photoUrl, $bookingId]);

            // Créer l'événement de pickup
            $this->createTripEvent($bookingId, 'pickup_confirmed', $carrierId, 
                'Colis récupéré avec succès', $photoUrl);

            // Notification au sender
            $this->notificationService->send($booking['sender_id'], 'pickup_confirmed', [
                'carrier_name' => $booking['carrier_first_name'] . ' ' . $booking['carrier_last_name'],
                'pickup_time' => date('H:i'),
                'pickup_date' => date('d/m/Y')
            ]);

            // Message automatique dans la conversation
            $this->messagingService->sendSystemMessage($bookingId, 
                "📦 Colis récupéré par {$booking['carrier_first_name']} à " . date('H:i'));

            $this->db->commit();

            return [
                'success' => true,
                'message' => 'Pickup confirmé avec succès',
                'status' => 'picked_up'
            ];

        } catch (\Exception $e) {
            $this->db->rollBack();
            return [
                'success' => false,
                'message' => $e->getMessage()
            ];
        }
    }

    /**
     * Démarrer le trajet - simple notification
     */
    public function startRoute(int $bookingId, int $carrierId, ?float $lat = null, ?float $lng = null): array
    {
        try {
            $booking = $this->getBooking($bookingId);
            if (!$booking || $booking['carrier_id'] !== $carrierId) {
                throw new \Exception('Booking not found or unauthorized');
            }

            if ($booking['status'] !== 'picked_up') {
                throw new \Exception('Package must be picked up first');
            }

            // Créer l'événement
            $this->createTripEvent($bookingId, 'en_route_started', $carrierId, 
                'Transport en cours', null, $lat, $lng);

            // Notification au sender
            $this->notificationService->send($booking['sender_id'], 'en_route_started', [
                'carrier_name' => $booking['carrier_first_name'] . ' ' . $booking['carrier_last_name'],
                'estimated_delivery' => 'Bientôt'
            ]);

            // Message automatique
            $this->messagingService->sendSystemMessage($bookingId, 
                "🚗 Transport en cours vers la destination");

            return [
                'success' => true,
                'message' => 'Trajet démarré',
                'status' => 'en_route'
            ];

        } catch (\Exception $e) {
            return [
                'success' => false,
                'message' => $e->getMessage()
            ];
        }
    }

    /**
     * Livraison simple - photo obligatoire, code optionnel
     */
    public function confirmDelivery(int $bookingId, int $carrierId, string $photoUrl, ?string $deliveryCode = null): array
    {
        try {
            $this->db->beginTransaction();

            $booking = $this->getBooking($bookingId);
            if (!$booking || $booking['carrier_id'] !== $carrierId) {
                throw new \Exception('Booking not found or unauthorized');
            }

            if ($booking['status'] !== 'en_route') {
                throw new \Exception('Package must be en route for delivery');
            }

            // Vérifier le code de livraison si fourni
            if (!empty($booking['delivery_code']) && $deliveryCode !== $booking['delivery_code']) {
                throw new \Exception('Invalid delivery code');
            }

            // Mettre à jour le booking
            $stmt = $this->db->prepare("
                UPDATE bookings 
                SET delivery_photo_url = ?, updated_at = NOW() 
                WHERE id = ?
            ");
            $stmt->execute([$photoUrl, $bookingId]);

            // Créer l'événement de livraison
            $this->createTripEvent($bookingId, 'delivery_confirmed', $carrierId, 
                'Colis livré avec succès', $photoUrl);

            // Notification au sender
            $this->notificationService->send($booking['sender_id'], 'delivery_confirmed', [
                'carrier_name' => $booking['carrier_first_name'] . ' ' . $booking['carrier_last_name'],
                'delivery_time' => date('H:i'),
                'delivery_date' => date('d/m/Y')
            ]);

            // Message automatique
            $this->messagingService->sendSystemMessage($bookingId, 
                "✅ Colis livré avec succès à " . date('H:i'));

            // Déclencher le paiement automatique (si intégré)
            $this->triggerAutomaticPayment($bookingId);

            $this->db->commit();

            return [
                'success' => true,
                'message' => 'Livraison confirmée avec succès',
                'status' => 'delivered'
            ];

        } catch (\Exception $e) {
            $this->db->rollBack();
            return [
                'success' => false,
                'message' => $e->getMessage()
            ];
        }
    }

    /**
     * Signaler un problème
     */
    public function reportIssue(int $bookingId, int $userId, string $issueType, string $description): array
    {
        try {
            // Créer le rapport
            $stmt = $this->db->prepare("
                INSERT INTO booking_reports (booking_id, reporter_id, report_type, description)
                VALUES (?, ?, ?, ?)
            ");
            $stmt->execute([$bookingId, $userId, $issueType, $description]);

            // Créer un événement
            $this->createTripEvent($bookingId, 'issue_reported', $userId, $description);

            // Notifier l'admin
            $this->notificationService->send(1, 'issue_reported', [
                'booking_id' => $bookingId,
                'issue_type' => $issueType,
                'reporter_id' => $userId
            ]);

            return [
                'success' => true,
                'message' => 'Problème signalé. Notre équipe va examiner votre demande.'
            ];

        } catch (\Exception $e) {
            return [
                'success' => false,
                'message' => $e->getMessage()
            ];
        }
    }

    /**
     * Obtenir le statut détaillé du tracking
     */
    public function getTrackingStatus(int $bookingId): array
    {
        $booking = $this->getBooking($bookingId);
        if (!$booking) {
            return ['success' => false, 'message' => 'Booking not found'];
        }

        // Récupérer les événements
        $stmt = $this->db->prepare("
            SELECT te.*, u.first_name, u.last_name 
            FROM trip_events te
            LEFT JOIN users u ON te.user_id = u.id
            WHERE te.booking_id = ?
            ORDER BY te.created_at ASC
        ");
        $stmt->execute([$bookingId]);
        $events = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return [
            'success' => true,
            'booking' => $booking,
            'events' => $events,
            'current_status' => $booking['status'],
            'progress_steps' => $this->getProgressSteps($booking['status'])
        ];
    }

    private function getBooking(int $bookingId): ?array
    {
        $stmt = $this->db->prepare("
            SELECT b.*, 
                   u1.first_name as sender_first_name, u1.last_name as sender_last_name,
                   u2.first_name as carrier_first_name, u2.last_name as carrier_last_name
            FROM bookings b
            LEFT JOIN users u1 ON b.sender_id = u1.id
            LEFT JOIN users u2 ON b.carrier_id = u2.id
            WHERE b.id = ?
        ");
        $stmt->execute([$bookingId]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    private function createTripEvent(int $bookingId, string $eventType, int $userId, 
                                    ?string $message = null, ?string $photoUrl = null, 
                                    ?float $lat = null, ?float $lng = null): void
    {
        $stmt = $this->db->prepare("
            INSERT INTO trip_events (booking_id, event_type, user_id, message, photo_url, location_lat, location_lng)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([$bookingId, $eventType, $userId, $message, $photoUrl, $lat, $lng]);
    }

    private function getProgressSteps(string $status): array
    {
        $steps = [
            'confirmed' => ['completed' => true, 'label' => 'Confirmé'],
            'picked_up' => ['completed' => in_array($status, ['picked_up', 'en_route', 'delivered']), 'label' => 'Récupéré'],
            'en_route' => ['completed' => in_array($status, ['en_route', 'delivered']), 'label' => 'En route'],
            'delivered' => ['completed' => $status === 'delivered', 'label' => 'Livré']
        ];

        return $steps;
    }

    private function triggerAutomaticPayment(int $bookingId): void
    {
        try {
            // Intégration avec Stripe pour libérer l'escrow
            $booking = $this->getBooking($bookingId);
            if (!$booking || $booking['payment_status'] !== 'pending') {
                return;
            }

            // Simuler la libération de l'escrow Stripe
            // Dans un vrai système, on ferait appel à l'API Stripe
            $stmt = $this->db->prepare("
                UPDATE bookings 
                SET payment_status = 'paid' 
                WHERE id = ? AND payment_status = 'pending'
            ");
            $stmt->execute([$bookingId]);

            // Notification de paiement au carrier
            $this->notificationService->send($booking['carrier_id'], 'payment_released', [
                'amount' => number_format($booking['price'], 2) . '€',
                'booking_id' => $bookingId
            ]);

            // Message automatique
            $this->messagingService->sendSystemMessage($bookingId, 
                "💰 Paiement libéré automatiquement suite à la livraison");

        } catch (\Exception $e) {
            error_log("Erreur paiement automatique pour booking $bookingId: " . $e->getMessage());
        }
    }
}