<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\PaymentAuthorization;
use KiloShare\Models\PaymentEventLog;
use KiloShare\Models\ScheduledJob;
use KiloShare\Models\Booking;
use KiloShare\Models\User;
use KiloShare\Models\Transaction;
use KiloShare\Models\UserStripeAccount;
use KiloShare\Services\SmartNotificationService;
use Stripe\StripeClient;
use Stripe\PaymentIntent;
use Stripe\Exception\StripeException;
use Carbon\Carbon;

class PaymentAuthorizationService
{
    private StripeClient $stripe;
    private ?SmartNotificationService $notificationService = null;
    private ?PaymentConfigurationService $configService = null;

    public function __construct()
    {
        // Initialiser Stripe avec la clé secrète
        $this->stripe = new StripeClient($_ENV['STRIPE_SECRET_KEY']);

        // Les autres services seront initialisés à la demande
        // pour éviter les dépendances circulaires
    }

    private function getNotificationService(): SmartNotificationService
    {
        if ($this->notificationService === null) {
            $this->notificationService = new SmartNotificationService();
        }
        return $this->notificationService;
    }

    private function getConfigService(): PaymentConfigurationService
    {
        if ($this->configService === null) {
            $this->configService = new PaymentConfigurationService();
        }
        return $this->configService;
    }

    /**
     * Créer une autorisation de paiement avec PaymentIntent manuel
     */
    public function createAuthorization(Booking $booking, User $sender): PaymentAuthorization
    {
        $startTime = microtime(true);

        try {
            // Calculer les montants
            $totalAmount = $booking->total_price;
            $amountCents = (int) ($totalAmount * 100);
            $platformFeeCents = $this->calculatePlatformFee($amountCents);

            // Vérifier le compte Stripe du transporteur
            $stripeAccountId = $this->getTransporterStripeAccount($booking);
            $hasStripeAccount = !empty($stripeAccountId);

            $paymentIntentId = null;
            $authorizationStatus = PaymentAuthorization::STATUS_PENDING;

            if ($hasStripeAccount) {
                // Créer le PaymentIntent avec capture manuelle
                $paymentIntent = $this->createStripePaymentIntent(
                    $amountCents,
                    $platformFeeCents,
                    $stripeAccountId,
                    $booking,
                    $sender
                );
                $paymentIntentId = $paymentIntent->id;
            } else {
                // Pas de compte Stripe - autorisation en attente de configuration
                $authorizationStatus = PaymentAuthorization::STATUS_PENDING_STRIPE_CONFIG;
            }

            // Créer l'autorisation en base
            $authorization = PaymentAuthorization::create([
                'booking_id' => $booking->id,
                'payment_intent_id' => $paymentIntentId,
                'stripe_account_id' => $stripeAccountId,
                'amount_cents' => $amountCents,
                'currency' => 'CAD',
                'platform_fee_cents' => $platformFeeCents,
                'status' => $authorizationStatus,
            ]);

            // Créer la transaction associée
            $this->createTransaction($authorization, Transaction::TYPE_PAYMENT_AUTHORIZATION);

            // Mettre à jour le statut de la réservation
            $bookingStatus = $hasStripeAccount ? Booking::STATUS_PAYMENT_AUTHORIZED : Booking::STATUS_ACCEPTED;
            $booking->update([
                'status' => $bookingStatus,
                'payment_authorization_id' => $authorization->id,
                'payment_authorized_at' => $hasStripeAccount ? Carbon::now() : null,
            ]);

            // Programmer les jobs de gestion automatique seulement si le PaymentIntent existe
            if ($hasStripeAccount) {
                $this->scheduleManagementJobs($authorization);
            }

            // Logger l'événement
            $processingTime = (int) ((microtime(true) - $startTime) * 1000);
            PaymentEventLog::logAuthorizationCreated($authorization, $sender, [
                'payment_intent_id' => $paymentIntentId,
                'amount_cents' => $amountCents,
                'platform_fee_cents' => $platformFeeCents,
                'processing_time_ms' => $processingTime,
                'has_stripe_account' => $hasStripeAccount,
            ]);

            // Envoyer notification appropriée
            if ($hasStripeAccount) {
                $this->getNotificationService()->sendPaymentAuthorizationNotification($authorization, $sender);
            } else {
                // Notifier que le compte Stripe doit être configuré
                $this->getNotificationService()->sendStripeAccountRequiredNotification($authorization, $booking->trip->user);
            }

            return $authorization;

        } catch (StripeException $e) {
            // Logger l'erreur
            PaymentEventLog::create([
                'booking_id' => $booking->id,
                'user_id' => $sender->id,
                'event_type' => PaymentEventLog::EVENT_AUTHORIZATION_CREATED,
                'success' => false,
                'error_message' => $e->getMessage(),
                'event_data' => [
                    'stripe_error_type' => $e->getStripeCode(),
                    'amount_cents' => $amountCents ?? null,
                ],
            ]);

            throw new \Exception("Échec de création de l'autorisation de paiement: " . $e->getMessage());
        }
    }

    /**
     * Confirmer une autorisation de paiement après confirmation client Stripe
     */
    public function confirmAuthorization(PaymentAuthorization $authorization, User $user): bool
    {
        $startTime = microtime(true);

        if (!$authorization->canBeConfirmed()) {
            throw new \Exception('Cette autorisation ne peut plus être confirmée');
        }

        if ($authorization->booking->sender_id !== $user->id) {
            throw new \Exception('Seul l\'expéditeur peut confirmer le paiement');
        }

        try {
            // Récupérer le PaymentIntent pour vérifier son statut
            $paymentIntent = $this->stripe->paymentIntents->retrieve($authorization->payment_intent_id);

            if ($paymentIntent->status !== 'requires_capture') {
                throw new \Exception('Le paiement n\'est pas dans l\'état requis pour la capture. Statut actuel: ' . $paymentIntent->status);
            }

            // Mettre à jour l'autorisation
            $authorization->confirm();

            // Mettre à jour la réservation
            $authorization->booking->update([
                'status' => Booking::STATUS_PAYMENT_CONFIRMED,
                'payment_confirmed_at' => Carbon::now(),
            ]);

            // Créer une transaction de confirmation
            $this->createTransaction($authorization, Transaction::TYPE_PAYMENT_CAPTURE, Transaction::STATUS_CONFIRMED);

            // Programmer la capture automatique et annuler les rappels de confirmation
            $this->rescheduleJobsAfterConfirmation($authorization);

            // Logger l'événement
            $processingTime = (int) ((microtime(true) - $startTime) * 1000);
            PaymentEventLog::logAuthorizationConfirmed($authorization, $user, [
                'payment_intent_status' => $paymentIntent->status,
                'processing_time_ms' => $processingTime,
            ]);

            // Notifier les parties
            $this->getNotificationService()->sendPaymentConfirmedNotification($authorization);

            return true;

        } catch (StripeException $e) {
            PaymentEventLog::logCaptureFailed($authorization, $e->getMessage(), [
                'action' => 'confirm',
                'stripe_error_type' => $e->getStripeCode(),
            ]);

            throw new \Exception("Échec de confirmation du paiement: " . $e->getMessage());
        }
    }

    /**
     * Capturer un paiement (manuelle ou automatique)
     */
    public function capturePayment(PaymentAuthorization $authorization, string $reason = PaymentAuthorization::CAPTURE_REASON_MANUAL): bool
    {
        $startTime = microtime(true);

        if (!$authorization->canBeCaptured()) {
            throw new \Exception('Ce paiement ne peut plus être capturé');
        }

        try {
            // Capturer via Stripe
            $paymentIntent = $this->stripe->paymentIntents->capture(
                $authorization->payment_intent_id,
                ['amount_to_capture' => $authorization->amount_cents]
            );

            if ($paymentIntent->status !== 'succeeded') {
                throw new \Exception('La capture a échoué côté Stripe');
            }

            // Mettre à jour l'autorisation
            $authorization->capture($reason);

            // Mettre à jour la réservation
            $authorization->booking->update([
                'status' => Booking::STATUS_PAID,
                'payment_captured_at' => Carbon::now(),
            ]);

            // Mettre à jour la transaction
            $transaction = $authorization->transactions()
                ->where('type', Transaction::TYPE_PAYMENT_CAPTURE)
                ->first();

            if ($transaction) {
                $transaction->update([
                    'status' => Transaction::STATUS_CAPTURED,
                    'captured_at' => Carbon::now(),
                ]);
            }

            // Annuler tous les jobs en attente pour cette autorisation
            $this->cancelPendingJobs($authorization);

            // Logger l'événement
            $processingTime = (int) ((microtime(true) - $startTime) * 1000);
            PaymentEventLog::logCaptureSucceeded($authorization, [
                'capture_reason' => $reason,
                'amount_captured' => $authorization->amount_cents,
                'processing_time_ms' => $processingTime,
            ]);

            // Notifier les parties
            $this->getNotificationService()->sendPaymentCapturedNotification($authorization);

            return true;

        } catch (StripeException $e) {
            // Marquer l'autorisation comme échec de capture
            $authorization->markAsFailed($e->getMessage());

            PaymentEventLog::logCaptureFailed($authorization, $e->getMessage(), [
                'capture_reason' => $reason,
                'stripe_error_type' => $e->getStripeCode(),
            ]);

            // Programmer un retry si possible
            if ($authorization->capture_attempts < 3) {
                $this->scheduleRetryCapture($authorization, $reason);
            }

            throw new \Exception("Échec de capture du paiement: " . $e->getMessage());
        }
    }

    /**
     * Annuler une autorisation de paiement
     */
    public function cancelAuthorization(PaymentAuthorization $authorization, ?User $user = null, ?string $reason = null): bool
    {
        if (!$authorization->canBeCancelled()) {
            throw new \Exception('Cette autorisation ne peut plus être annulée');
        }

        try {
            // Annuler le PaymentIntent côté Stripe
            $this->stripe->paymentIntents->cancel($authorization->payment_intent_id);

            // Mettre à jour l'autorisation
            $authorization->cancel();

            // Mettre à jour la réservation
            $authorization->booking->update([
                'status' => Booking::STATUS_PAYMENT_CANCELLED,
            ]);

            // Annuler tous les jobs en attente
            $this->cancelPendingJobs($authorization, 'Authorization cancelled');

            // Logger l'événement
            PaymentEventLog::logAuthorizationCancelled($authorization, $user, [
                'reason' => $reason,
                'cancelled_by_user' => $user ? true : false,
            ]);

            // Notifier les parties
            $this->getNotificationService()->sendPaymentCancelledNotification($authorization, $reason);

            return true;

        } catch (StripeException $e) {
            throw new \Exception("Échec d'annulation du paiement: " . $e->getMessage());
        }
    }

    /**
     * Gérer l'expiration d'une autorisation
     */
    public function expireAuthorization(PaymentAuthorization $authorization): bool
    {
        if (!$authorization->isConfirmationExpired() && !$authorization->isCaptureExpired()) {
            return false;
        }

        try {
            // Annuler le PaymentIntent côté Stripe
            $this->stripe->paymentIntents->cancel($authorization->payment_intent_id);

            // Marquer comme expiré
            $authorization->expire();

            // Mettre à jour la réservation
            $authorization->booking->update([
                'status' => Booking::STATUS_PAYMENT_EXPIRED,
            ]);

            // Annuler tous les jobs en attente
            $this->cancelPendingJobs($authorization, 'Authorization expired');

            // Logger l'événement
            PaymentEventLog::logAuthorizationExpired($authorization, [
                'expiry_type' => $authorization->isPending() ? 'confirmation' : 'capture',
            ]);

            // Notifier les parties
            $this->getNotificationService()->sendPaymentExpiredNotification($authorization);

            return true;

        } catch (StripeException $e) {
            // Même si Stripe échoue, on marque comme expiré en local
            $authorization->expire();
            return false;
        }
    }

    /**
     * Créer un PaymentIntent Stripe avec capture manuelle
     */
    private function createStripePaymentIntent(
        int $amountCents,
        int $platformFeeCents,
        string $stripeAccountId,
        Booking $booking,
        User $sender
    ): PaymentIntent {
        $applicationFeeCents = $platformFeeCents;

        return $this->stripe->paymentIntents->create([
            'amount' => $amountCents,
            'currency' => 'cad',
            'capture_method' => 'manual', // Capture différée
            'confirmation_method' => 'automatic', // Confirmation automatique côté client
            'application_fee_amount' => $applicationFeeCents,
            'transfer_data' => [
                'destination' => $stripeAccountId,
            ],
            'metadata' => [
                'booking_id' => $booking->id,
                'sender_id' => $sender->id,
                'trip_id' => $booking->trip_id,
                'type' => 'booking_payment',
                'platform' => 'kiloshare',
            ],
            'description' => "Transport de {$booking->package_description} - Réservation #{$booking->id}",
        ]);
    }

    /**
     * Créer une transaction associée à l'autorisation
     */
    private function createTransaction(
        PaymentAuthorization $authorization,
        string $type,
        string $status = Transaction::STATUS_AUTHORIZED
    ): Transaction {
        return Transaction::create([
            'booking_id' => $authorization->booking_id,
            'payment_authorization_id' => $authorization->id,
            'type' => $type,
            'amount' => $authorization->getAmountInDollars(),
            'commission' => $authorization->getPlatformFeeInDollars(),
            'receiver_amount' => $authorization->getAmountInDollars() - $authorization->getPlatformFeeInDollars(),
            'currency' => $authorization->currency,
            'status' => $status,
            'payment_method' => 'stripe',
            'stripe_payment_intent_id' => $authorization->payment_intent_id,
            'authorized_at' => Carbon::now(),
        ]);
    }

    /**
     * Programmer les jobs de gestion automatique
     */
    private function scheduleManagementJobs(PaymentAuthorization $authorization): void
    {
        // Job d'expiration de confirmation
        ScheduledJob::schedulePaymentExpiry($authorization);

        // Job de rappel de confirmation
        if ($this->getConfigService()->get('send_confirmation_reminders', true)) {
            $reminderHours = $this->getConfigService()->get('reminder_hours_before_expiry', 2);
            ScheduledJob::scheduleConfirmationReminder($authorization, $reminderHours);
        }
    }

    /**
     * Reprogrammer les jobs après confirmation
     */
    private function rescheduleJobsAfterConfirmation(PaymentAuthorization $authorization): void
    {
        // Annuler les jobs de confirmation
        ScheduledJob::where('payment_authorization_id', $authorization->id)
                   ->whereIn('type', [ScheduledJob::TYPE_CONFIRMATION_REMINDER, ScheduledJob::TYPE_PAYMENT_EXPIRY])
                   ->where('status', ScheduledJob::STATUS_PENDING)
                   ->update(['status' => ScheduledJob::STATUS_CANCELLED]);

        // Programmer la capture automatique
        if ($authorization->auto_capture_at && $this->getConfigService()->get('enable_auto_capture', true)) {
            ScheduledJob::scheduleAutoCapture($authorization);
        }

        // Programmer le nouveau job d'expiration (pour la capture)
        ScheduledJob::schedulePaymentExpiry($authorization);

        // Programmer un rappel de paiement
        ScheduledJob::schedulePaymentReminder($authorization, 24);
    }

    /**
     * Annuler tous les jobs en attente pour une autorisation
     */
    private function cancelPendingJobs(PaymentAuthorization $authorization, string $reason = 'Payment processed'): void
    {
        ScheduledJob::where('payment_authorization_id', $authorization->id)
                   ->where('status', ScheduledJob::STATUS_PENDING)
                   ->update([
                       'status' => ScheduledJob::STATUS_CANCELLED,
                       'error_message' => $reason,
                   ]);
    }

    /**
     * Programmer un retry de capture
     */
    private function scheduleRetryCapture(PaymentAuthorization $authorization, string $reason): void
    {
        $delayMinutes = min(60, pow(2, $authorization->capture_attempts) * 10);

        ScheduledJob::create([
            'type' => ScheduledJob::TYPE_AUTO_CAPTURE,
            'payment_authorization_id' => $authorization->id,
            'booking_id' => $authorization->booking_id,
            'scheduled_at' => Carbon::now()->addMinutes($delayMinutes),
            'priority' => 2, // Priorité élevée pour les retries
            'job_data' => [
                'payment_intent_id' => $authorization->payment_intent_id,
                'capture_reason' => $reason,
                'is_retry' => true,
                'attempt_number' => $authorization->capture_attempts + 1,
            ],
        ]);
    }

    /**
     * Calculer les frais de plateforme
     */
    private function calculatePlatformFee(int $amountCents): int
    {
        $feePercentage = $this->getConfigService()->get('platform_fee_percentage', 5.0);
        $minimumFeeCents = $this->getConfigService()->get('minimum_platform_fee_cents', 50);

        $calculatedFee = (int) ($amountCents * $feePercentage / 100);
        return max($calculatedFee, $minimumFeeCents);
    }

    /**
     * Récupérer le compte Stripe du transporteur
     */
    private function getTransporterStripeAccount(Booking $booking): ?string
    {
        $trip = $booking->trip;
        $transporter = $trip->user;

        // Vérifier si l'utilisateur a un compte Stripe configuré dans la table user_stripe_accounts
        $stripeAccount = UserStripeAccount::where('user_id', $transporter->id)->first();

        if (!$stripeAccount) {
            return null;
        }

        // Vérifier que le compte est prêt pour les transactions (charges_enabled ET payouts_enabled)
        if (!$stripeAccount->charges_enabled || !$stripeAccount->payouts_enabled) {
            return null;
        }

        return $stripeAccount->stripe_account_id;
    }

    /**
     * Obtenir le client_secret d'une autorisation pour l'app mobile
     */
    public function getClientSecret(PaymentAuthorization $authorization): ?string
    {
        if (!$authorization->payment_intent_id) {
            return null;
        }

        try {
            $paymentIntent = $this->stripe->paymentIntents->retrieve($authorization->payment_intent_id);
            return $paymentIntent->client_secret;
        } catch (StripeException $e) {
            error_log("Erreur récupération client_secret: " . $e->getMessage());
            return null;
        }
    }

    /**
     * URL de retour pour la confirmation 3D Secure
     */
    private function getReturnUrl(): string
    {
        return config('app.frontend_url') . '/payment/confirm';
    }

    /**
     * Statistiques des autorisations
     */
    public function getAuthorizationStats(int $days = 30): array
    {
        $startDate = Carbon::now()->subDays($days);

        return [
            'total_authorizations' => PaymentAuthorization::where('created_at', '>=', $startDate)->count(),
            'by_status' => PaymentAuthorization::where('created_at', '>=', $startDate)
                                             ->selectRaw('status, COUNT(*) as count')
                                             ->groupBy('status')
                                             ->pluck('count', 'status')
                                             ->toArray(),
            'total_amount' => PaymentAuthorization::where('created_at', '>=', $startDate)
                                                ->where('status', PaymentAuthorization::STATUS_CAPTURED)
                                                ->sum('amount_cents') / 100,
            'average_confirmation_time' => $this->getAverageConfirmationTime($days),
            'average_capture_time' => $this->getAverageCaptureTime($days),
        ];
    }

    private function getAverageConfirmationTime(int $days): ?float
    {
        $authorizations = PaymentAuthorization::where('created_at', '>=', Carbon::now()->subDays($days))
                                            ->whereNotNull('confirmed_at')
                                            ->get();

        if ($authorizations->isEmpty()) {
            return null;
        }

        $totalMinutes = $authorizations->sum(function ($auth) {
            return $auth->created_at->diffInMinutes($auth->confirmed_at);
        });

        return $totalMinutes / $authorizations->count();
    }

    private function getAverageCaptureTime(int $days): ?float
    {
        $authorizations = PaymentAuthorization::where('created_at', '>=', Carbon::now()->subDays($days))
                                            ->whereNotNull('captured_at')
                                            ->whereNotNull('confirmed_at')
                                            ->get();

        if ($authorizations->isEmpty()) {
            return null;
        }

        $totalMinutes = $authorizations->sum(function ($auth) {
            return $auth->confirmed_at->diffInMinutes($auth->captured_at);
        });

        return $totalMinutes / $authorizations->count();
    }
}