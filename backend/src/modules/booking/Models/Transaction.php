<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Models;

use PDO;
use PDOException;
use Exception;

/**
 * Modèle pour les transactions financières et paiements
 */
class Transaction
{
    private PDO $db;

    // Statuts des transactions
    public const STATUS_PENDING = 'pending';
    public const STATUS_PROCESSING = 'processing';
    public const STATUS_SUCCEEDED = 'succeeded';
    public const STATUS_FAILED = 'failed';
    public const STATUS_CANCELLED = 'cancelled';
    public const STATUS_REFUNDED = 'refunded';

    // Méthodes de paiement
    public const METHOD_STRIPE = 'stripe';
    public const METHOD_PAYPAL = 'paypal';
    public const METHOD_BANK_TRANSFER = 'bank_transfer';

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    /**
     * Créer une nouvelle transaction
     */
    public function create(array $data): array
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO transactions (
                    booking_id, stripe_payment_intent_id, stripe_payment_method_id,
                    amount, commission, receiver_amount, currency, 
                    status, payment_method
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            
            $stmt->execute([
                $data['booking_id'],
                $data['stripe_payment_intent_id'] ?? null,
                $data['stripe_payment_method_id'] ?? null,
                $data['amount'],
                $data['commission'],
                $data['receiver_amount'],
                $data['currency'] ?? 'CAD',
                $data['status'] ?? self::STATUS_PENDING,
                $data['payment_method'] ?? self::METHOD_STRIPE
            ]);

            $transactionId = $this->db->lastInsertId();
            return $this->getById($transactionId);
            
        } catch (PDOException $e) {
            throw new Exception('Erreur lors de la création de la transaction: ' . $e->getMessage());
        }
    }

    /**
     * Récupérer une transaction par ID
     */
    public function getById(int $transactionId): array
    {
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   b.package_description, b.weight_kg, b.final_price,
                   b.sender_id, b.receiver_id,
                   sender.email as sender_email,
                   receiver.email as receiver_email
            FROM transactions t
            LEFT JOIN bookings b ON t.booking_id = b.id
            LEFT JOIN users sender ON b.sender_id = sender.id
            LEFT JOIN users receiver ON b.receiver_id = receiver.id
            WHERE t.id = ?
        ");
        
        $stmt->execute([$transactionId]);
        $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$transaction) {
            throw new Exception('Transaction non trouvée');
        }
        
        return $transaction;
    }

    /**
     * Récupérer une transaction par UUID
     */
    public function getByUuid(string $uuid): array
    {
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   b.package_description, b.weight_kg, b.final_price,
                   b.sender_id, b.receiver_id
            FROM transactions t
            LEFT JOIN bookings b ON t.booking_id = b.id
            WHERE t.uuid = ?
        ");
        
        $stmt->execute([$uuid]);
        $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$transaction) {
            throw new Exception('Transaction non trouvée');
        }
        
        return $transaction;
    }

    /**
     * Récupérer les transactions d'une réservation
     */
    public function getByBookingId(int $bookingId): array
    {
        $stmt = $this->db->prepare("
            SELECT * FROM transactions 
            WHERE booking_id = ?
            ORDER BY created_at DESC
        ");
        
        $stmt->execute([$bookingId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Récupérer les transactions d'un utilisateur
     */
    public function getUserTransactions(int $userId): array
    {
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   b.package_description, b.weight_kg,
                   b.sender_id, b.receiver_id,
                   CASE 
                       WHEN b.sender_id = ? THEN 'sent'
                       WHEN b.receiver_id = ? THEN 'received'
                       ELSE 'unknown'
                   END as transaction_type
            FROM transactions t
            LEFT JOIN bookings b ON t.booking_id = b.id
            WHERE b.sender_id = ? OR b.receiver_id = ?
            ORDER BY t.created_at DESC
        ");
        
        $stmt->execute([$userId, $userId, $userId, $userId]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /**
     * Mettre à jour le statut d'une transaction
     */
    public function updateStatus(int $transactionId, string $status): bool
    {
        $validStatuses = [
            self::STATUS_PENDING, self::STATUS_PROCESSING, self::STATUS_SUCCEEDED,
            self::STATUS_FAILED, self::STATUS_CANCELLED, self::STATUS_REFUNDED
        ];
        
        if (!in_array($status, $validStatuses)) {
            throw new Exception('Statut invalide: ' . $status);
        }
        
        $updateFields = ['status = ?', 'updated_at = CURRENT_TIMESTAMP'];
        $params = [$status, $transactionId];
        
        // Marquer comme traité si succès
        if ($status === self::STATUS_SUCCEEDED) {
            $updateFields[] = 'processed_at = CURRENT_TIMESTAMP';
        }
        
        $stmt = $this->db->prepare("
            UPDATE transactions 
            SET " . implode(', ', $updateFields) . "
            WHERE id = ?
        ");
        
        return $stmt->execute($params);
    }

    /**
     * Mettre à jour les informations Stripe
     */
    public function updateStripeInfo(int $transactionId, array $stripeData): bool
    {
        try {
            $stmt = $this->db->prepare("
                UPDATE transactions 
                SET stripe_payment_intent_id = ?, 
                    stripe_payment_method_id = ?,
                    status = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ?
            ");
            
            return $stmt->execute([
                $stripeData['payment_intent_id'] ?? null,
                $stripeData['payment_method_id'] ?? null,
                $stripeData['status'] ?? self::STATUS_PROCESSING,
                $transactionId
            ]);
            
        } catch (PDOException $e) {
            throw new Exception('Erreur lors de la mise à jour Stripe: ' . $e->getMessage());
        }
    }

    /**
     * Créer un compte escrow pour la transaction
     */
    public function createEscrow(int $transactionId, float $amount, string $holdReason = 'delivery_confirmation'): int
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO escrow_accounts (transaction_id, amount_held, hold_reason)
                VALUES (?, ?, ?)
            ");
            
            $stmt->execute([$transactionId, $amount, $holdReason]);
            return (int)$this->db->lastInsertId();
            
        } catch (PDOException $e) {
            throw new Exception('Erreur lors de la création de l\'escrow: ' . $e->getMessage());
        }
    }

    /**
     * Libérer les fonds d'escrow
     */
    public function releaseEscrow(int $transactionId, float $amountToRelease, ?string $notes = null): bool
    {
        try {
            $this->db->beginTransaction();
            
            // Récupérer l'escrow account
            $stmt = $this->db->prepare("
                SELECT * FROM escrow_accounts 
                WHERE transaction_id = ? AND status IN ('holding', 'partial_release')
            ");
            $stmt->execute([$transactionId]);
            $escrow = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$escrow) {
                throw new Exception('Compte escrow non trouvé ou déjà libéré');
            }
            
            $newAmountReleased = $escrow['amount_released'] + $amountToRelease;
            $remainingAmount = $escrow['amount_held'] - $newAmountReleased;
            
            if ($remainingAmount < 0) {
                throw new Exception('Montant à libérer supérieur au montant retenu');
            }
            
            // Déterminer le nouveau statut
            $newStatus = $remainingAmount > 0 ? 'partial_release' : 'fully_released';
            
            // Mettre à jour l'escrow
            $stmt = $this->db->prepare("
                UPDATE escrow_accounts 
                SET amount_released = ?, 
                    status = ?,
                    released_at = CURRENT_TIMESTAMP,
                    release_notes = ?
                WHERE transaction_id = ?
            ");
            
            $stmt->execute([$newAmountReleased, $newStatus, $notes, $transactionId]);
            
            $this->db->commit();
            return true;
            
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }
    }

    /**
     * Obtenir l'état de l'escrow pour une transaction
     */
    public function getEscrowStatus(int $transactionId): ?array
    {
        $stmt = $this->db->prepare("
            SELECT * FROM escrow_accounts 
            WHERE transaction_id = ?
            ORDER BY held_at DESC
            LIMIT 1
        ");
        
        $stmt->execute([$transactionId]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    /**
     * Rembourser une transaction
     */
    public function refund(int $transactionId, float $refundAmount, string $reason): bool
    {
        try {
            $this->db->beginTransaction();
            
            // Marquer la transaction comme remboursée
            $this->updateStatus($transactionId, self::STATUS_REFUNDED);
            
            // TODO: Intégrer avec Stripe pour le remboursement réel
            
            $this->db->commit();
            return true;
            
        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Erreur lors du remboursement: ' . $e->getMessage());
        }
    }

    /**
     * Calculer les revenus pour une période
     */
    public function getRevenueStats(string $startDate, string $endDate): array
    {
        $stmt = $this->db->prepare("
            SELECT 
                COUNT(*) as total_transactions,
                SUM(amount) as total_amount,
                SUM(commission) as total_commission,
                SUM(receiver_amount) as total_to_receivers,
                AVG(amount) as average_transaction_amount,
                SUM(CASE WHEN status = 'succeeded' THEN 1 ELSE 0 END) as successful_transactions,
                SUM(CASE WHEN status = 'succeeded' THEN commission ELSE 0 END) as successful_commission
            FROM transactions 
            WHERE created_at BETWEEN ? AND ?
        ");
        
        $stmt->execute([$startDate, $endDate]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
    }

    /**
     * Obtenir les transactions en attente de traitement
     */
    public function getPendingTransactions(): array
    {
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   b.package_description, b.sender_id, b.receiver_id
            FROM transactions t
            LEFT JOIN bookings b ON t.booking_id = b.id
            WHERE t.status IN ('pending', 'processing')
            ORDER BY t.created_at ASC
        ");
        
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}