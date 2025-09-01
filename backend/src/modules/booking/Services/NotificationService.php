<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Services;

use PDO;
use PDOException;
use Exception;

class NotificationService
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    /**
     * Créer une notification de réservation
     */
    public function createBookingNotification(
        int $bookingId,
        int $userId,
        string $type,
        string $title,
        string $message
    ): int {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO booking_notifications (booking_id, user_id, type, title, message)
                VALUES (?, ?, ?, ?, ?)
            ");
            
            $stmt->execute([$bookingId, $userId, $type, $title, $message]);
            return (int)$this->db->lastInsertId();
            
        } catch (PDOException $e) {
            error_log("Erreur NotificationService::createBookingNotification: " . $e->getMessage());
            throw new Exception('Erreur lors de la création de la notification');
        }
    }

    /**
     * Notifications automatiques pour nouvelle réservation
     */
    public function notifyNewBooking(int $bookingId, array $bookingData): void
    {
        $receiverId = $bookingData['receiver_id'];
        $senderName = $bookingData['sender_first_name'] ?? 'Un utilisateur';
        $packageDescription = $bookingData['package_description'];
        
        $this->createBookingNotification(
            $bookingId,
            $receiverId,
            'new_booking',
            'Nouvelle demande de réservation',
            "{$senderName} souhaite transporter \"{$packageDescription}\" avec vous"
        );
    }

    /**
     * Notifications pour acceptation de réservation
     */
    public function notifyBookingAccepted(int $bookingId, array $bookingData): void
    {
        $senderId = $bookingData['sender_id'];
        $receiverName = $bookingData['receiver_first_name'] ?? 'Le transporteur';
        $packageDescription = $bookingData['package_description'];
        
        $this->createBookingNotification(
            $bookingId,
            $senderId,
            'booking_accepted',
            'Réservation acceptée',
            "{$receiverName} a accepté de transporter \"{$packageDescription}\""
        );
    }

    /**
     * Notifications pour rejet de réservation
     */
    public function notifyBookingRejected(int $bookingId, array $bookingData): void
    {
        $senderId = $bookingData['sender_id'];
        $receiverName = $bookingData['receiver_first_name'] ?? 'Le transporteur';
        $packageDescription = $bookingData['package_description'];
        
        $this->createBookingNotification(
            $bookingId,
            $senderId,
            'booking_rejected',
            'Réservation rejetée',
            "{$receiverName} n'a pas pu accepter de transporter \"{$packageDescription}\""
        );
    }

    /**
     * Notifications pour négociation de prix
     */
    public function notifyNegotiationOffer(int $bookingId, array $bookingData, array $negotiationData): void
    {
        $targetUserId = $negotiationData['proposed_by'] == $bookingData['sender_id'] 
            ? $bookingData['receiver_id'] 
            : $bookingData['sender_id'];
        
        $proposerName = $negotiationData['proposed_by'] == $bookingData['sender_id']
            ? ($bookingData['sender_first_name'] ?? 'L\'expéditeur')
            : ($bookingData['receiver_first_name'] ?? 'Le transporteur');
        
        $amount = number_format($negotiationData['amount'], 2);
        
        $this->createBookingNotification(
            $bookingId,
            $targetUserId,
            'negotiation_offer',
            'Nouvelle offre de prix',
            "{$proposerName} propose {$amount}$ pour cette réservation"
        );
    }

    /**
     * Notifications pour paiement requis
     */
    public function notifyPaymentRequired(int $bookingId, array $bookingData): void
    {
        $senderId = $bookingData['sender_id'];
        $amount = number_format($bookingData['final_price'] ?? $bookingData['proposed_price'], 2);
        
        $this->createBookingNotification(
            $bookingId,
            $senderId,
            'payment_required',
            'Paiement requis',
            "Veuillez procéder au paiement de {$amount}$ pour finaliser votre réservation"
        );
    }

    /**
     * Notifications pour confirmation de paiement
     */
    public function notifyPaymentConfirmed(int $bookingId, array $bookingData, array $transactionData): void
    {
        $receiverId = $bookingData['receiver_id'];
        $senderName = $bookingData['sender_first_name'] ?? 'L\'expéditeur';
        $amount = number_format($transactionData['receiver_amount'], 2);
        
        $this->createBookingNotification(
            $bookingId,
            $receiverId,
            'payment_confirmed',
            'Paiement confirmé',
            "{$senderName} a payé {$amount}$. Vous pouvez maintenant organiser le transport"
        );
    }

    /**
     * Notifications pour transport en cours
     */
    public function notifyInTransit(int $bookingId, array $bookingData): void
    {
        $senderId = $bookingData['sender_id'];
        $receiverName = $bookingData['receiver_first_name'] ?? 'Le transporteur';
        
        $this->createBookingNotification(
            $bookingId,
            $senderId,
            'in_transit',
            'Transport en cours',
            "{$receiverName} a pris en charge votre colis et est en route"
        );
    }

    /**
     * Notifications pour livraison
     */
    public function notifyDelivered(int $bookingId, array $bookingData): void
    {
        // Notifier l'expéditeur
        $this->createBookingNotification(
            $bookingId,
            $bookingData['sender_id'],
            'delivered',
            'Colis livré',
            "Votre colis a été livré avec succès. Confirmez la réception pour finaliser la transaction"
        );
        
        // Notifier le transporteur
        $this->createBookingNotification(
            $bookingId,
            $bookingData['receiver_id'],
            'delivered',
            'Livraison effectuée',
            "Vous avez marqué le colis comme livré. En attente de confirmation du destinataire"
        );
    }

    /**
     * Notifications pour transaction complétée
     */
    public function notifyCompleted(int $bookingId, array $bookingData): void
    {
        $senderName = $bookingData['sender_first_name'] ?? 'L\'expéditeur';
        $receiverName = $bookingData['receiver_first_name'] ?? 'Le transporteur';
        
        // Notifier l'expéditeur
        $this->createBookingNotification(
            $bookingId,
            $bookingData['sender_id'],
            'completed',
            'Transport terminé',
            "Votre transport avec {$receiverName} est maintenant terminé. Merci d'utiliser KiloShare!"
        );
        
        // Notifier le transporteur
        $this->createBookingNotification(
            $bookingId,
            $bookingData['receiver_id'],
            'completed',
            'Transport terminé',
            "Votre transport pour {$senderName} est maintenant terminé. Les fonds ont été libérés"
        );
    }

    /**
     * Récupérer les notifications d'un utilisateur
     */
    public function getUserNotifications(int $userId, bool $unreadOnly = false): array
    {
        try {
            $whereClause = "user_id = ?";
            $params = [$userId];
            
            if ($unreadOnly) {
                $whereClause .= " AND is_read = FALSE";
            }
            
            $stmt = $this->db->prepare("
                SELECT n.*, b.package_description, b.status as booking_status
                FROM booking_notifications n
                LEFT JOIN bookings b ON n.booking_id = b.id
                WHERE {$whereClause}
                ORDER BY n.created_at DESC
                LIMIT 50
            ");
            
            $stmt->execute($params);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);
            
        } catch (PDOException $e) {
            error_log("Erreur NotificationService::getUserNotifications: " . $e->getMessage());
            throw new Exception('Erreur lors de la récupération des notifications');
        }
    }

    /**
     * Marquer des notifications comme lues
     */
    public function markAsRead(array $notificationIds, int $userId): bool
    {
        try {
            if (empty($notificationIds)) {
                return true;
            }
            
            $placeholders = str_repeat('?,', count($notificationIds) - 1) . '?';
            $params = array_merge($notificationIds, [$userId]);
            
            $stmt = $this->db->prepare("
                UPDATE booking_notifications 
                SET is_read = TRUE 
                WHERE id IN ($placeholders) AND user_id = ?
            ");
            
            return $stmt->execute($params);
            
        } catch (PDOException $e) {
            error_log("Erreur NotificationService::markAsRead: " . $e->getMessage());
            throw new Exception('Erreur lors de la mise à jour des notifications');
        }
    }

    /**
     * Marquer toutes les notifications comme lues
     */
    public function markAllAsRead(int $userId): bool
    {
        try {
            $stmt = $this->db->prepare("
                UPDATE booking_notifications 
                SET is_read = TRUE 
                WHERE user_id = ? AND is_read = FALSE
            ");
            
            return $stmt->execute([$userId]);
            
        } catch (PDOException $e) {
            error_log("Erreur NotificationService::markAllAsRead: " . $e->getMessage());
            throw new Exception('Erreur lors de la mise à jour des notifications');
        }
    }

    /**
     * Obtenir le nombre de notifications non lues
     */
    public function getUnreadCount(int $userId): int
    {
        try {
            $stmt = $this->db->prepare("
                SELECT COUNT(*) 
                FROM booking_notifications 
                WHERE user_id = ? AND is_read = FALSE
            ");
            
            $stmt->execute([$userId]);
            return (int)$stmt->fetchColumn();
            
        } catch (PDOException $e) {
            error_log("Erreur NotificationService::getUnreadCount: " . $e->getMessage());
            return 0;
        }
    }

    /**
     * Supprimer les anciennes notifications
     */
    public function cleanupOldNotifications(int $daysToKeep = 30): int
    {
        try {
            $stmt = $this->db->prepare("
                DELETE FROM booking_notifications 
                WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)
            ");
            
            $stmt->execute([$daysToKeep]);
            return $stmt->rowCount();
            
        } catch (PDOException $e) {
            error_log("Erreur NotificationService::cleanupOldNotifications: " . $e->getMessage());
            throw new Exception('Erreur lors du nettoyage des notifications');
        }
    }

    /**
     * Envoyer des notifications push (simulation)
     */
    public function sendPushNotification(int $userId, string $title, string $message, array $data = []): bool
    {
        // En mode développement, juste logger
        error_log("PUSH NOTIFICATION [User $userId]: $title - $message");
        
        // En production, intégrer avec Firebase Cloud Messaging ou service similaire
        // $this->firebaseService->sendToUser($userId, $title, $message, $data);
        
        return true;
    }

    /**
     * Obtenir les statistiques de notifications
     */
    public function getNotificationStats(int $userId): array
    {
        try {
            $stmt = $this->db->prepare("
                SELECT 
                    COUNT(*) as total_notifications,
                    COUNT(CASE WHEN is_read = FALSE THEN 1 END) as unread_notifications,
                    COUNT(CASE WHEN type = 'new_booking' THEN 1 END) as new_booking_notifications,
                    COUNT(CASE WHEN type = 'payment_confirmed' THEN 1 END) as payment_notifications,
                    COUNT(CASE WHEN created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as recent_notifications
                FROM booking_notifications 
                WHERE user_id = ?
            ");
            
            $stmt->execute([$userId]);
            return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
            
        } catch (PDOException $e) {
            error_log("Erreur NotificationService::getNotificationStats: " . $e->getMessage());
            return [];
        }
    }
}