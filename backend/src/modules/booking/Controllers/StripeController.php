<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use KiloShare\Modules\Booking\Services\StripeService;
use KiloShare\Models\User;
use Exception;
use PDO;

class StripeController
{
    private PDO $db;
    private StripeService $stripeService;
    private User $userModel;

    public function __construct(PDO $db, StripeService $stripeService)
    {
        $this->db = $db;
        $this->stripeService = $stripeService;
        $this->userModel = new User($db);
    }

    /**
     * Créer un compte Stripe connecté pour l'utilisateur
     */
    public function createConnectedAccount(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            
            // Vérifier si l'utilisateur a déjà un compte Stripe
            $existingAccount = $this->stripeService->getUserStripeAccount($userId);
            if ($existingAccount) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Vous avez déjà un compte Stripe connecté',
                    'account' => $existingAccount
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            // Récupérer les infos utilisateur
            $user = $this->userModel->findById($userId);
            if (!$user) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Utilisateur non trouvé'
                ]));
                return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            }

            // Logger la tentative de création
            $this->logAccountCreationAttempt($userId);

            // Créer le compte Stripe connecté
            $accountData = $this->stripeService->createConnectedAccount($userId, [
                'email' => $user['email'],
                'first_name' => $user['first_name'],
                'last_name' => $user['last_name']
            ]);

            // Créer le lien d'onboarding
            $accountLink = $this->stripeService->createAccountLink($accountData['id'], $userId);

            // Logger le succès
            $this->logAccountCreationSuccess($userId, $accountData['id'], $accountData);

            $response->getBody()->write(json_encode([
                'success' => true,
                'account_id' => $accountData['id'],
                'onboarding_url' => $accountLink['url'],
                'expires_at' => $accountLink['expires_at'],
                'message' => 'Compte Stripe créé avec succès. Complétez votre onboarding.',
                'next_steps' => [
                    'Cliquez sur le lien d\'onboarding',
                    'Complétez vos informations personnelles',
                    'Ajoutez votre compte bancaire',
                    'Acceptez les conditions de service'
                ]
            ]));

            return $response->withStatus(201)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur StripeController::createConnectedAccount: " . $e->getMessage());
            
            // Logger l'erreur
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            $this->logAccountCreationError($userId, $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la création du compte Stripe: ' . $e->getMessage()
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Obtenir le statut du compte Stripe de l'utilisateur
     */
    public function getAccountStatus(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            
            $account = $this->stripeService->getUserStripeAccount($userId);
            
            if (!$account) {
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'has_account' => false,
                    'message' => 'Aucun compte Stripe connecté'
                ]));
                return $response->withStatus(200)->withHeader('Content-Type', 'application/json');
            }

            // Vérifier le statut actuel chez Stripe
            $stripeStatus = $this->stripeService->getAccountStatus($account['stripe_account_id']);
            
            // Mettre à jour le statut en base si nécessaire
            if ($stripeStatus['charges_enabled'] !== (bool)$account['charges_enabled'] ||
                $stripeStatus['payouts_enabled'] !== (bool)$account['payouts_enabled']) {
                
                $this->stripeService->saveConnectedAccount($userId, $account['stripe_account_id'], [
                    'status' => $stripeStatus['charges_enabled'] && $stripeStatus['payouts_enabled'] ? 'active' : 'pending',
                    'details_submitted' => $stripeStatus['details_submitted'],
                    'charges_enabled' => $stripeStatus['charges_enabled'],
                    'payouts_enabled' => $stripeStatus['payouts_enabled']
                ]);

                // Marquer l'utilisateur comme ayant complété l'onboarding si tout est OK
                if ($stripeStatus['charges_enabled'] && $stripeStatus['payouts_enabled']) {
                    $this->markUserStripeCompleted($userId);
                }
            }

            $response->getBody()->write(json_encode([
                'success' => true,
                'has_account' => true,
                'account' => array_merge($account, $stripeStatus),
                'transaction_ready' => $stripeStatus['charges_enabled'] && $stripeStatus['payouts_enabled'],
                'onboarding_complete' => $stripeStatus['details_submitted'] && 
                                       $stripeStatus['charges_enabled'] && 
                                       $stripeStatus['payouts_enabled']
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur StripeController::getAccountStatus: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la vérification du statut Stripe'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Créer un nouveau lien d'onboarding (si l'ancien a expiré)
     */
    public function refreshAccountLink(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = $user['id'] ?? null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'User ID not found in token'
                ]));
                return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
            }
            
            $account = $this->stripeService->getUserStripeAccount($userId);
            
            if (!$account) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Aucun compte Stripe connecté. Créez d\'abord un compte.'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            // Créer un nouveau lien d'onboarding
            $accountLink = $this->stripeService->createAccountLink($account['stripe_account_id'], $userId);

            $response->getBody()->write(json_encode([
                'success' => true,
                'onboarding_url' => $accountLink['url'],
                'expires_at' => $accountLink['expires_at'],
                'message' => 'Nouveau lien d\'onboarding généré'
            ]));

            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur StripeController::refreshAccountLink: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur lors de la génération du lien d\'onboarding'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    /**
     * Webhook pour les mises à jour de comptes Stripe
     */
    public function handleWebhook(Request $request, Response $response): Response
    {
        try {
            $payload = $request->getBody()->getContents();
            $sigHeader = $request->getHeaderLine('stripe-signature');
            
            // Valider la signature webhook
            if (!$this->stripeService->validateWebhookSignature($payload, $sigHeader, $_ENV['STRIPE_WEBHOOK_SECRET'] ?? '')) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'error' => 'Signature webhook invalide'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $event = json_decode($payload, true);
            
            if ($event['type'] === 'account.updated') {
                $this->handleAccountUpdated($event['data']['object']);
            }

            $response->getBody()->write(json_encode(['success' => true]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            error_log("Erreur StripeController::handleWebhook: " . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'error' => 'Erreur webhook'
            ]));
            
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    // Méthodes privées

    private function logAccountCreationAttempt(int $userId): void
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO stripe_account_creation_log (user_id, status)
                VALUES (?, 'attempting')
            ");
            $stmt->execute([$userId]);
        } catch (Exception $e) {
            error_log("Erreur log tentative création: " . $e->getMessage());
        }
    }

    private function logAccountCreationSuccess(int $userId, string $accountId, array $response): void
    {
        try {
            $stmt = $this->db->prepare("
                UPDATE stripe_account_creation_log 
                SET status = 'success', stripe_account_id = ?, stripe_response = ?
                WHERE user_id = ? AND status = 'attempting'
                ORDER BY created_at DESC LIMIT 1
            ");
            $stmt->execute([$accountId, json_encode($response), $userId]);
        } catch (Exception $e) {
            error_log("Erreur log succès création: " . $e->getMessage());
        }
    }

    private function logAccountCreationError(int $userId, string $error): void
    {
        try {
            $stmt = $this->db->prepare("
                UPDATE stripe_account_creation_log 
                SET status = 'failed', error_message = ?
                WHERE user_id = ? AND status = 'attempting'
                ORDER BY created_at DESC LIMIT 1
            ");
            $stmt->execute([$error, $userId]);
        } catch (Exception $e) {
            error_log("Erreur log erreur création: " . $e->getMessage());
        }
    }

    private function markUserStripeCompleted(int $userId): void
    {
        try {
            $stmt = $this->db->prepare("
                UPDATE users 
                SET stripe_setup_completed = TRUE, stripe_onboarding_completed_at = CURRENT_TIMESTAMP
                WHERE id = ?
            ");
            $stmt->execute([$userId]);
        } catch (Exception $e) {
            error_log("Erreur marquage utilisateur Stripe: " . $e->getMessage());
        }
    }

    private function handleAccountUpdated(array $accountData): void
    {
        try {
            $accountId = $accountData['id'];
            $userId = $accountData['metadata']['user_id'] ?? null;
            
            if (!$userId) {
                error_log("Webhook account.updated sans user_id pour compte: " . $accountId);
                return;
            }

            // Mettre à jour le statut en base
            $this->stripeService->saveConnectedAccount((int)$userId, $accountId, [
                'status' => $accountData['charges_enabled'] && $accountData['payouts_enabled'] ? 'active' : 'pending',
                'details_submitted' => $accountData['details_submitted'],
                'charges_enabled' => $accountData['charges_enabled'],
                'payouts_enabled' => $accountData['payouts_enabled']
            ]);

            // Marquer comme complété si nécessaire
            if ($accountData['charges_enabled'] && $accountData['payouts_enabled']) {
                $this->markUserStripeCompleted((int)$userId);
            }

        } catch (Exception $e) {
            error_log("Erreur traitement webhook account.updated: " . $e->getMessage());
        }
    }
}