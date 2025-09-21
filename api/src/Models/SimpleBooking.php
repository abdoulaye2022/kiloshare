<?php

declare(strict_types=1);

namespace KiloShare\Models;

use PDO;
use Carbon\Carbon;

class SimpleBooking
{
    private static function getDb(): PDO
    {
        return \KiloShare\Database\Connection::getInstance();
    }

    /**
     * Créer une nouvelle réservation simple
     */
    public static function create(array $data): ?int
    {
        try {
            $db = self::getDb();
            $stmt = $db->prepare("
                INSERT INTO bookings (
                    uuid, sender_id, carrier_id, pickup_address, delivery_address,
                    package_description, pickup_date, pickup_time, price,
                    pickup_code, delivery_code, status, payment_status
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            
            $stmt->execute([
                $data['uuid'] ?? \Ramsey\Uuid\Uuid::uuid4()->toString(),
                $data['sender_id'],
                $data['carrier_id'],
                $data['pickup_address'],
                $data['delivery_address'],
                $data['package_description'] ?? null,
                $data['pickup_date'] ?? null,
                $data['pickup_time'] ?? null,
                $data['price'],
                $data['pickup_code'] ?? null,
                $data['delivery_code'] ?? null,
                $data['status'] ?? 'pending',
                $data['payment_status'] ?? 'pending'
            ]);

            return (int) $db->lastInsertId();

        } catch (\Exception $e) {
            error_log("Error creating booking: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Trouver une réservation par ID
     */
    public static function find(int $id): ?array
    {
        try {
            $db = self::getDb();
            $stmt = $db->prepare("
                SELECT b.*, 
                       u1.first_name as sender_first_name, u1.last_name as sender_last_name,
                       u1.email as sender_email, u1.phone as sender_phone,
                       u2.first_name as carrier_first_name, u2.last_name as carrier_last_name,
                       u2.email as carrier_email, u2.phone as carrier_phone
                FROM bookings b
                LEFT JOIN users u1 ON b.sender_id = u1.id
                LEFT JOIN users u2 ON b.carrier_id = u2.id
                WHERE b.id = ?
            ");
            $stmt->execute([$id]);
            return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;

        } catch (\Exception $e) {
            error_log("Error finding booking: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Obtenir les réservations d'un utilisateur
     */
    public static function getUserBookings(int $userId, ?string $status = null): array
    {
        try {
            $db = self::getDb();
            $sql = "
                SELECT b.*, 
                       CASE 
                           WHEN b.sender_id = ? THEN CONCAT(u2.first_name, ' ', u2.last_name)
                           ELSE CONCAT(u1.first_name, ' ', u1.last_name)
                       END as other_party_name,
                       CASE 
                           WHEN b.sender_id = ? THEN 'sender'
                           ELSE 'carrier'
                       END as user_role
                FROM bookings b
                LEFT JOIN users u1 ON b.sender_id = u1.id
                LEFT JOIN users u2 ON b.carrier_id = u2.id
                WHERE (b.sender_id = ? OR b.carrier_id = ?)
            ";

            $params = [$userId, $userId, $userId, $userId];

            if ($status) {
                $sql .= " AND b.status = ?";
                $params[] = $status;
            }

            $sql .= " ORDER BY b.created_at DESC";

            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            return $stmt->fetchAll(PDO::FETCH_ASSOC);

        } catch (\Exception $e) {
            error_log("Error getting user bookings: " . $e->getMessage());
            return [];
        }
    }

    /**
     * Vérifier si l'utilisateur peut accéder à cette réservation
     */
    public static function canUserAccess(int $bookingId, int $userId): bool
    {
        try {
            $db = self::getDb();
            $stmt = $db->prepare("
                SELECT COUNT(*) 
                FROM bookings 
                WHERE id = ? AND (sender_id = ? OR carrier_id = ?)
            ");
            $stmt->execute([$bookingId, $userId, $userId]);
            return $stmt->fetchColumn() > 0;

        } catch (\Exception $e) {
            error_log("Error checking booking access: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Obtenir les statistiques des réservations pour un utilisateur
     */
    public static function getUserStats(int $userId): array
    {
        try {
            $db = self::getDb();
            $stmt = $db->prepare("
                SELECT 
                    COUNT(*) as total_bookings,
                    SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as completed_bookings,
                    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_bookings,
                    SUM(CASE WHEN sender_id = ? THEN 1 ELSE 0 END) as as_sender,
                    SUM(CASE WHEN carrier_id = ? THEN 1 ELSE 0 END) as as_carrier,
                    AVG(CASE WHEN status = 'delivered' AND carrier_id = ? THEN 
                        (SELECT AVG(rating) FROM booking_reviews WHERE reviewed_id = ? AND booking_id = b.id)
                        ELSE NULL END) as avg_carrier_rating,
                    AVG(CASE WHEN status = 'delivered' AND sender_id = ? THEN 
                        (SELECT AVG(rating) FROM booking_reviews WHERE reviewed_id = ? AND booking_id = b.id)
                        ELSE NULL END) as avg_sender_rating
                FROM bookings b
                WHERE (sender_id = ? OR carrier_id = ?)
            ");
            
            $stmt->execute([$userId, $userId, $userId, $userId, $userId, $userId, $userId, $userId]);
            return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];

        } catch (\Exception $e) {
            error_log("Error getting user booking stats: " . $e->getMessage());
            return [];
        }
    }
}