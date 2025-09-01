<?php

declare(strict_types=1);

namespace KiloShare\Modules\Booking\Services;

use Exception;
use PDO;

/**
 * Service Stripe mockée pour le développement
 * En production, utiliser la vraie SDK Stripe
 */
class StripeService
{
    private bool $isDevelopmentMode;
    private string $publicKey;
    private string $secretKey;
    private PDO $db;
    
    public function __construct(PDO $db, bool $isDevelopmentMode = true)
    {
        $this->db = $db;
        
        // Utiliser la vraie API si configuré dans .env
        $useRealAPI = $_ENV['STRIPE_USE_REAL_API'] ?? false;
        $this->isDevelopmentMode = !$useRealAPI;
        
        if ($useRealAPI) {
            $this->publicKey = $_ENV['STRIPE_PUBLIC_KEY'] ?? '';
            $this->secretKey = $_ENV['STRIPE_SECRET_KEY'] ?? '';
            // Initialiser Stripe
            \Stripe\Stripe::setApiKey($this->secretKey);
        } else {
            $this->publicKey = 'pk_test_dev';
            $this->secretKey = 'sk_test_dev';
        }
    }

    /**
     * Créer un Payment Intent
     */
    public function createPaymentIntent(array $params): array
    {
        if ($this->isDevelopmentMode) {
            return $this->mockCreatePaymentIntent($params);
        }

        // En production, utiliser la vraie API Stripe
        // require_once 'vendor/autoload.php';
        // \Stripe\Stripe::setApiKey($this->secretKey);
        // return \Stripe\PaymentIntent::create($params);
        
        throw new Exception('Production Stripe integration not implemented yet');
    }

    /**
     * Confirmer un Payment Intent
     */
    public function confirmPaymentIntent(string $paymentIntentId, array $params = []): array
    {
        if ($this->isDevelopmentMode) {
            return $this->mockConfirmPaymentIntent($paymentIntentId, $params);
        }

        // En production
        // \Stripe\Stripe::setApiKey($this->secretKey);
        // return \Stripe\PaymentIntent::retrieve($paymentIntentId)->confirm($params);
        
        throw new Exception('Production Stripe integration not implemented yet');
    }

    /**
     * Créer un remboursement
     */
    public function createRefund(string $paymentIntentId, ?int $amount = null, array $metadata = []): array
    {
        if ($this->isDevelopmentMode) {
            return $this->mockCreateRefund($paymentIntentId, $amount, $metadata);
        }

        // En production
        // \Stripe\Stripe::setApiKey($this->secretKey);
        // return \Stripe\Refund::create([
        //     'payment_intent' => $paymentIntentId,
        //     'amount' => $amount,
        //     'metadata' => $metadata
        // ]);
        
        throw new Exception('Production Stripe integration not implemented yet');
    }

    /**
     * Récupérer un Payment Intent
     */
    public function retrievePaymentIntent(string $paymentIntentId): array
    {
        if ($this->isDevelopmentMode) {
            return $this->mockRetrievePaymentIntent($paymentIntentId);
        }

        // En production
        // \Stripe\Stripe::setApiKey($this->secretKey);
        // return \Stripe\PaymentIntent::retrieve($paymentIntentId)->toArray();
        
        throw new Exception('Production Stripe integration not implemented yet');
    }

    /**
     * Obtenir la clé publique
     */
    public function getPublicKey(): string
    {
        return $this->publicKey;
    }

    /**
     * Vérifier si on est en mode développement
     */
    public function isDevelopmentMode(): bool
    {
        return $this->isDevelopmentMode;
    }

    // ===========================================
    // MÉTHODES MOCKÉES POUR LE DÉVELOPPEMENT
    // ===========================================

    /**
     * Mock - Créer un Payment Intent
     */
    private function mockCreatePaymentIntent(array $params): array
    {
        $paymentIntentId = 'pi_dev_' . uniqid() . '_' . time();
        $clientSecret = $paymentIntentId . '_secret_' . uniqid();
        
        $amount = $params['amount'] ?? 0;
        $currency = $params['currency'] ?? 'cad';
        
        // Simuler un délai réseau
        usleep(100000); // 100ms
        
        return [
            'id' => $paymentIntentId,
            'object' => 'payment_intent',
            'amount' => $amount,
            'currency' => $currency,
            'status' => 'requires_payment_method',
            'client_secret' => $clientSecret,
            'created' => time(),
            'description' => $params['description'] ?? null,
            'metadata' => $params['metadata'] ?? [],
            'payment_method_types' => ['card'],
            'setup_future_usage' => null,
            'shipping' => null,
            'source' => null,
            'statement_descriptor' => 'KiloShare',
            'transfer_data' => null,
            'transfer_group' => null
        ];
    }

    /**
     * Mock - Confirmer un Payment Intent
     */
    private function mockConfirmPaymentIntent(string $paymentIntentId, array $params): array
    {
        // Simuler un délai de traitement
        usleep(200000); // 200ms
        
        // Simuler différents résultats selon l'ID ou les paramètres
        $shouldSucceed = !isset($params['simulate_failure']) || !$params['simulate_failure'];
        
        if ($shouldSucceed) {
            return [
                'id' => $paymentIntentId,
                'object' => 'payment_intent',
                'status' => 'succeeded',
                'amount_received' => $this->extractAmountFromId($paymentIntentId),
                'charges' => [
                    'data' => [
                        [
                            'id' => 'ch_dev_' . uniqid(),
                            'status' => 'succeeded',
                            'amount' => $this->extractAmountFromId($paymentIntentId),
                            'created' => time(),
                            'payment_method_details' => [
                                'card' => [
                                    'brand' => 'visa',
                                    'last4' => '4242'
                                ]
                            ]
                        ]
                    ]
                ],
                'created' => time() - 300, // Créé il y a 5 minutes
                'currency' => 'cad',
                'metadata' => $params['metadata'] ?? []
            ];
        } else {
            return [
                'id' => $paymentIntentId,
                'object' => 'payment_intent',
                'status' => 'requires_payment_method',
                'last_payment_error' => [
                    'code' => 'card_declined',
                    'message' => 'Your card was declined.',
                    'type' => 'card_error'
                ],
                'created' => time() - 300
            ];
        }
    }

    /**
     * Mock - Créer un remboursement
     */
    private function mockCreateRefund(string $paymentIntentId, ?int $amount, array $metadata): array
    {
        // Simuler un délai de traitement
        usleep(150000); // 150ms
        
        $refundId = 're_dev_' . uniqid() . '_' . time();
        $originalAmount = $this->extractAmountFromId($paymentIntentId);
        $refundAmount = $amount ?? $originalAmount;
        
        return [
            'id' => $refundId,
            'object' => 'refund',
            'amount' => $refundAmount,
            'created' => time(),
            'currency' => 'cad',
            'metadata' => $metadata,
            'payment_intent' => $paymentIntentId,
            'reason' => 'requested_by_customer',
            'receipt_number' => null,
            'source_transfer_reversal' => null,
            'status' => 'succeeded',
            'transfer_reversal' => null
        ];
    }

    /**
     * Mock - Récupérer un Payment Intent
     */
    private function mockRetrievePaymentIntent(string $paymentIntentId): array
    {
        // Simuler une récupération de base de données
        usleep(50000); // 50ms
        
        return [
            'id' => $paymentIntentId,
            'object' => 'payment_intent',
            'amount' => $this->extractAmountFromId($paymentIntentId),
            'currency' => 'cad',
            'status' => 'succeeded', // Supposer que c'est réussi pour la simulation
            'created' => time() - 3600, // Créé il y a 1 heure
            'description' => 'Paiement KiloShare - Réservation de transport',
            'metadata' => [
                'booking_id' => 'mock_booking_id',
                'user_id' => 'mock_user_id'
            ]
        ];
    }

    /**
     * Extraire le montant de l'ID (simulation)
     */
    private function extractAmountFromId(string $paymentIntentId): int
    {
        // Pour la simulation, utiliser un montant par défaut
        // En réalité, on devrait stocker cela en base de données
        return 10000; // 100.00 CAD en centimes
    }

    /**
     * Obtenir les informations de webhook pour la simulation
     */
    public function getWebhookEndpoint(): string
    {
        return $this->isDevelopmentMode 
            ? 'http://localhost/api/webhooks/stripe'
            : 'https://kiloshare.com/api/webhooks/stripe';
    }

    /**
     * Simuler un webhook Stripe
     */
    public function simulateWebhook(string $eventType, array $data = []): array
    {
        if (!$this->isDevelopmentMode) {
            throw new Exception('Webhook simulation only available in development mode');
        }

        $eventId = 'evt_dev_' . uniqid() . '_' . time();
        
        return [
            'id' => $eventId,
            'object' => 'event',
            'type' => $eventType,
            'created' => time(),
            'data' => [
                'object' => $data
            ],
            'livemode' => false,
            'pending_webhooks' => 0,
            'request' => [
                'id' => 'req_dev_' . uniqid(),
                'idempotency_key' => null
            ]
        ];
    }

    /**
     * Obtenir les types d'événements webhook supportés
     */
    public function getSupportedWebhookEvents(): array
    {
        return [
            'payment_intent.succeeded',
            'payment_intent.payment_failed',
            'payment_intent.canceled',
            'payment_intent.requires_action',
            'charge.succeeded',
            'charge.failed',
            'refund.created',
            'refund.updated'
        ];
    }

    /**
     * Valider une signature de webhook (simulation)
     */
    public function validateWebhookSignature(string $payload, string $signature, string $secret): bool
    {
        if ($this->isDevelopmentMode) {
            // En développement, toujours valide
            return true;
        }

        // En production, utiliser la validation Stripe réelle
        // return \Stripe\Webhook::constructEvent($payload, $signature, $secret) !== null;
        
        return false;
    }

    // ===========================================
    // MÉTHODES POUR COMPTES CONNECTÉS STRIPE
    // ===========================================

    /**
     * Créer un compte connecté Stripe pour un utilisateur
     */
    public function createConnectedAccount(int $userId, array $userInfo): array
    {
        try {
            if ($this->isDevelopmentMode) {
                return $this->mockCreateConnectedAccount($userId, $userInfo);
            }

            // Créer un vrai compte Stripe Express
            $account = \Stripe\Account::create([
                'type' => 'express',
                'email' => $userInfo['email'],
                'capabilities' => [
                    'card_payments' => ['requested' => true],
                    'transfers' => ['requested' => true],
                ],
                'metadata' => [
                    'user_id' => (string)$userId,
                    'platform' => 'kiloshare'
                ],
                'settings' => [
                    'payouts' => [
                        'schedule' => [
                            'interval' => 'manual' // Permettre les paiements manuels
                        ]
                    ]
                ]
            ]);

            // Sauvegarder en base de données
            $this->saveConnectedAccount($userId, $account->id, [
                'status' => 'pending',
                'details_submitted' => $account->details_submitted,
                'charges_enabled' => $account->charges_enabled,
                'payouts_enabled' => $account->payouts_enabled
            ]);

            return $account->toArray();

        } catch (\Stripe\Exception\ApiErrorException $e) {
            error_log("Erreur Stripe API: " . $e->getMessage());
            throw new Exception('Erreur Stripe: ' . $e->getMessage());
        } catch (Exception $e) {
            error_log("Erreur création compte connecté: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Créer un lien d'onboarding pour un compte connecté
     */
    public function createAccountLink(string $stripeAccountId, int $userId): array
    {
        try {
            if ($this->isDevelopmentMode) {
                return $this->mockCreateAccountLink($stripeAccountId, $userId);
            }

            // Créer un vrai lien d'onboarding Stripe
            $accountLink = \Stripe\AccountLink::create([
                'account' => $stripeAccountId,
                'refresh_url' => ($_ENV['APP_URL'] ?? 'http://localhost:8080') . '/api/v1/stripe/refresh?user_id=' . $userId,
                'return_url' => ($_ENV['APP_URL'] ?? 'http://localhost:8080') . '/api/v1/stripe/return?user_id=' . $userId,
                'type' => 'account_onboarding',
            ]);
            
            return $accountLink->toArray();

        } catch (\Stripe\Exception\ApiErrorException $e) {
            error_log("Erreur Stripe API lien: " . $e->getMessage());
            throw new Exception('Erreur Stripe: ' . $e->getMessage());
        } catch (Exception $e) {
            error_log("Erreur création lien onboarding: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Vérifier le statut d'un compte connecté
     */
    public function getAccountStatus(string $stripeAccountId): array
    {
        try {
            if ($this->isDevelopmentMode) {
                return $this->mockGetAccountStatus($stripeAccountId);
            }

            // Récupérer le statut du vrai compte Stripe
            $account = \Stripe\Account::retrieve($stripeAccountId);
            
            return [
                'id' => $account->id,
                'charges_enabled' => $account->charges_enabled,
                'payouts_enabled' => $account->payouts_enabled,
                'details_submitted' => $account->details_submitted,
                'requirements' => $account->requirements->toArray()
            ];

        } catch (\Stripe\Exception\ApiErrorException $e) {
            error_log("Erreur Stripe API statut: " . $e->getMessage());
            throw new Exception('Erreur Stripe: ' . $e->getMessage());
        } catch (Exception $e) {
            error_log("Erreur vérification statut compte: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Sauvegarder les informations du compte connecté en base
     */
    public function saveConnectedAccount(int $userId, string $stripeAccountId, array $accountInfo): bool
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO user_stripe_accounts (user_id, stripe_account_id, status, details_submitted, charges_enabled, payouts_enabled)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    status = VALUES(status),
                    details_submitted = VALUES(details_submitted),
                    charges_enabled = VALUES(charges_enabled),
                    payouts_enabled = VALUES(payouts_enabled),
                    updated_at = CURRENT_TIMESTAMP
            ");

            return $stmt->execute([
                $userId,
                $stripeAccountId,
                $accountInfo['status'] ?? 'pending',
                $accountInfo['details_submitted'] ?? false,
                $accountInfo['charges_enabled'] ?? false,
                $accountInfo['payouts_enabled'] ?? false
            ]);

        } catch (Exception $e) {
            error_log("Erreur sauvegarde compte connecté: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Récupérer les infos du compte Stripe d'un utilisateur
     */
    public function getUserStripeAccount(int $userId): ?array
    {
        try {
            $stmt = $this->db->prepare("
                SELECT * FROM user_stripe_accounts 
                WHERE user_id = ?
            ");
            
            $stmt->execute([$userId]);
            return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;

        } catch (Exception $e) {
            error_log("Erreur récupération compte Stripe: " . $e->getMessage());
            return null;
        }
    }

    // ===========================================
    // MÉTHODES MOCKÉES POUR COMPTES CONNECTÉS
    // ===========================================

    /**
     * Mock - Créer un compte connecté
     */
    private function mockCreateConnectedAccount(int $userId, array $userInfo): array
    {
        $accountId = 'acct_dev_' . uniqid() . '_' . $userId;
        
        // Simuler un délai réseau
        usleep(150000); // 150ms
        
        $accountData = [
            'id' => $accountId,
            'object' => 'account',
            'type' => 'express',
            'email' => $userInfo['email'],
            'charges_enabled' => false,
            'payouts_enabled' => false,
            'details_submitted' => false,
            'created' => time(),
            'country' => 'CA',
            'default_currency' => 'cad',
            'metadata' => [
                'user_id' => $userId,
                'platform' => 'kiloshare'
            ],
            'requirements' => [
                'currently_due' => ['external_account', 'tos_acceptance.date'],
                'eventually_due' => [],
                'past_due' => [],
                'pending_verification' => []
            ]
        ];

        // Sauvegarder en base de données
        $this->saveConnectedAccount($userId, $accountId, [
            'status' => 'pending',
            'details_submitted' => false,
            'charges_enabled' => false,
            'payouts_enabled' => false
        ]);

        return $accountData;
    }

    /**
     * Mock - Créer un lien d'onboarding
     */
    private function mockCreateAccountLink(string $stripeAccountId, int $userId): array
    {
        // Simuler un délai réseau
        usleep(100000); // 100ms
        
        return [
            'object' => 'account_link',
            'created' => time(),
            'expires_at' => time() + 300, // 5 minutes
            'url' => 'https://connect.stripe.com/setup/mock/' . $stripeAccountId . '?dev=true'
        ];
    }

    /**
     * Mock - Obtenir le statut d'un compte
     */
    private function mockGetAccountStatus(string $stripeAccountId): array
    {
        // En mode dev, simuler différents statuts selon l'ID
        $isCompleted = str_contains($stripeAccountId, 'completed');
        
        return [
            'id' => $stripeAccountId,
            'charges_enabled' => $isCompleted,
            'payouts_enabled' => $isCompleted,
            'details_submitted' => $isCompleted,
            'requirements' => [
                'currently_due' => $isCompleted ? [] : ['external_account', 'tos_acceptance.date'],
                'eventually_due' => [],
                'past_due' => [],
                'pending_verification' => []
            ]
        ];
    }
}