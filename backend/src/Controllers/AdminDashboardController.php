<?php

declare(strict_types=1);

namespace App\Controllers;

use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class AdminDashboardController {
    
    private PDO $db;

    public function __construct(PDO $db) {
        $this->db = $db;
    }
    
    public function getStats(Request $request, Response $response): Response {
        try {
            // KPIs Financiers
            $revenueToday = $this->getRevenueToday();
            $revenueThisWeek = $this->getRevenueThisWeek();
            $revenueThisMonth = $this->getRevenueThisMonth();
            $commissionsCollected = $this->getCommissionsCollected();
            $transactionsPending = $this->getTransactionsPending();
            
            // Activité Plateforme
            $activeUsers = $this->getActiveUsers();
            $newRegistrationsToday = $this->getNewRegistrationsToday();
            $newRegistrationsThisWeek = $this->getNewRegistrationsThisWeek();
            $publishedTripsToday = $this->getPublishedTripsToday();
            $publishedTripsThisWeek = $this->getPublishedTripsThisWeek();
            $activeBookings = $this->getActiveBookings();
            
            // Santé du Système
            $tripCompletionRate = $this->getTripCompletionRate();
            $disputeRate = $this->getDisputeRate();
            $averageResolutionTime = $this->getAverageResolutionTime();
            
            // Alertes Critiques
            $suspectedFraudCount = $this->getSuspectedFraudCount();
            $urgentDisputesCount = $this->getUrgentDisputesCount();
            $reportedTripsCount = $this->getReportedTripsCount();
            $failedPaymentsCount = $this->getFailedPaymentsCount();
            
            // Données pour graphiques
            $revenueGrowth = $this->getRevenueGrowth();
            $userGrowth = $this->getUserGrowth();
            $popularRoutes = $this->getPopularRoutes();
            $transportDistribution = $this->getTransportDistribution();
            
            $stats = [
                // KPIs Financiers
                'revenue_today' => $revenueToday,
                'revenue_this_week' => $revenueThisWeek,
                'revenue_this_month' => $revenueThisMonth,
                'commissions_collected' => $commissionsCollected,
                'transactions_pending' => $transactionsPending,
                
                // Activité Plateforme
                'active_users' => $activeUsers,
                'new_registrations_today' => $newRegistrationsToday,
                'new_registrations_this_week' => $newRegistrationsThisWeek,
                'published_trips_today' => $publishedTripsToday,
                'published_trips_this_week' => $publishedTripsThisWeek,
                'active_bookings' => $activeBookings,
                
                // Santé du Système
                'trip_completion_rate' => $tripCompletionRate,
                'dispute_rate' => $disputeRate,
                'average_resolution_time_hours' => $averageResolutionTime,
                
                // Alertes Critiques
                'suspected_fraud_count' => $suspectedFraudCount,
                'urgent_disputes_count' => $urgentDisputesCount,
                'reported_trips_count' => $reportedTripsCount,
                'failed_payments_count' => $failedPaymentsCount,
                
                // Données pour graphiques
                'revenue_growth' => $revenueGrowth,
                'user_growth' => $userGrowth,
                'popular_routes' => $popularRoutes,
                'transport_distribution' => $transportDistribution
            ];
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'stats' => $stats
            ]));
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error fetching dashboard stats: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    private function getRevenueToday() {
        try {
            $sql = "SELECT COALESCE(SUM(amount), 0) as total 
                   FROM transactions 
                   WHERE status = 'completed' 
                   AND DATE(created_at) = CURDATE()";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(\PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getRevenueThisWeek() {
        try {
            $sql = "SELECT COALESCE(SUM(amount), 0) as total 
                   FROM transactions 
                   WHERE status = 'completed' 
                   AND YEARWEEK(created_at) = YEARWEEK(NOW())";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(\PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getRevenueThisMonth() {
        try {
            $sql = "SELECT COALESCE(SUM(amount), 0) as total 
                   FROM transactions 
                   WHERE status = 'completed' 
                   AND YEAR(created_at) = YEAR(NOW()) 
                   AND MONTH(created_at) = MONTH(NOW())";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(\PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getCommissionsCollected() {
        try {
            $sql = "SELECT COALESCE(SUM(commission_amount), 0) as total 
                   FROM transactions 
                   WHERE status = 'completed'";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(\PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getTransactionsPending() {
        try {
            $sql = "SELECT COUNT(*) as count FROM transactions WHERE status = 'pending'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getActiveUsers() {
        try {
            $sql = "SELECT COUNT(*) as count FROM users WHERE status = 'active'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getNewRegistrationsToday() {
        try {
            $sql = "SELECT COUNT(*) as count FROM users WHERE DATE(created_at) = CURDATE()";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getNewRegistrationsThisWeek() {
        try {
            $sql = "SELECT COUNT(*) as count FROM users WHERE YEARWEEK(created_at) = YEARWEEK(NOW())";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getPublishedTripsToday() {
        try {
            $sql = "SELECT COUNT(*) as count FROM trips WHERE DATE(created_at) = CURDATE() AND status != 'draft'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getPublishedTripsThisWeek() {
        try {
            $sql = "SELECT COUNT(*) as count FROM trips WHERE YEARWEEK(created_at) = YEARWEEK(NOW()) AND status != 'draft'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getActiveBookings() {
        try {
            $sql = "SELECT COUNT(*) as count FROM bookings WHERE status IN ('pending', 'accepted', 'payment_ready')";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getTripCompletionRate() {
        try {
            $sql = "SELECT 
                       (COUNT(CASE WHEN status = 'completed' THEN 1 END) * 100.0 / COUNT(*)) as rate
                   FROM trips 
                   WHERE status IN ('completed', 'cancelled')";
            $stmt = $this->db->query($sql);
            return round((float)$stmt->fetch(\PDO::FETCH_ASSOC)['rate'], 1);
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getDisputeRate() {
        try {
            $sql = "SELECT 
                       (COUNT(CASE WHEN status = 'disputed' THEN 1 END) * 100.0 / COUNT(*)) as rate
                   FROM bookings";
            $stmt = $this->db->query($sql);
            return round((float)$stmt->fetch(\PDO::FETCH_ASSOC)['rate'], 1);
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getAverageResolutionTime() {
        try {
            $sql = "SELECT AVG(TIMESTAMPDIFF(HOUR, created_at, updated_at)) as avg_hours
                   FROM trip_reports 
                   WHERE status = 'resolved'";
            $stmt = $this->db->query($sql);
            $result = $stmt->fetch(\PDO::FETCH_ASSOC);
            return round((float)($result['avg_hours'] ?? 0), 1);
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getSuspectedFraudCount() {
        try {
            $sql = "SELECT COUNT(*) as count FROM trip_reports WHERE type = 'fraud' AND status = 'pending'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getUrgentDisputesCount() {
        try {
            $sql = "SELECT COUNT(*) as count FROM bookings WHERE status = 'disputed' AND TIMESTAMPDIFF(HOUR, updated_at, NOW()) > 24";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getReportedTripsCount() {
        try {
            $sql = "SELECT COUNT(*) as count FROM trip_reports WHERE status = 'pending'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getFailedPaymentsCount() {
        try {
            $sql = "SELECT COUNT(*) as count FROM transactions WHERE status = 'failed'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(\PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getRevenueGrowth() {
        try {
            $sql = "SELECT 
                       DATE(created_at) as date, 
                       SUM(amount) as amount
                   FROM transactions 
                   WHERE status = 'completed' 
                   AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
                   GROUP BY DATE(created_at)
                   ORDER BY date";
            $stmt = $this->db->query($sql);
            return $stmt->fetchAll(\PDO::FETCH_ASSOC);
        } catch (\Exception $e) {
            return [];
        }
    }
    
    private function getUserGrowth() {
        try {
            $sql = "SELECT 
                       DATE(created_at) as date, 
                       COUNT(*) as count
                   FROM users 
                   WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
                   GROUP BY DATE(created_at)
                   ORDER BY date";
            $stmt = $this->db->query($sql);
            return $stmt->fetchAll(\PDO::FETCH_ASSOC);
        } catch (\Exception $e) {
            return [];
        }
    }
    
    private function getPopularRoutes() {
        try {
            $sql = "SELECT 
                       CONCAT(departure_city, ' → ', arrival_city) as route,
                       COUNT(*) as count,
                       COALESCE(SUM(t.price), 0) as revenue
                   FROM trips t
                   WHERE t.status != 'draft'
                   GROUP BY departure_city, arrival_city
                   ORDER BY count DESC
                   LIMIT 10";
            $stmt = $this->db->query($sql);
            return $stmt->fetchAll(\PDO::FETCH_ASSOC);
        } catch (\Exception $e) {
            return [];
        }
    }
    
    private function getTransportDistribution() {
        try {
            $sql = "SELECT 
                       transport_type as type,
                       COUNT(*) as count,
                       (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM trips WHERE status != 'draft')) as percentage
                   FROM trips 
                   WHERE status != 'draft'
                   GROUP BY transport_type
                   ORDER BY count DESC";
            $stmt = $this->db->query($sql);
            return $stmt->fetchAll(\PDO::FETCH_ASSOC);
        } catch (\Exception $e) {
            return [];
        }
    }
}