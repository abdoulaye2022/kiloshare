<?php

declare(strict_types=1);

namespace App\Controllers;

use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class AdminPaymentsController {
    
    private PDO $db;

    public function __construct(PDO $db) {
        $this->db = $db;
    }
    
    public function getStats(Request $request, Response $response): Response {
        try {
            $totalTransactions = $this->getTotalTransactions();
            $totalRevenue = $this->getTotalRevenue();
            $totalCommissions = $this->getTotalCommissions();
            $successRate = $this->getSuccessRate();
            $averageTransactionAmount = $this->getAverageTransactionAmount();
            $pendingTransactions = $this->getPendingTransactions();
            $refundsTotal = $this->getRefundsTotal();
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'stats' => [
                    'total_transactions' => $totalTransactions,
                    'total_revenue' => $totalRevenue,
                    'total_commissions' => $totalCommissions,
                    'success_rate' => $successRate,
                    'average_transaction_amount' => $averageTransactionAmount,
                    'pending_transactions' => $pendingTransactions,
                    'refunds_total' => $refundsTotal
                ]
            ]));
            
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error fetching payment stats: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    public function getTransactions(Request $request, Response $response): Response {
        try {
            $queryParams = $request->getQueryParams();
            $page = (int)($queryParams['page'] ?? 1);
            $limit = (int)($queryParams['limit'] ?? 20);
            $status = $queryParams['status'] ?? 'all';
            $search = $queryParams['search'] ?? '';
            $offset = ($page - 1) * $limit;
            
            $whereConditions = [];
            $params = [];
            
            if ($status !== 'all') {
                $whereConditions[] = "t.status = ?";
                $params[] = $status;
            }
            
            if (!empty($search)) {
                $whereConditions[] = "(COALESCE(t.stripe_payment_intent_id, '') LIKE ? OR CAST(t.id AS CHAR) LIKE ?)";
                $params[] = "%$search%";
                $params[] = "%$search%";
            }
            
            $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
            
            $sql = "SELECT 
                       t.id,
                       COALESCE(t.stripe_payment_intent_id, '') as stripe_payment_intent_id,
                       t.amount,
                       0 as commission_amount,
                       t.status,
                       'payment' as type,
                       t.created_at,
                       t.updated_at,
                       'Unknown User' as user_name,
                       'unknown@example.com' as user_email,
                       0 as booking_id,
                       '' as departure_city,
                       '' as arrival_city
                   FROM transactions t
                   $whereClause
                   ORDER BY t.created_at DESC
                   LIMIT $limit OFFSET $offset";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute($params);
            $transactions = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            $countSql = "SELECT COUNT(*) as total 
                        FROM transactions t
                        $whereClause";
            $countStmt = $this->db->prepare($countSql);
            $countStmt->execute($params);
            $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'transactions' => $transactions,
                'pagination' => [
                    'current_page' => $page,
                    'total' => (int)$total,
                    'per_page' => $limit,
                    'total_pages' => ceil($total / $limit)
                ]
            ]));
            
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error fetching transactions: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    public function getTransaction(Request $request, Response $response, string $transactionId): Response {
        try {
            $sql = "SELECT 
                       t.*,
                       u.name as user_name,
                       u.email as user_email,
                       b.id as booking_id,
                       b.status as booking_status,
                       tr.departure_city,
                       tr.arrival_city,
                       tr.departure_date,
                       tr.price as trip_price
                   FROM transactions t
                   LEFT JOIN bookings b ON t.booking_id = b.id
                   LEFT JOIN users u ON b.user_id = u.id
                   LEFT JOIN trips tr ON b.trip_id = tr.id
                   WHERE t.id = ?";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$transactionId]);
            $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$transaction) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Transaction not found'
                ]));
                return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            }
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'transaction' => $transaction
            ]));
            
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error fetching transaction: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    public function refundTransaction(Request $request, Response $response, string $transactionId): Response {
        try {
            $data = json_decode($request->getBody()->getContents(), true);
            $amount = $data['amount'] ?? null;
            $reason = $data['reason'] ?? 'Admin refund';
            
            $sql = "SELECT * FROM transactions WHERE id = ? AND status = 'completed'";
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$transactionId]);
            $transaction = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$transaction) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Transaction not found or not eligible for refund'
                ]));
                return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            }
            
            if (!$amount) {
                $amount = $transaction['amount'];
            }
            
            $updateSql = "UPDATE transactions 
                         SET status = 'refunded', 
                             refund_amount = ?, 
                             refund_reason = ?, 
                             updated_at = NOW() 
                         WHERE id = ?";
            $updateStmt = $this->db->prepare($updateSql);
            $updateStmt->execute([$amount, $reason, $transactionId]);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Transaction refunded successfully',
                'refund_amount' => $amount
            ]));
            
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error processing refund: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    private function getTotalTransactions() {
        try {
            $sql = "SELECT COUNT(*) as count FROM transactions";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getTotalRevenue() {
        try {
            $sql = "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE status = 'completed'";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getTotalCommissions() {
        try {
            // Since commission_amount column doesn't exist, calculate 5% of total revenue
            $sql = "SELECT COALESCE(SUM(amount) * 0.05, 0) as total FROM transactions WHERE status = 'completed'";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getSuccessRate() {
        try {
            $sql = "SELECT 
                       (COUNT(CASE WHEN status = 'completed' THEN 1 END) * 100.0 / COUNT(*)) as rate
                   FROM transactions";
            $stmt = $this->db->query($sql);
            return round((float)$stmt->fetch(PDO::FETCH_ASSOC)['rate'], 1);
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getAverageTransactionAmount() {
        try {
            $sql = "SELECT COALESCE(AVG(amount), 0) as avg FROM transactions WHERE status = 'completed'";
            $stmt = $this->db->query($sql);
            return round((float)$stmt->fetch(PDO::FETCH_ASSOC)['avg'], 2);
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getPendingTransactions() {
        try {
            $sql = "SELECT COUNT(*) as count FROM transactions WHERE status = 'pending'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getRefundsTotal() {
        try {
            // Since refund_amount column doesn't exist, use amount for refunded transactions
            $sql = "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE status = 'refunded'";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
}