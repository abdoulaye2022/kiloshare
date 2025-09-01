<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Models;

use PDO;
use PDOException;
use DateTime;
use Exception;

/**
 * Modèle pour les réservations de transport de colis
 */
class Booking
{
    private PDO $db;

    // Statuts possibles pour une réservation
    public const STATUS_PENDING = 'pending';
    public const STATUS_ACCEPTED = 'accepted';
    public const STATUS_REJECTED = 'rejected';
    public const STATUS_PAYMENT_PENDING = 'payment_pending';
    public const STATUS_PAID = 'paid';
    public const STATUS_IN_TRANSIT = 'in_transit';
    public const STATUS_DELIVERED = 'delivered';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_CANCELLED = 'cancelled';
    public const STATUS_DISPUTED = 'disputed';

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    /**
     * Créer une nouvelle réservation
     */
    public function create(array $data): array
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO bookings (
                    trip_id, sender_id, receiver_id, package_description, 
                    weight_kg, dimensions_cm, proposed_price, pickup_address, 
                    delivery_address, special_instructions, expires_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            
            $expiresAt = isset($data['expires_at']) 
                ? $data['expires_at'] 
                : date('Y-m-d H:i:s', strtotime('+7 days')); // Expire dans 7 jours par défaut
            
            $stmt->execute([
                $data['trip_id'],
                $data['sender_id'],
                $data['receiver_id'],
                $data['package_description'],
                $data['weight_kg'],
                $data['dimensions_cm'] ?? null,
                $data['proposed_price'],
                $data['pickup_address'] ?? null,
                $data['delivery_address'] ?? null,
                $data['special_instructions'] ?? null,
                $expiresAt
            ]);

            $bookingId = (int) $this->db->lastInsertId();
            return $this->getById($bookingId);
            
        } catch (PDOException $e) {
            throw new Exception('Erreur lors de la création de la réservation: ' . $e->getMessage());
        }
    }

    /**
     * Récupérer une réservation par ID
     */
    public function getById(int $bookingId): array
    {
        $stmt = $this->db->prepare("
            SELECT b.*, 
                   t.departure_city, t.arrival_city, t.departure_date,
                   sender.email as sender_email, sender.first_name as sender_first_name,
                   receiver.email as receiver_email, receiver.first_name as receiver_first_name
            FROM bookings b
            LEFT JOIN trips t ON b.trip_id = t.id
            LEFT JOIN users sender ON b.sender_id = sender.id
            LEFT JOIN users receiver ON b.receiver_id = receiver.id
            WHERE b.id = ?
        ");
        
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$booking) {
            throw new Exception('Réservation non trouvée');
        }
        
        // Ajouter les négociations
        $booking['negotiations'] = $this->getNegotiations($bookingId);
        
        // Ajouter les photos
        $booking['photos'] = $this->getPackagePhotos($bookingId);
        
        return $booking;
    }

    /**
     * Récupérer une réservation par UUID
     */
    public function getByUuid(string $uuid): array
    {
        $stmt = $this->db->prepare("
            SELECT b.*, 
                   t.departure_city, t.arrival_city, t.departure_date,
                   sender.email as sender_email, sender.first_name as sender_first_name,
                   receiver.email as receiver_email, receiver.first_name as receiver_first_name
            FROM bookings b
            LEFT JOIN trips t ON b.trip_id = t.id
            LEFT JOIN users sender ON b.sender_id = sender.id
            LEFT JOIN users receiver ON b.receiver_id = receiver.id
            WHERE b.uuid = ?
        ");
        
        $stmt->execute([$uuid]);
        $booking = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$booking) {
            throw new Exception('Réservation non trouvée');
        }
        
        $booking['negotiations'] = $this->getNegotiations($booking['id']);
        $booking['photos'] = $this->getPackagePhotos($booking['id']);
        
        return $booking;
    }

    /**
     * Récupérer les réservations d'un utilisateur
     */
    public function getUserBookings(int $userId, string $role = 'all'): array
    {
        $whereClause = match($role) {
            'sender' => 'b.sender_id = ?',
            'receiver' => 'b.receiver_id = ?',
            default => '(b.sender_id = ? OR b.receiver_id = ?)'
        };
        
        $params = $role === 'all' ? [$userId, $userId] : [$userId];
        
        $stmt = $this->db->prepare("
            SELECT b.*, 
                   t.departure_city, t.arrival_city, t.departure_date,
                   sender.email as sender_email, sender.first_name as sender_first_name,
                   receiver.email as receiver_email, receiver.first_name as receiver_first_name
            FROM bookings b
            LEFT JOIN trips t ON b.trip_id = t.id
            LEFT JOIN users sender ON b.sender_id = sender.id
            LEFT JOIN users receiver ON b.receiver_id = receiver.id
            WHERE {$whereClause}
            ORDER BY b.created_at DESC
        ");
        
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Récupérer les réservations pour un voyage
     */
    public function getTripBookings(int $tripId): array
    {
        $stmt = $this->db->prepare("
            SELECT b.*, 
                   sender.email as sender_email, sender.first_name as sender_first_name,
                   receiver.email as receiver_email, receiver.first_name as receiver_first_name
            FROM bookings b
            LEFT JOIN users sender ON b.sender_id = sender.id
            LEFT JOIN users receiver ON b.receiver_id = receiver.id
            WHERE b.trip_id = ?
            ORDER BY b.created_at DESC
        ");
        
        $stmt->execute([$tripId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Mettre à jour le statut d'une réservation
     */
    public function updateStatus(int $bookingId, string $status): bool
    {
        $validStatuses = [
            self::STATUS_PENDING, self::STATUS_ACCEPTED, self::STATUS_REJECTED,
            self::STATUS_PAYMENT_PENDING, self::STATUS_PAID, self::STATUS_IN_TRANSIT,
            self::STATUS_DELIVERED, self::STATUS_COMPLETED, self::STATUS_CANCELLED,
            self::STATUS_DISPUTED
        ];
        
        if (!in_array($status, $validStatuses)) {
            throw new Exception('Statut invalide: ' . $status);
        }
        
        $stmt = $this->db->prepare("
            UPDATE bookings 
            SET status = ?, updated_at = CURRENT_TIMESTAMP 
            WHERE id = ?
        ");
        
        return $stmt->execute([$status, $bookingId]);
    }

    /**
     * Accepter une réservation
     */
    public function accept(int $bookingId, ?float $finalPrice = null): bool
    {
        try {
            $this->db->beginTransaction();
            
            // Mettre à jour le statut et le prix final si fourni
            $updateFields = 'status = ?, updated_at = CURRENT_TIMESTAMP';
            $params = [self::STATUS_ACCEPTED, $bookingId];
            
            if ($finalPrice !== null) {
                $updateFields .= ', final_price = ?, commission_amount = final_price * (commission_rate / 100)';
                array_splice($params, 1, 0, $finalPrice);
            }
            
            $stmt = $this->db->prepare("UPDATE bookings SET {$updateFields} WHERE id = ?");
            $stmt->execute($params);
            
            $this->db->commit();
            return true;
            
        } catch (PDOException $e) {
            $this->db->rollBack();
            throw new Exception('Erreur lors de l\'acceptation: ' . $e->getMessage());
        }
    }

    /**
     * Rejeter une réservation
     */
    public function reject(int $bookingId): bool
    {
        return $this->updateStatus($bookingId, self::STATUS_REJECTED);
    }

    /**
     * Ajouter une négociation de prix
     */
    public function addNegotiation(int $bookingId, int $proposedBy, float $amount, ?string $message = null): int
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO booking_negotiations (booking_id, proposed_by, amount, message)
                VALUES (?, ?, ?, ?)
            ");
            
            $stmt->execute([$bookingId, $proposedBy, $amount, $message]);
            return (int)$this->db->lastInsertId();
            
        } catch (PDOException $e) {
            throw new Exception('Erreur lors de l\'ajout de la négociation: ' . $e->getMessage());
        }
    }

    /**
     * Récupérer les négociations d'une réservation
     */
    public function getNegotiations(int $bookingId): array
    {
        $stmt = $this->db->prepare("
            SELECT n.*, u.first_name, u.email
            FROM booking_negotiations n
            LEFT JOIN users u ON n.proposed_by = u.id
            WHERE n.booking_id = ?
            ORDER BY n.created_at ASC
        ");
        
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Ajouter une photo de colis
     */
    public function addPackagePhoto(int $bookingId, int $uploadedBy, string $photoUrl, string $photoType = 'package', ?string $cloudinaryId = null): int
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO booking_package_photos (booking_id, uploaded_by, photo_url, photo_type, cloudinary_public_id)
                VALUES (?, ?, ?, ?, ?)
            ");
            
            $stmt->execute([$bookingId, $uploadedBy, $photoUrl, $photoType, $cloudinaryId]);
            return (int)$this->db->lastInsertId();
            
        } catch (PDOException $e) {
            throw new Exception('Erreur lors de l\'ajout de la photo: ' . $e->getMessage());
        }
    }

    /**
     * Récupérer les photos d'un colis
     */
    public function getPackagePhotos(int $bookingId): array
    {
        $stmt = $this->db->prepare("
            SELECT p.*, u.first_name as uploaded_by_name
            FROM booking_package_photos p
            LEFT JOIN users u ON p.uploaded_by = u.id
            WHERE p.booking_id = ?
            ORDER BY p.uploaded_at ASC
        ");
        
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Calculer le montant total avec commission
     */
    public function calculateTotalWithCommission(float $basePrice, float $commissionRate = 15.0): array
    {
        $commission = $basePrice * ($commissionRate / 100);
        $total = $basePrice + $commission;
        
        return [
            'base_price' => $basePrice,
            'commission_rate' => $commissionRate,
            'commission_amount' => round($commission, 2),
            'total_amount' => round($total, 2),
            'receiver_amount' => $basePrice
        ];
    }

    /**
     * Vérifier si une réservation a expiré
     */
    public function isExpired(int $bookingId): bool
    {
        $stmt = $this->db->prepare("
            SELECT expires_at FROM bookings WHERE id = ? AND expires_at < NOW()
        ");
        
        $stmt->execute([$bookingId]);
        return $stmt->rowCount() > 0;
    }

    /**
     * Marquer les réservations expirées
     */
    public function markExpiredBookings(): int
    {
        $stmt = $this->db->prepare("
            UPDATE bookings 
            SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP 
            WHERE status = 'pending' AND expires_at < NOW()
        ");
        
        $stmt->execute();
        return $stmt->rowCount();
    }

    /**
     * Obtenir les statistiques des réservations
     */
    public function getBookingStats(int $userId): array
    {
        $stmt = $this->db->prepare("
            SELECT 
                COUNT(*) as total_bookings,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_bookings,
                SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_bookings,
                AVG(final_price) as average_price,
                SUM(commission_amount) as total_commission_paid
            FROM bookings 
            WHERE sender_id = ? OR receiver_id = ?
        ");
        
        $stmt->execute([$userId, $userId]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    }
}