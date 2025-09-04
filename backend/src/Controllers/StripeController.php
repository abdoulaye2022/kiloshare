<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use KiloShare\Models\User;
use KiloShare\Models\UserStripeAccount;
use KiloShare\Models\Booking;
use KiloShare\Models\EscrowAccount;
use KiloShare\Models\Transaction;
use KiloShare\Utils\Response;
use Stripe\Stripe;
use Stripe\Account;
use Stripe\AccountLink;
use Stripe\PaymentIntent;
use Stripe\PaymentMethod;
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

    /**
     * Créer un Payment Intent pour une réservation
     */
    public function createPaymentIntent(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            
            // Lire le body JSON correctement
            $rawBody = $request->getBody()->getContents();
            $data = json_decode($rawBody, true);
            
            // Debug temporaire
            error_log("StripeController.createPaymentIntent - Raw body: " . $rawBody);
            error_log("StripeController.createPaymentIntent - Parsed data: " . json_encode($data));
            
            // Fallback si le JSON parsing échoue
            if ($data === null) {
                $data = $request->getParsedBody() ?: [];
                error_log("StripeController.createPaymentIntent - Fallback to getParsedBody: " . json_encode($data));
            }
            
            $bookingId = $data['booking_id'] ?? null;

            // Validation plus stricte
            if (!$bookingId || $bookingId === 0 || $bookingId === '0' || empty($bookingId)) {
                error_log("StripeController.createPaymentIntent - BookingId is missing, null, zero or empty: " . var_export($bookingId, true));
                return Response::error('Booking ID requis et doit être valide', [], 400);
            }

            // S'assurer que c'est un entier
            $bookingId = (int) $bookingId;
            if ($bookingId <= 0) {
                error_log("StripeController.createPaymentIntent - BookingId must be positive integer: " . $bookingId);
                return Response::error('Booking ID doit être un entier positif', [], 400);
            }

            // Récupérer la réservation
            $booking = Booking::with(['trip.user', 'sender', 'receiver'])
                ->where('id', $bookingId)
                ->first();

            if (!$booking) {
                return Response::error('Réservation non trouvée', [], 404);
            }

            // Vérifier que l'utilisateur est l'expéditeur
            if ($booking->sender_id !== $user->id) {
                return Response::error('Non autorisé - vous devez être l\'expéditeur', [], 403);
            }

            // Vérifier que la réservation est confirmée mais pas encore payée
            if ($booking->status !== Booking::STATUS_CONFIRMED) {
                return Response::error('La réservation doit être confirmée pour procéder au paiement', [], 400);
            }

            if ($booking->payment_status === 'paid') {
                return Response::error('Cette réservation a déjà été payée', [], 400);
            }

            // Vérifier que le voyageur a un compte Stripe actif
            $receiverStripeAccount = UserStripeAccount::where('user_id', $booking->receiver_id)->first();
            if (!$receiverStripeAccount || !$receiverStripeAccount->canAcceptPayments()) {
                return Response::error('Le voyageur doit configurer son compte Stripe pour recevoir les paiements', [], 400);
            }

            // Calculer les montants
            $finalPrice = $booking->final_price ?? $booking->proposed_price;
            $commissionRate = $booking->commission_rate ?? 15.00;
            $commissionAmount = ($finalPrice * $commissionRate) / 100;
            $amount = (int)($finalPrice * 100); // Montant en centimes pour Stripe

            Stripe::setApiKey($_ENV['STRIPE_SECRET_KEY']);

            // Créer le Payment Intent
            $paymentIntent = PaymentIntent::create([
                'amount' => $amount,
                'currency' => 'cad',
                'automatic_payment_methods' => ['enabled' => true],
                'metadata' => [
                    'booking_id' => $booking->id,
                    'sender_id' => $booking->sender_id,
                    'receiver_id' => $booking->receiver_id,
                    'trip_id' => $booking->trip_id,
                    'commission_amount' => $commissionAmount,
                ],
                'description' => "KiloShare - Transport de {$booking->package_description} de {$booking->trip->departure_city} à {$booking->trip->arrival_city}",
            ]);

            // Mettre à jour la réservation
            $booking->update([
                'payment_status' => 'pending',
                'commission_amount' => $commissionAmount
            ]);

            return Response::success([
                'client_secret' => $paymentIntent->client_secret,
                'payment_intent_id' => $paymentIntent->id,
                'amount' => $finalPrice,
                'commission_amount' => $commissionAmount,
                'net_amount' => $finalPrice - $commissionAmount
            ], 'Payment Intent créé avec succès');

        } catch (Exception $e) {
            error_log("Erreur création Payment Intent: " . $e->getMessage());
            return Response::error('Erreur lors de la création du paiement', [], 500);
        }
    }

    /**
     * Confirmer le paiement et créer l'escrow
     */
    public function confirmPayment(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            
            // Lire le body JSON correctement
            $rawBody = $request->getBody()->getContents();
            $data = json_decode($rawBody, true);
            
            // Debug: Log received data
            error_log('StripeController.confirmPayment - Raw body: ' . $rawBody);
            error_log('StripeController.confirmPayment - Parsed data: ' . json_encode($data));
            
            // Fallback si le JSON parsing échoue
            if ($data === null) {
                $data = $request->getParsedBody() ?: [];
                error_log('StripeController.confirmPayment - Fallback to getParsedBody: ' . json_encode($data));
            }
            
            $paymentIntentId = $data['payment_intent_id'] ?? null;
            $bookingId = $data['booking_id'] ?? null;

            if (!$paymentIntentId || !$bookingId) {
                error_log("StripeController.confirmPayment - Missing params: payment_intent_id=$paymentIntentId, booking_id=$bookingId");
                return Response::error('Payment Intent ID et Booking ID requis', [], 400);
            }

            Stripe::setApiKey($_ENV['STRIPE_SECRET_KEY']);

            // Récupérer le Payment Intent depuis Stripe
            try {
                $paymentIntent = PaymentIntent::retrieve($paymentIntentId);
                
                if ($paymentIntent->status !== 'succeeded') {
                    error_log("StripeController.confirmPayment - Payment status: " . $paymentIntent->status);
                    return Response::error('Le paiement n\'a pas abouti', [], 400);
                }
                
                error_log("StripeController.confirmPayment - PaymentIntent retrieved successfully: " . $paymentIntentId);
            } catch (\Exception $e) {
                error_log("StripeController.confirmPayment - Error retrieving PaymentIntent: " . $e->getMessage());
                return Response::error('Erreur lors de la récupération du Payment Intent: ' . $e->getMessage(), [], 500);
            }

            // Récupérer la réservation
            $booking = Booking::with(['trip', 'sender', 'receiver'])
                ->where('id', $bookingId)
                ->first();

            if (!$booking) {
                return Response::error('Réservation non trouvée', [], 404);
            }

            // Vérifier que l'utilisateur est l'expéditeur
            if ($booking->sender_id !== $user->id) {
                return Response::error('Non autorisé', [], 403);
            }

            // Créer la transaction
            $transaction = Transaction::create([
                'user_id' => $booking->sender_id,
                'booking_id' => $booking->id,
                'amount' => $paymentIntent->amount / 100, // Convertir en dollars
                'currency' => $paymentIntent->currency,
                'stripe_payment_intent_id' => $paymentIntentId,
                'status' => 'completed',
                'type' => 'payment'
            ]);

            // Calculer ou récupérer la commission
            $commissionAmount = $booking->commission_amount;
            if ($commissionAmount === null) {
                // Calculer la commission si elle n'est pas définie (15% par défaut)
                $commissionRate = $booking->commission_rate ?? 15.00;
                $totalAmount = $paymentIntent->amount / 100;
                $commissionAmount = $totalAmount * ($commissionRate / 100);
                
                // Mettre à jour la réservation avec le montant de commission calculé
                $booking->commission_amount = $commissionAmount;
                $booking->save();
            }

            // Créer l'escrow account
            $escrowAmount = ($paymentIntent->amount / 100) - $commissionAmount;
            EscrowAccount::create([
                'transaction_id' => $transaction->id,
                'amount_held' => $escrowAmount,
                'hold_reason' => 'delivery_confirmation',
                'status' => 'holding'
            ]);

            // Mettre à jour la réservation
            $booking->update([
                'payment_status' => 'paid',
                'status' => Booking::STATUS_PAID
            ]);

            // Mettre à jour le voyage
            $booking->trip->update([
                'status' => 'booked'
            ]);

            return Response::success('Paiement confirmé et fonds mis en escrow', [
                'transaction_id' => $transaction->id,
                'escrow_amount' => $escrowAmount,
                'commission_amount' => $booking->commission_amount
            ]);

        } catch (Exception $e) {
            error_log("Erreur confirmation paiement: " . $e->getMessage());
            return Response::error('Erreur lors de la confirmation du paiement', [], 500);
        }
    }

    /**
     * Libérer les fonds de l'escrow (après livraison)
     */
    public function releaseEscrow(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            $bookingId = $request->getAttribute('booking_id');

            // Récupérer la réservation
            $booking = Booking::with(['trip.user', 'escrowAccount.transaction'])
                ->where('id', $bookingId)
                ->first();

            if (!$booking) {
                return Response::error('Réservation non trouvée', [], 404);
            }

            // Vérifier les permissions (expéditeur ou admin)
            if ($booking->sender_id !== $user->id && !$user->is_admin) {
                return Response::error('Non autorisé', [], 403);
            }

            // Vérifier que la livraison est confirmée
            if ($booking->status !== Booking::STATUS_DELIVERED) {
                return Response::error('La livraison doit être confirmée avant la libération des fonds', [], 400);
            }

            // Récupérer l'escrow account
            $escrowAccount = EscrowAccount::where('transaction_id', $booking->escrowAccount->transaction->id)
                ->where('status', 'holding')
                ->first();

            if (!$escrowAccount) {
                return Response::error('Aucun escrow actif trouvé pour cette réservation', [], 404);
            }

            // Libérer les fonds (ici on marque comme libéré, l'intégration Stripe Connect se ferait séparément)
            $escrowAccount->update([
                'status' => 'fully_released',
                'amount_released' => $escrowAccount->amount_held,
                'released_at' => now(),
                'release_notes' => 'Livraison confirmée - fonds libérés automatiquement'
            ]);

            // Mettre à jour la réservation
            $booking->update([
                'status' => Booking::STATUS_COMPLETED
            ]);

            return Response::success('Fonds libérés avec succès', [
                'amount_released' => $escrowAccount->amount_held,
                'released_to_traveler' => $booking->receiver_id
            ]);

        } catch (Exception $e) {
            error_log("Erreur libération escrow: " . $e->getMessage());
            return Response::error('Erreur lors de la libération des fonds', [], 500);
        }
    }
}