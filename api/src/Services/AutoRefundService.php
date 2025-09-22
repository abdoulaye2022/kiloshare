<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\Trip;
use KiloShare\Models\Booking;
use KiloShare\Models\Transaction;
use KiloShare\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Capsule\Manager as DB;
use Exception;

class AutoRefundService
{
    private const STRIPE_FEE_RATE = 0.029; // 2.9%
    private const STRIPE_FIXED_FEE = 0.30; // 0.30€
    private const KILOSHARE_FEE_RATE = 0.15; // 15%

    private SmartNotificationService $notificationService;

    public function __construct(SmartNotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    /**
     * Traite les remboursements automatiques pour un voyage annulé
     */
    public function processAutomaticRefunds(Trip $trip): array
    {
        $results = [
            'total_refunds' => 0,
            'successful_refunds' => 0,
            'failed_refunds' => 0,
            'total_amount' => 0,
            'refund_details' => []
        ];

        try {
            DB::beginTransaction();

            // Récupérer toutes les réservations payées
            $paidBookings = $trip->bookings()
                ->whereIn('status', ['paid', 'accepted'])
                ->where('payment_status', 'completed')
                ->get();

            foreach ($paidBookings as $booking) {
                $refundResult = $this->processBookingRefund($booking, 'trip_cancelled');

                $results['total_refunds']++;
                $results['refund_details'][] = $refundResult;

                if ($refundResult['success']) {
                    $results['successful_refunds']++;
                    $results['total_amount'] += $refundResult['amount'];
                } else {
                    $results['failed_refunds']++;
                }
            }

            DB::commit();

            // Envoyer les notifications de remboursement
            $this->sendRefundNotifications($trip, $results);

            error_log("Auto refunds processed for trip {$trip->id}: {$results['successful_refunds']}/{$results['total_refunds']} successful");

            return $results;

        } catch (Exception $e) {
            DB::rollBack();
            error_log("Auto refund processing failed for trip {$trip->id}: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Traite le remboursement d'une réservation spécifique
     */
    public function processBookingRefund(Booking $booking, string $reason = 'standard'): array
    {
        try {
            // Déterminer le type de remboursement selon la raison
            $refundType = $this->determineRefundType($booking, $reason);

            // Calculer les montants de remboursement
            $refundCalculation = $this->calculateRefundAmounts($booking, $refundType);

            // Traiter le remboursement Stripe si nécessaire
            $stripeRefund = null;
            if ($booking->stripe_payment_intent_id && $refundCalculation['refund_amount'] > 0) {
                $stripeRefund = $this->processStripeRefund($booking, $refundCalculation);
            }

            // Enregistrer la transaction de remboursement
            $refundTransaction = $this->createRefundTransaction($booking, $refundCalculation, $reason);

            // Mettre à jour le statut de la réservation
            $this->updateBookingStatus($booking, $refundCalculation, $reason);

            // Traiter la compensation au voyageur si applicable
            $compensationResult = null;
            if ($refundCalculation['traveler_compensation'] > 0) {
                $compensationResult = $this->processTravelerCompensation($booking, $refundCalculation);
            }

            return [
                'success' => true,
                'booking_id' => $booking->id,
                'amount' => $refundCalculation['refund_amount'],
                'refund_type' => $refundType,
                'stripe_refund_id' => $stripeRefund['id'] ?? null,
                'transaction_id' => $refundTransaction->id,
                'compensation_amount' => $refundCalculation['traveler_compensation'],
                'compensation_transaction_id' => $compensationResult['transaction_id'] ?? null
            ];

        } catch (Exception $e) {
            error_log("Refund processing failed for booking {$booking->id}: " . $e->getMessage());

            return [
                'success' => false,
                'booking_id' => $booking->id,
                'error' => $e->getMessage(),
                'amount' => 0
            ];
        }
    }

    /**
     * Détermine le type de remboursement
     */
    private function determineRefundType(Booking $booking, string $reason): string
    {
        if ($reason === 'trip_cancelled') {
            return 'full_refund'; // Annulation par le voyageur = remboursement intégral
        }

        // Calcul du délai avant départ
        $departureTime = Carbon::parse($booking->trip->departure_date);
        $hoursUntilDeparture = Carbon::now()->diffInHours($departureTime, false);

        if ($hoursUntilDeparture < 24) {
            return 'partial_refund'; // Moins de 24h = remboursement partiel
        } elseif ($hoursUntilDeparture >= 24) {
            return 'standard_refund'; // Plus de 24h = remboursement standard
        }

        return 'no_refund'; // Cas par défaut
    }

    /**
     * Calcule les montants de remboursement
     */
    private function calculateRefundAmounts(Booking $booking, string $refundType): array
    {
        $originalAmount = $booking->total_amount ?? 0;
        $stripeFee = ($originalAmount * self::STRIPE_FEE_RATE) + self::STRIPE_FIXED_FEE;
        $kiloshareFee = $originalAmount * self::KILOSHARE_FEE_RATE;

        $calculation = [
            'original_amount' => $originalAmount,
            'stripe_fee' => $stripeFee,
            'kiloshare_fee' => $kiloshareFee,
            'refund_amount' => 0,
            'traveler_compensation' => 0,
            'kiloshare_keeps' => 0
        ];

        switch ($refundType) {
            case 'full_refund':
                // Remboursement intégral pour annulation de voyage
                $calculation['refund_amount'] = $originalAmount;
                break;

            case 'standard_refund':
                // Remboursement moins les frais KiloShare et Stripe
                $calculation['refund_amount'] = $originalAmount - $kiloshareFee - $stripeFee;
                $calculation['kiloshare_keeps'] = $kiloshareFee;
                break;

            case 'partial_refund':
                // 50% pour l'expéditeur, 50% compensation pour le voyageur
                $netAmount = $originalAmount - $stripeFee; // Frais Stripe non récupérables
                $calculation['refund_amount'] = $netAmount * 0.5;
                $calculation['traveler_compensation'] = $netAmount * 0.5;
                break;

            case 'no_refund':
                // Aucun remboursement, compensation au voyageur
                $calculation['refund_amount'] = 0;
                $calculation['traveler_compensation'] = $originalAmount - $stripeFee;
                break;
        }

        return $calculation;
    }

    /**
     * Traite le remboursement Stripe
     */
    private function processStripeRefund(Booking $booking, array $calculation): array
    {
        // Simulation du remboursement Stripe
        // Dans un vrai environnement, utiliser l'API Stripe

        $refundData = [
            'id' => 're_' . uniqid(),
            'amount' => $calculation['refund_amount'] * 100, // En centimes
            'currency' => $booking->currency ?? 'eur',
            'payment_intent' => $booking->stripe_payment_intent_id,
            'status' => 'succeeded',
            'created' => time()
        ];

        error_log("Stripe refund processed: {$refundData['id']} for booking {$booking->id}, amount: {$calculation['refund_amount']}");

        return $refundData;
    }

    /**
     * Crée la transaction de remboursement
     */
    private function createRefundTransaction(Booking $booking, array $calculation, string $reason): Transaction
    {
        $transaction = new Transaction();
        $transaction->booking_id = $booking->id;
        $transaction->user_id = $booking->user_id;
        $transaction->trip_id = $booking->trip_id;
        $transaction->type = 'refund';
        $transaction->amount = $calculation['refund_amount'];
        $transaction->currency = $booking->currency ?? 'eur';
        $transaction->status = 'completed';
        $transaction->stripe_fee = $calculation['stripe_fee'];
        $transaction->kiloshare_fee = $calculation['kiloshare_fee'];
        $transaction->net_amount = $calculation['refund_amount'];
        $transaction->description = "Remboursement automatique - $reason";
        $transaction->processed_at = Carbon::now();
        $transaction->save();

        return $transaction;
    }

    /**
     * Met à jour le statut de la réservation
     */
    private function updateBookingStatus(Booking $booking, array $calculation, string $reason): void
    {
        $booking->status = 'cancelled';
        $booking->cancelled_at = Carbon::now();
        $booking->cancellation_type = $this->mapReasonToCancellationType($reason);
        $booking->cancellation_reason = $reason;
        $booking->refund_amount = $calculation['refund_amount'];
        $booking->refund_processed_at = Carbon::now();
        $booking->save();
    }

    /**
     * Traite la compensation pour le voyageur
     */
    private function processTravelerCompensation(Booking $booking, array $calculation): array
    {
        // Créer une transaction de compensation pour le voyageur
        $compensation = new Transaction();
        $compensation->booking_id = $booking->id;
        $compensation->user_id = $booking->trip->user_id; // Voyageur
        $compensation->trip_id = $booking->trip_id;
        $compensation->type = 'compensation';
        $compensation->amount = $calculation['traveler_compensation'];
        $compensation->currency = $booking->currency ?? 'eur';
        $compensation->status = 'completed';
        $compensation->description = 'Compensation pour annulation tardive';
        $compensation->processed_at = Carbon::now();
        $compensation->save();

        return [
            'success' => true,
            'transaction_id' => $compensation->id,
            'amount' => $calculation['traveler_compensation']
        ];
    }

    /**
     * Mappe la raison au type d'annulation
     */
    private function mapReasonToCancellationType(string $reason): string
    {
        $mapping = [
            'trip_cancelled' => 'trip_cancelled_by_owner',
            'standard' => 'cancelled_by_sender',
            'late_cancellation' => 'late_cancellation',
            'no_show' => 'no_show'
        ];

        return $mapping[$reason] ?? 'other';
    }

    /**
     * Envoie les notifications de remboursement
     */
    private function sendRefundNotifications(Trip $trip, array $results): void
    {
        foreach ($results['refund_details'] as $refund) {
            if ($refund['success']) {
                $booking = Booking::find($refund['booking_id']);
                if ($booking && $booking->user) {
                    $this->notificationService->sendRefundNotification(
                        $booking->user,
                        $booking,
                        [
                            'amount' => $refund['amount'],
                            'refund_type' => $refund['refund_type'],
                            'processing_time' => '3-5 jours ouvrables'
                        ]
                    );
                }
            }
        }
    }

    /**
     * Obtient le résumé des remboursements pour un voyage
     */
    public function getRefundSummary(Trip $trip): array
    {
        $refunds = Transaction::where('trip_id', $trip->id)
            ->where('type', 'refund')
            ->get();

        $compensations = Transaction::where('trip_id', $trip->id)
            ->where('type', 'compensation')
            ->get();

        return [
            'total_refunds' => $refunds->count(),
            'total_refund_amount' => $refunds->sum('amount'),
            'total_compensations' => $compensations->count(),
            'total_compensation_amount' => $compensations->sum('amount'),
            'processing_status' => $this->getProcessingStatus($refunds, $compensations)
        ];
    }

    /**
     * Statut du traitement des remboursements
     */
    private function getProcessingStatus($refunds, $compensations): string
    {
        $allTransactions = $refunds->concat($compensations);

        if ($allTransactions->isEmpty()) {
            return 'no_refunds';
        }

        $pendingCount = $allTransactions->where('status', 'pending')->count();

        if ($pendingCount > 0) {
            return 'processing';
        }

        return 'completed';
    }
}