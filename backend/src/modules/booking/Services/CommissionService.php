<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Services;

use PDO;
use Exception;

class CommissionService
{
    private PDO $db;
    
    // Taux de commission par défaut (15%)
    private float $defaultCommissionRate = 15.0;
    
    // Seuils pour différents taux de commission
    private array $commissionTiers = [
        'standard' => ['min' => 0, 'max' => 100, 'rate' => 15.0],
        'premium' => ['min' => 100, 'max' => 500, 'rate' => 12.5],
        'vip' => ['min' => 500, 'max' => PHP_FLOAT_MAX, 'rate' => 10.0]
    ];

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    /**
     * Calculer les frais pour une transaction
     */
    public function calculateFees(float $baseAmount, ?int $userId = null): array
    {
        $commissionRate = $this->getCommissionRate($baseAmount, $userId);
        $commission = $baseAmount * ($commissionRate / 100);
        $totalAmount = $baseAmount + $commission;
        $receiverAmount = $baseAmount;

        return [
            'base_amount' => round($baseAmount, 2),
            'commission_rate' => $commissionRate,
            'commission_amount' => round($commission, 2),
            'total_amount' => round($totalAmount, 2),
            'receiver_amount' => round($receiverAmount, 2),
            'processing_fee' => 0, // Pas de frais de traitement supplémentaires pour l'instant
            'breakdown' => [
                'service_fee' => round($commission * 0.8, 2), // 80% pour KiloShare
                'payment_processing' => round($commission * 0.2, 2) // 20% pour frais Stripe
            ]
        ];
    }

    /**
     * Obtenir le taux de commission applicable
     */
    public function getCommissionRate(float $amount, ?int $userId = null): float
    {
        // Appliquer des taux différenciés selon le montant
        foreach ($this->commissionTiers as $tier => $config) {
            if ($amount >= $config['min'] && $amount < $config['max']) {
                $rate = $config['rate'];
                break;
            }
        }

        // Appliquer des réductions pour utilisateurs VIP (si implémenté)
        if ($userId !== null) {
            $userDiscount = $this->getUserCommissionDiscount($userId);
            $rate = max(5.0, $rate - $userDiscount); // Minimum 5%
        }

        return $rate ?? $this->defaultCommissionRate;
    }

    /**
     * Obtenir la réduction de commission pour un utilisateur
     */
    private function getUserCommissionDiscount(int $userId): float
    {
        try {
            // Calculer la réduction basée sur l'historique de l'utilisateur
            $stmt = $this->db->prepare("
                SELECT 
                    COUNT(*) as completed_bookings,
                    SUM(final_price) as total_volume
                FROM bookings 
                WHERE (sender_id = ? OR receiver_id = ?) 
                AND status = 'completed'
                AND created_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
            ");
            
            $stmt->execute([$userId, $userId]);
            $stats = $stmt->fetch(PDO::FETCH_ASSOC);
            
            $completedBookings = (int)$stats['completed_bookings'];
            $totalVolume = (float)($stats['total_volume'] ?? 0);
            
            $discount = 0;
            
            // Réduction selon le nombre de réservations complétées
            if ($completedBookings >= 50) {
                $discount += 3.0; // -3% pour 50+ réservations
            } elseif ($completedBookings >= 20) {
                $discount += 2.0; // -2% pour 20+ réservations
            } elseif ($completedBookings >= 10) {
                $discount += 1.0; // -1% pour 10+ réservations
            }
            
            // Réduction selon le volume total
            if ($totalVolume >= 5000) {
                $discount += 2.5; // -2.5% pour 5000$+ de volume
            } elseif ($totalVolume >= 2000) {
                $discount += 1.5; // -1.5% pour 2000$+ de volume
            } elseif ($totalVolume >= 1000) {
                $discount += 1.0; // -1% pour 1000$+ de volume
            }
            
            return min(5.0, $discount); // Maximum 5% de réduction
            
        } catch (Exception $e) {
            error_log("Erreur CommissionService::getUserCommissionDiscount: " . $e->getMessage());
            return 0;
        }
    }

    /**
     * Calculer la commission pour une négociation
     */
    public function calculateNegotiationFees(float $originalAmount, float $negotiatedAmount, ?int $userId = null): array
    {
        $originalFees = $this->calculateFees($originalAmount, $userId);
        $negotiatedFees = $this->calculateFees($negotiatedAmount, $userId);
        
        return [
            'original' => $originalFees,
            'negotiated' => $negotiatedFees,
            'savings' => [
                'amount' => round($originalFees['total_amount'] - $negotiatedFees['total_amount'], 2),
                'commission' => round($originalFees['commission_amount'] - $negotiatedFees['commission_amount'], 2)
            ]
        ];
    }

    /**
     * Obtenir les statistiques de revenus
     */
    public function getRevenueStats(string $startDate, string $endDate): array
    {
        try {
            $stmt = $this->db->prepare("
                SELECT 
                    COUNT(*) as total_transactions,
                    COUNT(CASE WHEN t.status = 'succeeded' THEN 1 END) as successful_transactions,
                    SUM(t.amount) as gross_revenue,
                    SUM(t.commission) as commission_revenue,
                    SUM(t.receiver_amount) as paid_to_users,
                    AVG(t.commission) as avg_commission,
                    MIN(t.commission) as min_commission,
                    MAX(t.commission) as max_commission
                FROM transactions t
                WHERE t.created_at BETWEEN ? AND ?
            ");
            
            $stmt->execute([$startDate, $endDate]);
            $stats = $stmt->fetch(PDO::FETCH_ASSOC);
            
            // Calculer les métriques dérivées
            $successRate = $stats['total_transactions'] > 0 
                ? ($stats['successful_transactions'] / $stats['total_transactions']) * 100 
                : 0;
                
            $avgCommissionRate = $stats['gross_revenue'] > 0 
                ? ($stats['commission_revenue'] / ($stats['gross_revenue'] - $stats['commission_revenue'])) * 100 
                : 0;
            
            return [
                'period' => ['start' => $startDate, 'end' => $endDate],
                'transactions' => [
                    'total' => (int)$stats['total_transactions'],
                    'successful' => (int)$stats['successful_transactions'],
                    'success_rate' => round($successRate, 2)
                ],
                'revenue' => [
                    'gross' => round((float)$stats['gross_revenue'], 2),
                    'commission' => round((float)$stats['commission_revenue'], 2),
                    'paid_to_users' => round((float)$stats['paid_to_users'], 2)
                ],
                'commission_stats' => [
                    'average' => round((float)$stats['avg_commission'], 2),
                    'average_rate' => round($avgCommissionRate, 2),
                    'minimum' => round((float)$stats['min_commission'], 2),
                    'maximum' => round((float)$stats['max_commission'], 2)
                ]
            ];
            
        } catch (Exception $e) {
            error_log("Erreur CommissionService::getRevenueStats: " . $e->getMessage());
            throw new Exception('Erreur lors du calcul des statistiques de revenus');
        }
    }

    /**
     * Obtenir les commissions par palier
     */
    public function getCommissionTiers(): array
    {
        return $this->commissionTiers;
    }

    /**
     * Simuler les frais pour différents montants
     */
    public function simulateFees(array $amounts, ?int $userId = null): array
    {
        $simulations = [];
        
        foreach ($amounts as $amount) {
            $fees = $this->calculateFees($amount, $userId);
            $simulations[] = [
                'amount' => $amount,
                'fees' => $fees
            ];
        }
        
        return $simulations;
    }

    /**
     * Valider un montant de commission
     */
    public function validateCommission(float $baseAmount, float $commissionAmount): bool
    {
        $expectedFees = $this->calculateFees($baseAmount);
        $tolerance = 0.01; // Tolérance de 1 centime
        
        return abs($expectedFees['commission_amount'] - $commissionAmount) <= $tolerance;
    }

    /**
     * Obtenir le profil de commission d'un utilisateur
     */
    public function getUserCommissionProfile(int $userId): array
    {
        try {
            // Récupérer les statistiques utilisateur
            $stmt = $this->db->prepare("
                SELECT 
                    COUNT(*) as total_bookings,
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_bookings,
                    SUM(final_price) as total_volume,
                    AVG(final_price) as avg_transaction_size,
                    SUM(commission_amount) as total_commission_paid
                FROM bookings 
                WHERE (sender_id = ? OR receiver_id = ?) 
                AND created_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
            ");
            
            $stmt->execute([$userId, $userId]);
            $stats = $stmt->fetch(PDO::FETCH_ASSOC);
            
            $discount = $this->getUserCommissionDiscount($userId);
            $currentRate = $this->getCommissionRate(100, $userId); // Taux pour 100$ comme référence
            
            return [
                'user_id' => $userId,
                'current_commission_rate' => $currentRate,
                'discount_applied' => $discount,
                'statistics' => [
                    'total_bookings' => (int)$stats['total_bookings'],
                    'completed_bookings' => (int)$stats['completed_bookings'],
                    'total_volume' => round((float)$stats['total_volume'], 2),
                    'average_transaction' => round((float)$stats['avg_transaction_size'], 2),
                    'total_commission_paid' => round((float)$stats['total_commission_paid'], 2)
                ],
                'next_tier' => $this->getNextCommissionTier($userId),
                'sample_rates' => [
                    '50' => $this->getCommissionRate(50, $userId),
                    '100' => $this->getCommissionRate(100, $userId),
                    '250' => $this->getCommissionRate(250, $userId),
                    '500' => $this->getCommissionRate(500, $userId)
                ]
            ];
            
        } catch (Exception $e) {
            error_log("Erreur CommissionService::getUserCommissionProfile: " . $e->getMessage());
            throw new Exception('Erreur lors de la récupération du profil de commission');
        }
    }

    /**
     * Obtenir les informations sur le prochain palier de commission
     */
    private function getNextCommissionTier(int $userId): ?array
    {
        try {
            $stmt = $this->db->prepare("
                SELECT 
                    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_bookings,
                    SUM(CASE WHEN status = 'completed' THEN final_price ELSE 0 END) as total_volume
                FROM bookings 
                WHERE (sender_id = ? OR receiver_id = ?) 
                AND created_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
            ");
            
            $stmt->execute([$userId, $userId]);
            $stats = $stmt->fetch(PDO::FETCH_ASSOC);
            
            $completedBookings = (int)$stats['completed_bookings'];
            $totalVolume = (float)$stats['total_volume'];
            
            // Déterminer le prochain palier
            if ($completedBookings < 10) {
                return [
                    'target' => '10 réservations complétées',
                    'current' => $completedBookings,
                    'remaining' => 10 - $completedBookings,
                    'benefit' => 'Réduction de 1% sur les commissions'
                ];
            } elseif ($completedBookings < 20) {
                return [
                    'target' => '20 réservations complétées',
                    'current' => $completedBookings,
                    'remaining' => 20 - $completedBookings,
                    'benefit' => 'Réduction de 2% sur les commissions'
                ];
            } elseif ($totalVolume < 1000) {
                return [
                    'target' => '1000$ de volume total',
                    'current' => $totalVolume,
                    'remaining' => 1000 - $totalVolume,
                    'benefit' => 'Réduction supplémentaire de 1% sur les commissions'
                ];
            }
            
            return null; // Utilisateur au niveau maximum
            
        } catch (Exception $e) {
            error_log("Erreur CommissionService::getNextCommissionTier: " . $e->getMessage());
            return null;
        }
    }
}