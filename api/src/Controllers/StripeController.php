<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use KiloShare\Models\User;
use KiloShare\Models\UserStripeAccount;
use KiloShare\Models\Booking;
use KiloShare\Models\BookingNegotiation;
use KiloShare\Models\Trip;
use KiloShare\Models\EscrowAccount;
use KiloShare\Models\Transaction;
use KiloShare\Models\VerificationCode;
use KiloShare\Services\SmartNotificationService;
use KiloShare\Utils\Response;
use Stripe\Stripe;
use Stripe\Account;
use Stripe\AccountLink;
use Stripe\PaymentIntent;
use Stripe\PaymentMethod;
use Exception;

class StripeController
{
    private SmartNotificationService $notificationService;

    public function __construct()
    {
        // Initialize Stripe with secret key
        Stripe::setApiKey($_ENV['STRIPE_SECRET_KEY']);
        $this->notificationService = new SmartNotificationService();
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
     * Confirmer le paiement et exécuter le workflow complet post-paiement
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

            // Récupérer la réservation avec toutes les relations nécessaires
            $booking = Booking::with(['trip', 'sender', 'receiver', 'negotiation'])
                ->where('id', $bookingId)
                ->first();

            if (!$booking) {
                return Response::error('Réservation non trouvée', [], 404);
            }

            // Vérifier que l'utilisateur est l'expéditeur
            if ($booking->sender_id !== $user->id) {
                return Response::error('Non autorisé', [], 403);
            }

            // Vérifier que le paiement n'a pas déjà été confirmé
            if ($booking->payment_status === 'paid') {
                return Response::error('Cette réservation a déjà été payée', [], 400);
            }

            // ÉTAPE 1: Calculer les montants
            $commissionAmount = $booking->commission_amount;
            if ($commissionAmount === null) {
                $commissionRate = $booking->commission_rate ?? 15.00;
                $totalAmount = $paymentIntent->amount / 100;
                $commissionAmount = $totalAmount * ($commissionRate / 100);
                
                $booking->commission_amount = $commissionAmount;
                $booking->save();
            }

            $totalAmount = $paymentIntent->amount / 100;
            $receiverAmount = $totalAmount - $commissionAmount;

            // ÉTAPE 2: Créer la transaction de paiement reçu
            $transaction = Transaction::create([
                'booking_id' => $booking->id,
                'amount' => $totalAmount,
                'commission' => $commissionAmount,
                'receiver_amount' => $receiverAmount,
                'currency' => $paymentIntent->currency,
                'stripe_payment_intent_id' => $paymentIntentId,
                'status' => 'succeeded'
            ]);

            // ÉTAPE 3: Créer l'escrow account avec statut 'holding' (argent retenu)
            EscrowAccount::create([
                'transaction_id' => $transaction->id,
                'amount_held' => $receiverAmount,
                'hold_reason' => 'delivery_confirmation',
                'status' => 'holding'
            ]);

            // ÉTAPE 4: Mettre à jour le statut de la réservation
            $booking->update([
                'payment_status' => 'paid',
                'status' => Booking::STATUS_PAID
            ]);

            // ÉTAPE 5: Mettre à jour la négociation associée (si elle existe)
            if ($booking->negotiation) {
                $booking->negotiation->update(['status' => 'completed']);
            }

            // ÉTAPE 6: Gérer la mise à jour du voyage et du poids disponible
            $trip = $booking->trip;
            $this->updateTripAfterPayment($trip, $booking);

            // ÉTAPE 7: Générer les codes de vérification
            $this->generateVerificationCodes($booking);

            // ÉTAPE 8: Envoyer les notifications
            $this->sendPaymentNotifications($booking);

            // ÉTAPE 9: Mettre à jour les tables de résumé
            $this->updateSummaryTables($booking, $trip);

            error_log("StripeController.confirmPayment - Payment workflow completed successfully for booking: " . $bookingId);

            return Response::success([
                'transaction_id' => $transaction->id,
                'escrow_amount' => $receiverAmount,
                'commission_amount' => $commissionAmount,
                'trip_status' => $trip->fresh()->status,
                'remaining_weight' => $trip->fresh()->available_weight_kg,
                'verification_codes_generated' => true
            ], 'Paiement confirmé et workflow post-paiement exécuté avec succès');

        } catch (Exception $e) {
            error_log("Erreur confirmation paiement: " . $e->getMessage());
            error_log("Stack trace: " . $e->getTraceAsString());
            return Response::error('Erreur lors de la confirmation du paiement', [], 500);
        }
    }

    /**
     * Met à jour le voyage après un paiement confirmé
     */
    private function updateTripAfterPayment(Trip $trip, Booking $booking): void
    {
        // Soustraire le poids réservé du poids disponible
        $newAvailableWeight = max(0, $trip->available_weight_kg - $booking->weight_kg);
        
        // Calculer le poids total réservé
        $totalBookedWeight = $trip->bookings()
            ->whereIn('status', [Booking::STATUS_PAID, Booking::STATUS_IN_TRANSIT, Booking::STATUS_DELIVERED])
            ->sum('weight_kg');

        // Déterminer le nouveau statut
        if ($newAvailableWeight <= 0) {
            // Plus de place disponible - marquer comme complet
            $newStatus = 'booked';
        } else {
            // Il reste de la place - garder le voyage actif et visible
            $newStatus = 'active';
        }

        // Mettre à jour le voyage
        $trip->update([
            'available_weight_kg' => $newAvailableWeight,
            'total_booked_weight' => $totalBookedWeight,
            'status' => $newStatus
        ]);

        error_log("Trip {$trip->id} updated: available_weight={$newAvailableWeight}, total_booked={$totalBookedWeight}, status={$newStatus}");
    }

    /**
     * Génère les codes de vérification pickup et delivery
     */
    private function generateVerificationCodes(Booking $booking): array
    {
        $codes = [];
        
        try {
            // Générer le code pickup (6 chiffres) pour le voyageur
            $pickupVerification = VerificationCode::generate(
                $booking->receiver_id,
                VerificationCode::TYPE_PICKUP_CODE,
                6,
                $booking->id
            );

            // Générer le code delivery (6 chiffres) pour l'expéditeur  
            $deliveryVerification = VerificationCode::generate(
                $booking->sender_id,
                VerificationCode::TYPE_DELIVERY_CODE,
                6,
                $booking->id
            );

            $codes = [
                'pickup' => $pickupVerification->code,
                'delivery' => $deliveryVerification->code
            ];
            
            error_log("Generated verification codes for booking {$booking->id}: pickup={$pickupVerification->code}, delivery={$deliveryVerification->code}");
            
        } catch (Exception $e) {
            error_log("Error generating verification codes: " . $e->getMessage());
            // Return empty codes if generation fails
            $codes = ['pickup' => null, 'delivery' => null];
        }

        return $codes;
    }

    /**
     * Met à jour les tables de résumé pour maintenir la cohérence
     */
    private function updateSummaryTables(Booking $booking, Trip $trip): void
    {
        try {
            // Mettre à jour trip_status_summary
            \Illuminate\Support\Facades\DB::statement("
                INSERT INTO trip_status_summary (status, count, last_updated) 
                VALUES (?, 1, NOW()) 
                ON DUPLICATE KEY UPDATE 
                count = count + 1, 
                last_updated = NOW()
            ", [$trip->status]);

            // Mettre à jour booking_summary
            \Illuminate\Support\Facades\DB::statement("
                INSERT INTO booking_summary (status, count, last_updated) 
                VALUES (?, 1, NOW()) 
                ON DUPLICATE KEY UPDATE 
                count = count + 1, 
                last_updated = NOW()
            ", [$booking->status]);

            // Mettre à jour active_trips_overview
            \Illuminate\Support\Facades\DB::statement("
                UPDATE active_trips_overview 
                SET booked_trips = (
                    SELECT COUNT(*) FROM trips WHERE status = 'booked'
                ), 
                last_updated = NOW()
            ");

            error_log("Summary tables updated successfully for booking {$booking->id}");
            
        } catch (Exception $e) {
            error_log("Error updating summary tables: " . $e->getMessage());
        }
    }

    /**
     * Valider le code pickup et marquer le début du voyage
     */
    public function validatePickupCode(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            
            $rawBody = $request->getBody()->getContents();
            $data = json_decode($rawBody, true);
            
            $code = $data['code'] ?? null;
            $bookingId = $data['booking_id'] ?? null;

            if (!$code || !$bookingId) {
                return Response::error('Code et booking ID requis', [], 400);
            }

            // Vérifier le code pickup
            $verification = VerificationCode::verify($code, VerificationCode::TYPE_PICKUP_CODE, $bookingId);
            
            if (!$verification) {
                return Response::error('Code pickup invalide ou expiré', [], 400);
            }

            // Récupérer la réservation
            $booking = Booking::with(['trip', 'sender', 'receiver'])
                ->where('id', $bookingId)
                ->first();

            if (!$booking) {
                return Response::error('Réservation non trouvée', [], 404);
            }

            // Vérifier que l'utilisateur est le voyageur (receiver)
            if ($booking->receiver_id !== $user->id) {
                return Response::error('Non autorisé - vous devez être le voyageur', [], 403);
            }

            // Marquer le code comme utilisé
            $verification->markAsUsed();

            // Mettre à jour le statut de la réservation
            $booking->update(['status' => Booking::STATUS_IN_TRANSIT]);

            // Vérifier si c'est la première réservation à commencer pour ce voyage
            $trip = $booking->trip;
            $hasOtherActiveBookings = $trip->bookings()
                ->whereIn('status', [Booking::STATUS_IN_TRANSIT, Booking::STATUS_DELIVERED])
                ->where('id', '!=', $booking->id)
                ->exists();

            // Si c'est la première réservation active, marquer le voyage comme en cours
            if (!$hasOtherActiveBookings) {
                $trip->update(['status' => Trip::STATUS_IN_PROGRESS]);
            }

            return Response::success([
                'booking_status' => $booking->status,
                'trip_status' => $trip->fresh()->status,
                'message' => 'Code pickup validé - voyage commencé'
            ], 'Pickup confirmé avec succès');

        } catch (Exception $e) {
            error_log("Erreur validation pickup: " . $e->getMessage());
            return Response::error('Erreur lors de la validation du pickup', [], 500);
        }
    }

    /**
     * Valider le code delivery et marquer la livraison
     */
    public function validateDeliveryCode(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $user = $request->getAttribute('user');
            
            $rawBody = $request->getBody()->getContents();
            $data = json_decode($rawBody, true);
            
            $code = $data['code'] ?? null;
            $bookingId = $data['booking_id'] ?? null;

            if (!$code || !$bookingId) {
                return Response::error('Code et booking ID requis', [], 400);
            }

            // Vérifier le code delivery
            $verification = VerificationCode::verify($code, VerificationCode::TYPE_DELIVERY_CODE, $bookingId);
            
            if (!$verification) {
                return Response::error('Code delivery invalide ou expiré', [], 400);
            }

            // Récupérer la réservation
            $booking = Booking::with(['trip', 'sender', 'receiver'])
                ->where('id', $bookingId)
                ->first();

            if (!$booking) {
                return Response::error('Réservation non trouvée', [], 404);
            }

            // Vérifier que l'utilisateur est l'expéditeur (sender)
            if ($booking->sender_id !== $user->id) {
                return Response::error('Non autorisé - vous devez être l\'expéditeur', [], 403);
            }

            // Vérifier que la réservation est en transit
            if ($booking->status !== Booking::STATUS_IN_TRANSIT) {
                return Response::error('La réservation doit être en transit pour confirmer la livraison', [], 400);
            }

            // Marquer le code comme utilisé
            $verification->markAsUsed();

            // Mettre à jour le statut de la réservation
            $booking->update([
                'status' => Booking::STATUS_DELIVERED,
                'delivery_date' => now()
            ]);

            // Libérer les fonds automatiquement
            $this->processEscrowRelease($booking);

            // Vérifier si toutes les réservations du voyage sont livrées
            $trip = $booking->trip;
            $this->checkTripCompletion($trip);

            return Response::success([
                'booking_status' => $booking->status,
                'trip_status' => $trip->fresh()->status,
                'escrow_released' => true,
                'message' => 'Livraison confirmée - fonds libérés'
            ], 'Delivery confirmé avec succès');

        } catch (Exception $e) {
            error_log("Erreur validation delivery: " . $e->getMessage());
            return Response::error('Erreur lors de la validation de la livraison', [], 500);
        }
    }

    /**
     * Libérer les fonds de l'escrow automatiquement après livraison
     */
    private function processEscrowRelease(Booking $booking): void
    {
        try {
            // Récupérer le compte escrow pour cette réservation
            $escrowAccount = EscrowAccount::whereHas('transaction', function($query) use ($booking) {
                $query->where('booking_id', $booking->id);
            })->where('status', 'holding')->first();

            if (!$escrowAccount) {
                error_log("No escrow account found for booking {$booking->id}");
                return;
            }

            // Marquer l'escrow comme libéré
            $escrowAccount->update([
                'status' => 'fully_released',
                'amount_released' => $escrowAccount->amount_held,
                'released_at' => now(),
                'release_notes' => 'Livraison confirmée automatiquement'
            ]);

            // Créer une transaction de payout vers le voyageur
            Transaction::create([
                'booking_id' => $booking->id,
                'amount' => $escrowAccount->amount_released,
                'commission' => 0, // Commission déjà déduite
                'receiver_amount' => $escrowAccount->amount_released,
                'currency' => 'cad',
                'status' => 'succeeded',
                'processed_at' => now()
            ]);

            error_log("Escrow released successfully for booking {$booking->id}: {$escrowAccount->amount_released}");

        } catch (Exception $e) {
            error_log("Error releasing escrow for booking {$booking->id}: " . $e->getMessage());
        }
    }

    /**
     * Vérifier si le voyage est terminé (toutes livraisons effectuées)
     */
    private function checkTripCompletion(Trip $trip): void
    {
        // Compter les réservations non livrées
        $undeliveredCount = $trip->bookings()
            ->whereIn('status', [
                Booking::STATUS_PAID,
                Booking::STATUS_IN_TRANSIT,
                Booking::STATUS_IN_PROGRESS
            ])
            ->count();

        // Si toutes les réservations sont livrées, marquer le voyage comme terminé
        if ($undeliveredCount === 0) {
            $trip->update([
                'status' => Trip::STATUS_COMPLETED,
                'completed_at' => now()
            ]);

            error_log("Trip {$trip->id} marked as completed - all deliveries finished");
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

    /**
     * Envoyer les notifications après un paiement réussi
     */
    private function sendPaymentNotifications(Booking $booking): void
    {
        try {
            // Notification au receiver (propriétaire du voyage) - paiement reçu
            $this->notificationService->send(
                $booking->receiver_id,
                'payment_received',
                [
                    'amount' => $booking->final_price,
                    'sender_name' => $booking->sender->first_name . ' ' . $booking->sender->last_name
                ]
            );

            // Récupérer le pickup code pour la notification
            $pickupCode = VerificationCode::where('booking_id', $booking->id)
                                         ->where('type', VerificationCode::TYPE_PICKUP_CODE)
                                         ->first()?->code ?? 'N/A';

            // Notification au sender (expéditeur) - confirmation de paiement
            $this->notificationService->send(
                $booking->sender_id,
                'payment_confirmed',
                [
                    'amount' => $booking->final_price,
                    'pickup_code' => $pickupCode
                ]
            );

            error_log("Payment notifications sent successfully for booking: " . $booking->id);
        } catch (\Exception $e) {
            error_log("Error sending payment notifications: " . $e->getMessage());
        }
    }
}