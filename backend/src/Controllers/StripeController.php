<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use KiloShare\Models\User;
use KiloShare\Models\UserStripeAccount;
use KiloShare\Utils\Response;
use Stripe\Stripe;
use Stripe\Account;
use Stripe\AccountLink;
use Exception;

class StripeController
{
    public function __construct()
    {
        // Initialize Stripe with secret key
        Stripe::setApiKey($_ENV['STRIPE_SECRET_KEY']);
    }

    /**
     * Create a Stripe Connect account for the user
     */
    public function createConnectedAccount(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            // Check if user already has a Stripe account
            $existingAccount = UserStripeAccount::where('user_id', $user->id)->first();
            if ($existingAccount) {
                // If account exists but onboarding is incomplete, create new account link
                if ($existingAccount->status !== 'active') {
                    $accountLink = AccountLink::create([
                        'account' => $existingAccount->stripe_account_id,
                        'refresh_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?refresh=true',
                        'return_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?success=true',
                        'type' => 'account_onboarding',
                    ]);

                    // Update the onboarding URL
                    $existingAccount->onboarding_url = $accountLink->url;
                    $existingAccount->save();

                    return Response::success([
                        'account_id' => $existingAccount->stripe_account_id,
                        'onboarding_url' => $accountLink->url,
                        'expires_at' => $accountLink->expires_at,
                        'message' => 'Lien d\'onboarding régénéré',
                        'next_steps' => [
                            'Cliquez sur le lien d\'onboarding',
                            'Complétez vos informations personnelles',
                            'Ajoutez vos informations bancaires',
                            'Acceptez les conditions d\'utilisation'
                        ]
                    ], 'Account link created successfully', 201);
                }

                return Response::error('Un compte Stripe actif existe déjà pour cet utilisateur', [], 400);
            }

            // Create new Stripe Express account
            $account = Account::create([
                'type' => 'express',
                'country' => 'CA', // Canada
                'email' => $user->email,
                'capabilities' => [
                    'card_payments' => ['requested' => true],
                    'transfers' => ['requested' => true],
                ],
                'business_type' => 'individual',
                'individual' => [
                    'email' => $user->email,
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                ],
                'metadata' => [
                    'kiloshare_user_id' => (string)$user->id,
                ]
            ]);

            // Create account link for onboarding
            $accountLink = AccountLink::create([
                'account' => $account->id,
                'refresh_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?refresh=true',
                'return_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?success=true',
                'type' => 'account_onboarding',
            ]);

            // Save account info to database
            UserStripeAccount::create([
                'user_id' => $user->id,
                'stripe_account_id' => $account->id,
                'status' => 'pending',
                'details_submitted' => false,
                'charges_enabled' => false,
                'payouts_enabled' => false,
                'onboarding_url' => $accountLink->url,
                'requirements' => json_encode([
                    'currently_due' => $account->requirements->currently_due ?? [],
                    'eventually_due' => $account->requirements->eventually_due ?? [],
                    'past_due' => $account->requirements->past_due ?? [],
                ])
            ]);

            return Response::success([
                'account_id' => $account->id,
                'onboarding_url' => $accountLink->url,
                'expires_at' => $accountLink->expires_at,
                'message' => 'Compte Stripe Connect créé avec succès',
                'next_steps' => [
                    'Cliquez sur le lien d\'onboarding',
                    'Complétez vos informations personnelles',
                    'Ajoutez vos informations bancaires',
                    'Acceptez les conditions d\'utilisation'
                ]
            ], 'Stripe Connect account created successfully', 201);

        } catch (Exception $e) {
            return Response::serverError('Erreur lors de la création du compte Stripe: ' . $e->getMessage());
        }
    }

    /**
     * Get the Stripe account status for the user
     */
    public function getAccountStatus(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            $userStripeAccount = UserStripeAccount::where('user_id', $user->id)->first();

            if (!$userStripeAccount) {
                return Response::success([
                    'has_account' => false,
                    'account' => null,
                    'transaction_ready' => false,
                    'onboarding_complete' => false,
                    'message' => 'Aucun compte Stripe Connect trouvé'
                ]);
            }

            // Get fresh account info from Stripe
            $account = Account::retrieve($userStripeAccount->stripe_account_id);

            // Update local record with fresh data
            $userStripeAccount->details_submitted = $account->details_submitted;
            $userStripeAccount->charges_enabled = $account->charges_enabled;
            $userStripeAccount->payouts_enabled = $account->payouts_enabled;

            // Determine status based on Stripe account state
            $newStatus = 'pending';
            if ($account->details_submitted && $account->charges_enabled && $account->payouts_enabled) {
                $newStatus = 'active';
            } elseif ($account->details_submitted && $account->charges_enabled) {
                // Account has restrictions but can accept payments - needs verification
                $newStatus = 'restricted';
            } elseif ($account->details_submitted) {
                $newStatus = 'onboarding';
            }

            $userStripeAccount->status = $newStatus;
            $userStripeAccount->requirements = json_encode([
                'currently_due' => $account->requirements->currently_due ?? [],
                'eventually_due' => $account->requirements->eventually_due ?? [],
                'past_due' => $account->requirements->past_due ?? [],
            ]);
            $userStripeAccount->save();

            $transactionReady = $account->charges_enabled && $account->payouts_enabled;
            $onboardingComplete = $account->details_submitted;
            $hasRestrictions = !empty($account->requirements->currently_due) || !empty($account->requirements->past_due);

            // Generate new onboarding link if account has restrictions
            $onboardingUrl = null;
            if ($hasRestrictions && $userStripeAccount->status !== 'active') {
                try {
                    $accountLink = AccountLink::create([
                        'account' => $account->id,
                        'refresh_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?refresh=true',
                        'return_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?success=true',
                        'type' => 'account_onboarding',
                    ]);
                    
                    $onboardingUrl = $accountLink->url;
                    $userStripeAccount->onboarding_url = $onboardingUrl;
                    $userStripeAccount->save();
                } catch (Exception $e) {
                    // Log error but continue
                    error_log('Failed to create onboarding link: ' . $e->getMessage());
                }
            }

            $message = 'Compte Stripe Connect prêt pour les transactions';
            if (!$transactionReady) {
                if ($hasRestrictions) {
                    $message = 'Vérification d\'identité requise pour finaliser votre compte';
                } else {
                    $message = 'Configuration Stripe Connect en cours';
                }
            }

            return Response::success([
                'has_account' => true,
                'account' => [
                    'id' => $account->id,
                    'status' => $userStripeAccount->status,
                    'details_submitted' => $account->details_submitted,
                    'charges_enabled' => $account->charges_enabled,
                    'payouts_enabled' => $account->payouts_enabled,
                    'has_restrictions' => $hasRestrictions,
                    'requirements' => [
                        'currently_due' => $account->requirements->currently_due ?? [],
                        'eventually_due' => $account->requirements->eventually_due ?? [],
                        'past_due' => $account->requirements->past_due ?? [],
                    ]
                ],
                'transaction_ready' => $transactionReady,
                'onboarding_complete' => $onboardingComplete,
                'onboarding_url' => $onboardingUrl,
                'message' => $message
            ]);

        } catch (Exception $e) {
            return Response::serverError('Erreur lors de la vérification du statut Stripe: ' . $e->getMessage());
        }
    }

    /**
     * Refresh onboarding link if it expired
     */
    public function refreshOnboardingLink(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        try {
            $userStripeAccount = UserStripeAccount::where('user_id', $user->id)->first();

            if (!$userStripeAccount) {
                return Response::notFound('Aucun compte Stripe trouvé');
            }

            if ($userStripeAccount->status === 'active') {
                return Response::error('Le compte Stripe est déjà actif', [], 400);
            }

            // Create new account link
            $accountLink = AccountLink::create([
                'account' => $userStripeAccount->stripe_account_id,
                'refresh_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?refresh=true',
                'return_url' => $_ENV['FRONTEND_URL'] . '/profile/wallet?success=true',
                'type' => 'account_onboarding',
            ]);

            // Update the onboarding URL
            $userStripeAccount->onboarding_url = $accountLink->url;
            $userStripeAccount->save();

            return Response::success([
                'onboarding_url' => $accountLink->url,
                'expires_at' => $accountLink->expires_at,
                'message' => 'Lien d\'onboarding rafraîchi'
            ]);

        } catch (Exception $e) {
            return Response::serverError('Erreur lors du rafraîchissement du lien: ' . $e->getMessage());
        }
    }

    /**
     * Handle Stripe webhook events
     */
    public function handleWebhook(ServerRequestInterface $request): ResponseInterface
    {
        $payload = $request->getBody()->getContents();
        $sigHeader = $request->getHeaderLine('Stripe-Signature');

        try {
            $event = \Stripe\Webhook::constructEvent(
                $payload,
                $sigHeader,
                $_ENV['STRIPE_WEBHOOK_SECRET']
            );

            // Handle the event
            switch ($event['type']) {
                case 'account.updated':
                    $this->handleAccountUpdated($event['data']['object']);
                    break;
                
                case 'account.application.deauthorized':
                    $this->handleAccountDeauthorized($event['data']['object']);
                    break;

                default:
                    // Unhandled event type
                    break;
            }

            return Response::success(['received' => true]);

        } catch (\Stripe\Exception\SignatureVerificationException $e) {
            return Response::error('Invalid signature', [], 400);
        } catch (Exception $e) {
            return Response::serverError('Webhook error: ' . $e->getMessage());
        }
    }

    private function handleAccountUpdated($account): void
    {
        $userStripeAccount = UserStripeAccount::where('stripe_account_id', $account['id'])->first();
        
        if ($userStripeAccount) {
            $userStripeAccount->details_submitted = $account['details_submitted'];
            $userStripeAccount->charges_enabled = $account['charges_enabled'];
            $userStripeAccount->payouts_enabled = $account['payouts_enabled'];
            
            // Update status
            if ($account['details_submitted'] && $account['charges_enabled'] && $account['payouts_enabled']) {
                $userStripeAccount->status = 'active';
            } elseif ($account['details_submitted']) {
                $userStripeAccount->status = 'onboarding';
            }
            
            $userStripeAccount->requirements = json_encode($account['requirements']);
            $userStripeAccount->save();
        }
    }

    private function handleAccountDeauthorized($account): void
    {
        $userStripeAccount = UserStripeAccount::where('stripe_account_id', $account['id'])->first();
        
        if ($userStripeAccount) {
            $userStripeAccount->status = 'rejected';
            $userStripeAccount->save();
        }
    }
}