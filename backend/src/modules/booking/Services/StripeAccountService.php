<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Services;

use PDO;
use Exception;

class StripeAccountService 
{
    private PDO $db;
    
    public function __construct(PDO $db) 
    {
        $this->db = $db;
    }
    
    /**
     * Vérifier si un utilisateur a déjà un compte Stripe
     */
    public function hasStripeAccount(int $userId): bool 
    {
        $stmt = $this->db->prepare("
            SELECT id FROM user_stripe_accounts 
            WHERE user_id = ? AND status != 'rejected'
        ");
        $stmt->execute([$userId]);
        return $stmt->rowCount() > 0;
    }
    
    /**
     * Créer un compte Stripe Connected Account pour un utilisateur
     */
    public function createConnectedAccount(int $userId, float $expectedAmount): array 
    {
        try {
            // Vérifier si le compte existe déjà
            if ($this->hasStripeAccount($userId)) {
                $stmt = $this->db->prepare("
                    SELECT * FROM user_stripe_accounts 
                    WHERE user_id = ? AND status != 'rejected'
                ");
                $stmt->execute([$userId]);
                return $stmt->fetch(PDO::FETCH_ASSOC) ?: [];
            }
            
            // Simuler la création du compte Stripe (en production, utiliser l'API Stripe)
            $stripeAccountId = 'acct_' . uniqid();
            $onboardingUrl = 'https://connect.stripe.com/setup/e/' . $stripeAccountId;
            
            // Enregistrer dans la base de données
            $stmt = $this->db->prepare("
                INSERT INTO user_stripe_accounts 
                (user_id, stripe_account_id, status, details_submitted, charges_enabled, 
                 payouts_enabled, onboarding_url, requirements, created_at, updated_at)
                VALUES (?, ?, 'pending', 0, 0, 0, ?, '{}', NOW(), NOW())
            ");
            
            $stmt->execute([
                $userId,
                $stripeAccountId,
                $onboardingUrl
            ]);
            
            // Logger cette création
            $this->logAccountCreation($userId, $stripeAccountId, $expectedAmount);
            
            // Retourner les détails du compte
            return [
                'id' => (int)$this->db->lastInsertId(),
                'user_id' => $userId,
                'stripe_account_id' => $stripeAccountId,
                'status' => 'pending',
                'onboarding_url' => $onboardingUrl,
                'details_submitted' => false,
                'charges_enabled' => false,
                'payouts_enabled' => false,
                'expected_amount' => $expectedAmount
            ];
            
        } catch (Exception $e) {
            error_log("Erreur création compte Stripe: " . $e->getMessage());
            throw new Exception("Impossible de créer le compte Stripe: " . $e->getMessage());
        }
    }
    
    /**
     * Logger la création d'un compte Stripe
     */
    private function logAccountCreation(int $userId, string $stripeAccountId, float $expectedAmount): void 
    {
        try {
            $stripeResponse = json_encode([
                'trigger_event' => 'negotiation_accepted',
                'expected_amount' => $expectedAmount,
                'onboarding_initiated' => true
            ]);
            
            $stmt = $this->db->prepare("
                INSERT INTO stripe_account_creation_log 
                (user_id, stripe_account_id, status, stripe_response, created_at)
                VALUES (?, ?, 'success', ?, NOW())
            ");
            
            $stmt->execute([$userId, $stripeAccountId, $stripeResponse]);
            
        } catch (Exception $e) {
            error_log("Erreur log création compte Stripe: " . $e->getMessage());
        }
    }
    
    /**
     * Récupérer le compte Stripe d'un utilisateur
     */
    public function getUserStripeAccount(int $userId): ?array 
    {
        $stmt = $this->db->prepare("
            SELECT * FROM user_stripe_accounts 
            WHERE user_id = ? AND status != 'rejected'
            ORDER BY created_at DESC
            LIMIT 1
        ");
        $stmt->execute([$userId]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        return $result ?: null;
    }
    
    /**
     * Mettre à jour le statut d'un compte Stripe
     */
    public function updateAccountStatus(int $userId, string $status): bool 
    {
        $validStatuses = ['pending', 'onboarding', 'active', 'restricted', 'rejected'];
        
        if (!in_array($status, $validStatuses)) {
            throw new Exception("Statut invalide: $status");
        }
        
        $stmt = $this->db->prepare("
            UPDATE user_stripe_accounts 
            SET status = ?, updated_at = NOW()
            WHERE user_id = ?
        ");
        
        return $stmt->execute([$status, $userId]);
    }
    
    /**
     * Générer un message de motivation pour la création de compte
     */
    public function getMotivationalMessage(float $amount): string 
    {
        return "🎉 Félicitations ! Pour recevoir votre paiement de " . number_format($amount, 2) . "$, configurez votre compte de paiement (2 minutes)";
    }
}