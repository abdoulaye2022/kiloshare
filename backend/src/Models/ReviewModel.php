<?php

declare(strict_types=1);

namespace KiloShare\Models;

use PDO;

class ReviewModel
{
    private PDO $db;

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    /**
     * Créer une nouvelle review
     */
    public function create(array $data): int
    {
        $sql = "INSERT INTO reviews (booking_id, reviewer_id, reviewed_id, rating, comment)
                VALUES (:booking_id, :reviewer_id, :reviewed_id, :rating, :comment)";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            'booking_id' => $data['booking_id'],
            'reviewer_id' => $data['reviewer_id'],
            'reviewed_id' => $data['reviewed_id'],
            'rating' => $data['rating'],
            'comment' => $data['comment'] ?? null,
        ]);
        
        $reviewId = (int) $this->db->lastInsertId();
        
        // Vérifier si les deux reviews existent pour cette booking
        $this->checkAndPublishMutualReviews((int) $data['booking_id']);
        
        return $reviewId;
    }

    /**
     * Vérifier si les deux parties ont reviewé et publier si c'est le cas
     */
    private function checkAndPublishMutualReviews(int $bookingId): void
    {
        $sql = "SELECT COUNT(*) as review_count FROM reviews WHERE booking_id = :booking_id";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(['booking_id' => $bookingId]);
        $result = $stmt->fetch();
        
        // Si il y a 2 reviews pour cette booking, les rendre visibles
        if ($result['review_count'] == 2) {
            $updateSql = "UPDATE reviews SET is_visible = TRUE WHERE booking_id = :booking_id";
            $updateStmt = $this->db->prepare($updateSql);
            $updateStmt->execute(['booking_id' => $bookingId]);
        }
    }

    /**
     * Récupérer une review par booking_id et reviewer_id
     */
    public function getByBookingAndReviewer(int $bookingId, int $reviewerId): ?array
    {
        $sql = "SELECT * FROM reviews 
                WHERE booking_id = :booking_id AND reviewer_id = :reviewer_id";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            'booking_id' => $bookingId,
            'reviewer_id' => $reviewerId
        ]);
        
        $result = $stmt->fetch();
        return $result ?: null;
    }

    /**
     * Récupérer les reviews d'un utilisateur
     */
    public function getUserReviews(int $userId, int $limit = 20, int $offset = 0): array
    {
        $sql = "SELECT r.*, 
                       reviewer.first_name as reviewer_first_name,
                       reviewer.last_name as reviewer_last_name,
                       reviewer.avatar as reviewer_avatar,
                       b.trip_id,
                       t.departure_city,
                       t.arrival_city
                FROM reviews r
                JOIN users reviewer ON r.reviewer_id = reviewer.id
                JOIN bookings b ON r.booking_id = b.id
                JOIN trips t ON b.trip_id = t.id
                WHERE r.reviewed_id = :user_id 
                AND r.is_visible = TRUE
                ORDER BY r.created_at DESC
                LIMIT :limit OFFSET :offset";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue('user_id', $userId, PDO::PARAM_INT);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->bindValue('offset', $offset, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    /**
     * Récupérer les stats de rating d'un utilisateur
     */
    public function getUserRating(int $userId): ?array
    {
        $sql = "SELECT * FROM user_ratings WHERE user_id = :user_id";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(['user_id' => $userId]);
        
        $result = $stmt->fetch();
        if (!$result) {
            // Créer un rating par défaut si inexistant
            $this->createDefaultUserRating($userId);
            return $this->getUserRating($userId);
        }
        
        return $result;
    }

    /**
     * Créer un rating par défaut pour un utilisateur
     */
    private function createDefaultUserRating(int $userId): void
    {
        $sql = "INSERT IGNORE INTO user_ratings (user_id) VALUES (:user_id)";
        $stmt = $this->db->prepare($sql);
        $stmt->execute(['user_id' => $userId]);
    }

    /**
     * Récupérer les bookings éligibles pour review (livrées depuis 24h+)
     */
    public function getEligibleBookingsForReview(): array
    {
        $sql = "SELECT DISTINCT b.id as booking_id,
                       b.user_id as sender_id,
                       t.user_id as traveler_id,
                       b.status,
                       b.delivered_at,
                       t.departure_city,
                       t.arrival_city
                FROM bookings b
                JOIN trips t ON b.trip_id = t.id
                WHERE b.status = 'delivered'
                AND b.delivered_at <= DATE_SUB(NOW(), INTERVAL 24 HOUR)
                AND b.delivered_at >= DATE_SUB(NOW(), INTERVAL 15 DAY)
                AND NOT EXISTS (
                    SELECT 1 FROM reviews r 
                    WHERE r.booking_id = b.id 
                    AND r.reviewer_id = b.user_id
                )
                OR NOT EXISTS (
                    SELECT 1 FROM reviews r 
                    WHERE r.booking_id = b.id 
                    AND r.reviewer_id = t.user_id
                )";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    /**
     * Publier automatiquement les reviews en attente après 14 jours
     */
    public function autoPublishPendingReviews(): int
    {
        $sql = "UPDATE reviews r
                JOIN bookings b ON r.booking_id = b.id
                SET r.is_visible = TRUE,
                    r.auto_published_at = NOW()
                WHERE r.is_visible = FALSE
                AND b.delivered_at <= DATE_SUB(NOW(), INTERVAL 14 DAY)
                AND b.status = 'delivered'";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return $stmt->rowCount();
    }

    /**
     * Vérifier si un utilisateur peut créer une review pour une booking
     */
    public function canUserReviewBooking(int $userId, int $bookingId): array
    {
        // Récupérer les infos de la booking
        $sql = "SELECT b.id, b.user_id as sender_id, b.status, b.delivered_at,
                       t.user_id as traveler_id
                FROM bookings b
                JOIN trips t ON b.trip_id = t.id
                WHERE b.id = :booking_id";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute(['booking_id' => $bookingId]);
        $booking = $stmt->fetch();
        
        if (!$booking) {
            return ['can_review' => false, 'reason' => 'booking_not_found'];
        }
        
        // Vérifier que l'utilisateur est impliqué dans la booking
        if ($userId !== (int) $booking['sender_id'] && $userId !== (int) $booking['traveler_id']) {
            return ['can_review' => false, 'reason' => 'not_participant'];
        }
        
        // Vérifier que la booking est livrée
        if ($booking['status'] !== 'delivered') {
            return ['can_review' => false, 'reason' => 'not_delivered'];
        }
        
        // Vérifier que 24h se sont écoulées depuis la livraison
        $deliveredAt = new \DateTime($booking['delivered_at']);
        $now = new \DateTime();
        $diff = $now->diff($deliveredAt);
        
        if ($diff->h < 24 && $diff->days === 0) {
            return ['can_review' => false, 'reason' => 'too_early'];
        }
        
        // Vérifier si l'utilisateur a déjà reviewé
        $existingReview = $this->getByBookingAndReviewer($bookingId, $userId);
        if ($existingReview) {
            return ['can_review' => false, 'reason' => 'already_reviewed'];
        }
        
        // Déterminer qui est reviewé
        $reviewedId = ($userId === (int) $booking['sender_id']) 
            ? (int) $booking['traveler_id'] 
            : (int) $booking['sender_id'];
        
        return [
            'can_review' => true,
            'booking' => $booking,
            'reviewed_id' => $reviewedId,
            'user_role' => ($userId === (int) $booking['sender_id']) ? 'sender' : 'traveler'
        ];
    }

    /**
     * Récupérer les utilisateurs avec les meilleures notes (pour tri recherche)
     */
    public function getTopRatedUsers(int $limit = 50): array
    {
        $sql = "SELECT user_id, average_rating, total_reviews
                FROM user_ratings
                WHERE total_reviews >= 3
                ORDER BY average_rating DESC, total_reviews DESC
                LIMIT :limit";
        
        $stmt = $this->db->prepare($sql);
        $stmt->bindValue('limit', $limit, PDO::PARAM_INT);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }

    /**
     * Enregistrer un rappel de review envoyé
     */
    public function recordReviewReminder(int $bookingId, int $userId, string $reminderType): void
    {
        $sql = "INSERT IGNORE INTO review_reminders (booking_id, user_id, reminder_type)
                VALUES (:booking_id, :user_id, :reminder_type)";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            'booking_id' => $bookingId,
            'user_id' => $userId,
            'reminder_type' => $reminderType
        ]);
    }

    /**
     * Vérifier si un rappel a déjà été envoyé
     */
    public function hasReminderBeenSent(int $bookingId, int $userId, string $reminderType): bool
    {
        $sql = "SELECT COUNT(*) as count FROM review_reminders 
                WHERE booking_id = :booking_id 
                AND user_id = :user_id 
                AND reminder_type = :reminder_type";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            'booking_id' => $bookingId,
            'user_id' => $userId,
            'reminder_type' => $reminderType
        ]);
        
        $result = $stmt->fetch();
        return (int) $result['count'] > 0;
    }

    /**
     * Récupérer les bookings nécessitant des rappels J+3
     */
    public function getBookingsNeedingReminders(): array
    {
        $sql = "SELECT DISTINCT b.id as booking_id,
                       b.user_id as sender_id,
                       t.user_id as traveler_id,
                       b.delivered_at
                FROM bookings b
                JOIN trips t ON b.trip_id = t.id
                WHERE b.status = 'delivered'
                AND b.delivered_at <= DATE_SUB(NOW(), INTERVAL 3 DAY)
                AND b.delivered_at >= DATE_SUB(NOW(), INTERVAL 15 DAY)
                AND (
                    NOT EXISTS (
                        SELECT 1 FROM reviews r 
                        WHERE r.booking_id = b.id 
                        AND r.reviewer_id = b.user_id
                    )
                    OR NOT EXISTS (
                        SELECT 1 FROM reviews r 
                        WHERE r.booking_id = b.id 
                        AND r.reviewer_id = t.user_id
                    )
                )";
        
        $stmt = $this->db->prepare($sql);
        $stmt->execute();
        
        return $stmt->fetchAll();
    }
}