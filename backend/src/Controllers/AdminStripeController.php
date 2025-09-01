<?php

declare(strict_types=1);

namespace App\Controllers;

use PDO;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class AdminStripeController {
    
    private PDO $db;

    public function __construct(PDO $db) {
        $this->db = $db;
    }
    
    public function getConnectedAccounts(Request $request, Response $response): Response {
        try {
            $queryParams = $request->getQueryParams();
            $page = (int)($queryParams['page'] ?? 1);
            $limit = (int)($queryParams['limit'] ?? 20);
            $status = $queryParams['status'] ?? 'all';
            $search = $queryParams['search'] ?? '';
            $offset = ($page - 1) * $limit;
            
            $whereConditions = [];
            $params = [];
            
            // Status filtering for real Stripe accounts
            if ($status !== 'all') {
                $whereConditions[] = "usa.status = ?";
                $params[] = $status;
            }
            
            if (!empty($search)) {
                $whereConditions[] = "(COALESCE(u.first_name, '') LIKE ? OR COALESCE(u.last_name, '') LIKE ? OR u.email LIKE ?)";
                $params[] = "%$search%";
                $params[] = "%$search%";
                $params[] = "%$search%";
            }
            
            $whereClause = !empty($whereConditions) ? 'WHERE ' . implode(' AND ', $whereConditions) : '';
            
            // Get only users who actually have Stripe accounts
            $sql = "SELECT 
                       u.id,
                       COALESCE(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')), u.email) as user_name,
                       u.email as user_email,
                       'active' as user_status,
                       u.created_at as user_created_at,
                       usa.stripe_account_id,
                       usa.status,
                       'express' as type,
                       'US' as country,
                       'USD' as default_currency,
                       COALESCE(usa.requirements, '{}') as capabilities,
                       COALESCE(usa.requirements, '{}') as requirements,
                       usa.payouts_enabled,
                       usa.charges_enabled,
                       usa.details_submitted,
                       usa.created_at,
                       usa.updated_at
                   FROM users u
                   INNER JOIN user_stripe_accounts usa ON u.id = usa.user_id
                   $whereClause
                   ORDER BY usa.created_at DESC
                   LIMIT $limit OFFSET $offset";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute($params);
            $accounts = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Parse JSON fields
            foreach ($accounts as &$account) {
                $account['capabilities'] = json_decode($account['capabilities'] ?? '{}', true);
                $account['requirements'] = json_decode($account['requirements'] ?? '{}', true);
            }
            
            // Get total count
            $countSql = "SELECT COUNT(*) as total 
                        FROM users u 
                        INNER JOIN user_stripe_accounts usa ON u.id = usa.user_id 
                        $whereClause";
            $countStmt = $this->db->prepare($countSql);
            $countStmt->execute($params);
            $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'accounts' => $accounts,
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
                'message' => 'Error fetching connected accounts: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    public function getConnectedAccount(Request $request, Response $response, array $args): Response {
        $accountId = $args['id'];
        try {
            $sql = "SELECT 
                       u.id,
                       COALESCE(CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, '')), u.email) as user_name,
                       u.email as user_email,
                       'active' as user_status,
                       u.created_at as user_created_at,
                       'pending' as status,
                       'express' as type,
                       'US' as country,
                       'USD' as default_currency,
                       '{}' as capabilities,
                       '{}' as requirements,
                       0 as payouts_enabled,
                       0 as charges_enabled,
                       0 as details_submitted
                   FROM users u
                   WHERE u.id = ?";
            
            $stmt = $this->db->prepare($sql);
            $stmt->execute([$accountId]);
            $account = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$account) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Connected account not found'
                ]));
                return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            }
            
            // Parse JSON fields
            $account['capabilities'] = json_decode($account['capabilities'] ?? '{}', true);
            $account['requirements'] = json_decode($account['requirements'] ?? '{}', true);
            
            // Get account transactions
            $transactionsSql = "SELECT 
                               t.id,
                               t.amount,
                               t.status,
                               t.type,
                               t.created_at,
                               b.id as booking_id
                           FROM transactions t
                           LEFT JOIN bookings b ON t.booking_id = b.id
                           LEFT JOIN trips tr ON b.trip_id = tr.id
                           WHERE tr.user_id = ?
                           ORDER BY t.created_at DESC
                           LIMIT 10";
            $transactionsStmt = $this->db->prepare($transactionsSql);
            $transactionsStmt->execute([$account['id']]);
            $transactions = $transactionsStmt->fetchAll(PDO::FETCH_ASSOC);
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'account' => $account,
                'transactions' => $transactions
            ]));
            
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error fetching connected account: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    public function updateAccountStatus(Request $request, Response $response, array $args): Response {
        $accountId = $args['id'];
        try {
            $data = json_decode($request->getBody()->getContents(), true);
            $action = $data['action'] ?? null; // enable, disable, review
            $reason = $data['reason'] ?? 'Admin action';
            
            if (!in_array($action, ['enable', 'disable', 'review'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Invalid action. Must be enable, disable, or review.'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }
            
            // For now just return success - in real implementation you'd update Stripe
            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => "Account {$action}d successfully"
            ]));
            
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error updating account status: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    public function getStats(Request $request, Response $response): Response {
        try {
            $totalAccounts = $this->getTotalAccounts();
            $activeAccounts = $this->getActiveAccounts();
            $pendingAccounts = $this->getPendingAccounts();
            $restrictedAccounts = $this->getRestrictedAccounts();
            $totalPayoutsVolume = $this->getTotalPayoutsVolume();
            $pendingPayouts = $this->getPendingPayouts();
            $averageOnboardingTime = $this->getAverageOnboardingTime();
            
            $response->getBody()->write(json_encode([
                'success' => true,
                'stats' => [
                    'total_accounts' => $totalAccounts,
                    'active_accounts' => $activeAccounts,
                    'pending_accounts' => $pendingAccounts,
                    'restricted_accounts' => $restrictedAccounts,
                    'total_payouts_volume' => $totalPayoutsVolume,
                    'pending_payouts' => $pendingPayouts,
                    'average_onboarding_time_hours' => $averageOnboardingTime
                ]
            ]));
            
            return $response->withHeader('Content-Type', 'application/json');
            
        } catch (\Exception $e) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Error fetching Stripe stats: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
    
    private function getTotalAccounts() {
        try {
            $sql = "SELECT COUNT(*) as count FROM user_stripe_accounts";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getActiveAccounts() {
        try {
            $sql = "SELECT COUNT(*) as count FROM user_stripe_accounts WHERE status = 'active'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getPendingAccounts() {
        try {
            $sql = "SELECT COUNT(*) as count FROM user_stripe_accounts WHERE status IN ('pending', 'onboarding')";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getRestrictedAccounts() {
        try {
            $sql = "SELECT COUNT(*) as count FROM user_stripe_accounts WHERE status IN ('restricted', 'rejected')";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getTotalPayoutsVolume() {
        try {
            $sql = "SELECT COALESCE(SUM(amount), 0) as total 
                   FROM transactions 
                   WHERE type = 'payout' AND status = 'completed'";
            $stmt = $this->db->query($sql);
            return (float)$stmt->fetch(PDO::FETCH_ASSOC)['total'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getPendingPayouts() {
        try {
            $sql = "SELECT COUNT(*) as count FROM transactions WHERE type = 'payout' AND status = 'pending'";
            $stmt = $this->db->query($sql);
            return (int)$stmt->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (\Exception $e) {
            return 0;
        }
    }
    
    private function getAverageOnboardingTime() {
        try {
            return 24.5; // Mock data
        } catch (\Exception $e) {
            return 0;
        }
    }
}