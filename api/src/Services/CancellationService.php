<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\User;
use KiloShare\Models\Trip;
use KiloShare\Models\Booking;
use KiloShare\Models\BookingNegotiation;
use KiloShare\Models\EscrowAccount;
use KiloShare\Models\Transaction;
use Carbon\Carbon;
use Illuminate\Database\Capsule\Manager as DB;
use Exception;

class CancellationService
{
    private const KILOSHARE_FEE_RATE = 0.15; // 15% commission KiloShare
    private const STRIPE_FEE_RATE = 0.029; // 2.9% frais Stripe
    private const STRIPE_FIXED_FEE = 0.30; // 0.30€ frais fixe Stripe
    private const MAX_CANCELLATIONS_PER_PERIOD = 1;
    private const CANCELLATION_RESTRICTION_DAYS = 90; // 3 mois
    
    /**
     * Vérifie si un voyageur peut annuler son voyage
     */
    public function canTravelerCancelTrip(User $user, Trip $trip): array
    {
        // Vérifier la propriété du voyage
        if (!$trip->isOwner($user)) {
            return ['allowed' => false, 'reason' => 'Vous n\'êtes pas le propriétaire de ce voyage'];
        }

        // Vérifier si le voyage peut être annulé (statut)
        if (!in_array($trip->status, [Trip::STATUS_ACTIVE, Trip::STATUS_BOOKED])) {
            return ['allowed' => false, 'reason' => 'Ce voyage ne peut plus être annulé'];
        }

        // Vérifier s'il y a des réservations confirmées
        $confirmedBookings = $trip->bookings()->whereIn('status', ['accepted', 'in_progress'])->count();
        
        if ($confirmedBookings > 0) {
            // Vérifier les limites d'annulation avec réservations
            $cancellationCheck = $this->checkTravelerCancellationLimits($user);
            if (!$cancellationCheck['allowed']) {
                return $cancellationCheck;
            }
        }

        return ['allowed' => true, 'has_bookings' => $confirmedBookings > 0];
    }

    /**
     * Vérifie les limites d'annulation pour un voyageur
     */
    private function checkTravelerCancellationLimits(User $user): array
    {
        // Vérifier si l'utilisateur est suspendu
        if ($user->is_suspended) {
            return ['allowed' => false, 'reason' => 'Votre compte est suspendu pour annulations répétées'];
        }

        // Vérifier le nombre d'annulations dans les 3 derniers mois
        $threeMonthsAgo = Carbon::now()->subDays(self::CANCELLATION_RESTRICTION_DAYS);
        
        if ($user->last_cancellation_date && Carbon::parse($user->last_cancellation_date)->isAfter($threeMonthsAgo)) {
            return [
                'allowed' => false, 
                'reason' => 'Vous avez déjà annulé un voyage avec réservations dans les 3 derniers mois. Prochaine annulation possible le ' . 
                           Carbon::parse($user->last_cancellation_date)->addDays(self::CANCELLATION_RESTRICTION_DAYS)->format('d/m/Y')
            ];
        }

        return ['allowed' => true];
    }

    /**
     * Annule un voyage par le voyageur
     */
    public function cancelTripByTraveler(Trip $trip, ?string $reason = null): array
    {
        $user = $trip->user;
        
        // Vérifications préalables
        $canCancel = $this->canTravelerCancelTrip($user, $trip);
        if (!$canCancel['allowed']) {
            throw new Exception($canCancel['reason']);
        }

        DB::beginTransaction();
        
        try {
            $hasBookings = $canCancel['has_bookings'];
            
            // Si annulation avec réservations, raison obligatoire
            if ($hasBookings && empty($reason)) {
                throw new Exception('Une raison d\'annulation est obligatoire lorsque des réservations sont confirmées');
            }

            // Mettre à jour le voyage
            $trip->status = Trip::STATUS_CANCELLED;
            $trip->cancellation_reason = $reason;
            $trip->cancelled_at = Carbon::now();
            $trip->cancelled_by = 'traveler';
            $trip->save();

            if ($hasBookings) {
                // Traiter les réservations confirmées
                $this->processTravelerCancellationWithBookings($trip, $reason);
            }

            // Enregistrer la tentative d'annulation
            $this->logCancellationAttempt($user->id, $trip->id, null, 'trip_cancel', true);

            DB::commit();
            
            return [
                'success' => true,
                'message' => $hasBookings ? 
                    'Voyage annulé. Les expéditeurs seront remboursés intégralement.' : 
                    'Voyage annulé avec succès.',
                'refunds_processed' => $hasBookings
            ];

        } catch (Exception $e) {
            DB::rollBack();
            
            // Enregistrer la tentative échouée
            $this->logCancellationAttempt($user->id, $trip->id, null, 'trip_cancel', false, $e->getMessage());
            
            throw $e;
        }
    }

    /**
     * Traite l'annulation d'un voyage avec réservations par le voyageur
     */
    private function processTravelerCancellationWithBookings(Trip $trip, string $reason): void
    {
        $confirmedBookings = $trip->bookings()->whereIn('status', ['accepted', 'in_progress'])->get();
        
        foreach ($confirmedBookings as $booking) {
            // Annuler la réservation
            $booking->status = Booking::STATUS_CANCELLED;
            $booking->cancelled_at = Carbon::now();
            $booking->cancellation_type = 'by_traveler';
            $booking->cancellation_reason = $reason;
            $booking->save();

            // Traiter le remboursement 100%
            $this->processFullRefund($booking, 'traveler_cancellation');
        }
    }

    /**
     * Vérifie si un expéditeur peut annuler sa réservation
     */
    public function canSenderCancelBooking(User $user, Booking $booking): array
    {
        // Vérifier la propriété de la réservation
        if ($booking->sender_id !== $user->id) {
            return ['allowed' => false, 'reason' => 'Vous n\'êtes pas l\'expéditeur de cette réservation'];
        }

        // Vérifier le statut de la réservation
        if (!in_array($booking->status, ['pending', 'accepted'])) {
            return ['allowed' => false, 'reason' => 'Cette réservation ne peut plus être annulée'];
        }

        // Si c'est une demande non confirmée (pending)
        if ($booking->status === 'pending') {
            return ['allowed' => true, 'type' => 'negotiation_cancel', 'refund_rate' => 100];
        }

        // Calculer le timing par rapport au départ
        $trip = $booking->trip;
        $now = Carbon::now();
        $departure = Carbon::parse($trip->departure_date);
        $hoursBeforeDeparture = $now->diffInHours($departure, false);

        if ($hoursBeforeDeparture < 24) {
            // Annulation moins de 24h avant
            return ['allowed' => true, 'type' => 'late_cancel', 'refund_rate' => 50];
        } else {
            // Annulation plus de 24h avant
            return ['allowed' => true, 'type' => 'early_cancel', 'refund_rate' => 100];
        }
    }

    /**
     * Annule une réservation par l'expéditeur
     */
    public function cancelBookingBySender(Booking $booking): array
    {
        $user = User::find($booking->sender_id);
        
        // Vérifications préalables
        $canCancel = $this->canSenderCancelBooking($user, $booking);
        if (!$canCancel['allowed']) {
            throw new Exception($canCancel['reason']);
        }

        DB::beginTransaction();
        
        try {
            $cancelType = $canCancel['type'];
            $refundRate = $canCancel['refund_rate'];

            if ($cancelType === 'negotiation_cancel') {
                // Annulation d'une demande non confirmée
                $this->cancelPendingNegotiation($booking);
            } else {
                // Annulation d'une réservation confirmée
                $this->processConfirmedBookingCancellation($booking, $cancelType, $refundRate);
            }

            // TODO: Enregistrer la tentative d'annulation quand la table sera créée
            // $this->logCancellationAttempt($user->id, null, $booking->id, 'booking_cancel', true);

            DB::commit();
            
            return [
                'success' => true,
                'message' => $this->getCancellationMessage($cancelType, $refundRate),
                'refund_percentage' => $refundRate
            ];

        } catch (Exception $e) {
            DB::rollBack();
            
            // TODO: Enregistrer la tentative échouée quand la table sera créée
            // $this->logCancellationAttempt($user->id, null, $booking->id, 'booking_cancel', false, $e->getMessage());
            
            throw $e;
        }
    }

    /**
     * Annule une négociation en cours (demande non confirmée)
     */
    private function cancelPendingNegotiation(Booking $booking): void
    {
        // Mettre à jour la négociation
        if ($booking->booking_negotiation_id) {
            $negotiation = BookingNegotiation::find($booking->booking_negotiation_id);
            if ($negotiation) {
                $negotiation->status = 'cancelled_by_sender';
                $negotiation->save();
            }
        }

        // Annuler la réservation
        $booking->status = Booking::STATUS_CANCELLED;
        $booking->cancelled_at = Carbon::now();
        $booking->cancellation_type = 'by_sender';
        $booking->save();

        // Remboursement 100% (pas de frais)
        $this->processFullRefund($booking, 'negotiation_cancellation');
    }

    /**
     * Traite l'annulation d'une réservation confirmée
     */
    private function processConfirmedBookingCancellation(Booking $booking, string $cancelType, int $refundRate): void
    {
        // Mettre à jour la réservation
        $booking->status = Booking::STATUS_CANCELLED;
        $booking->save();

        // TODO: Implémenter la logique de remboursement
        if ($refundRate === 50) {
            // Annulation tardive: 50% expéditeur, 50% voyageur
            // $this->processPartialRefundWithCompensation($booking);
        } else {
            // Annulation précoce: 100% expéditeur moins frais
            // $this->processRefundMinusFees($booking);
        }
    }

    /**
     * Traite un remboursement complet (100%)
     */
    private function processFullRefund(Booking $booking, string $reason): void
    {
        $escrow = EscrowAccount::where('booking_id', $booking->id)->first();
        if (!$escrow) {
            throw new Exception('Compte séquestre non trouvé pour cette réservation');
        }

        // Créer la transaction de remboursement
        $transaction = new Transaction([
            'booking_id' => $booking->id,
            'user_id' => $booking->sender_id,
            'type' => 'refund_full',
            'amount' => $escrow->total_amount,
            'fee_amount' => 0.00,
            'net_amount' => $escrow->total_amount,
            'status' => 'pending',
            'description' => "Remboursement complet - {$reason}",
            'stripe_fee' => 0.00,
            'kiloshare_fee' => 0.00
        ]);
        $transaction->save();

        // Mettre à jour l'escrow
        $escrow->status = 'refunded';
        $escrow->refunded_at = Carbon::now();
        $escrow->save();
    }

    /**
     * Traite un remboursement partiel avec compensation
     */
    private function processPartialRefundWithCompensation(Booking $booking): void
    {
        $escrow = EscrowAccount::where('booking_id', $booking->id)->first();
        if (!$escrow) {
            throw new Exception('Compte séquestre non trouvé pour cette réservation');
        }

        $totalAmount = $escrow->total_amount;
        $kiloshareCommission = $escrow->commission_amount;
        $packageAmount = $totalAmount - $kiloshareCommission;
        
        // Calculer les frais Stripe sur le montant total
        $stripeFee = $this->calculateStripeFees($totalAmount);
        
        // 50% du montant du colis à l'expéditeur (moins frais Stripe)
        $senderRefund = ($packageAmount * 0.5) - $stripeFee;
        
        // 50% du montant du colis au voyageur comme compensation
        $travelerCompensation = $packageAmount * 0.5;

        // Transaction de remboursement partiel pour l'expéditeur
        $refundTransaction = new Transaction([
            'booking_id' => $booking->id,
            'user_id' => $booking->sender_id,
            'type' => 'partial_refund',
            'amount' => $senderRefund,
            'fee_amount' => $stripeFee,
            'net_amount' => $senderRefund,
            'status' => 'pending',
            'description' => 'Remboursement partiel (50%) - Annulation tardive',
            'stripe_fee' => $stripeFee,
            'kiloshare_fee' => 0.00
        ]);
        $refundTransaction->save();

        // Transaction de compensation pour le voyageur
        $compensationTransaction = new Transaction([
            'booking_id' => $booking->id,
            'user_id' => $booking->trip->user_id,
            'type' => 'cancellation_compensation',
            'amount' => $travelerCompensation,
            'fee_amount' => 0.00,
            'net_amount' => $travelerCompensation,
            'status' => 'pending',
            'description' => 'Compensation (50%) - Annulation tardive par expéditeur',
            'stripe_fee' => 0.00,
            'kiloshare_fee' => 0.00
        ]);
        $compensationTransaction->save();

        // Mettre à jour l'escrow
        $escrow->status = 'partially_refunded';
        $escrow->refunded_at = Carbon::now();
        $escrow->save();
    }

    /**
     * Traite un remboursement moins les frais
     */
    private function processRefundMinusFees(Booking $booking): void
    {
        $escrow = EscrowAccount::where('booking_id', $booking->id)->first();
        if (!$escrow) {
            throw new Exception('Compte séquestre non trouvé pour cette réservation');
        }

        $totalAmount = $escrow->total_amount;
        $kiloshareCommission = $escrow->commission_amount;
        $stripeFee = $this->calculateStripeFees($totalAmount);
        
        // Remboursement = montant total - commission KiloShare - frais Stripe
        $refundAmount = $totalAmount - $kiloshareCommission - $stripeFee;

        // Transaction de remboursement
        $transaction = new Transaction([
            'booking_id' => $booking->id,
            'user_id' => $booking->sender_id,
            'type' => 'refund_minus_fees',
            'amount' => $refundAmount,
            'fee_amount' => $kiloshareCommission + $stripeFee,
            'net_amount' => $refundAmount,
            'status' => 'pending',
            'description' => 'Remboursement moins frais - Annulation précoce',
            'stripe_fee' => $stripeFee,
            'kiloshare_fee' => $kiloshareCommission
        ]);
        $transaction->save();

        // Mettre à jour l'escrow
        $escrow->status = 'refunded_minus_fees';
        $escrow->refunded_at = Carbon::now();
        $escrow->save();
    }

    /**
     * Marque une réservation comme no-show
     */
    public function markBookingAsNoShow(Booking $booking): void
    {
        DB::beginTransaction();
        
        try {
            // Mettre à jour la réservation
            $booking->status = Booking::STATUS_CANCELLED;
            $booking->cancelled_at = Carbon::now();
            $booking->cancellation_type = 'no_show';
            $booking->cancellation_reason = 'Expéditeur ne s\'est pas présenté pour déposer le colis';
            $booking->save();

            // Aucun remboursement à l'expéditeur
            // Le voyageur reçoit une compensation (à définir selon les politiques)
            
            $escrow = EscrowAccount::where('booking_id', $booking->id)->first();
            if ($escrow) {
                // Compensation au voyageur (montant à définir)
                $compensationAmount = $escrow->total_amount * 0.5; // 50% comme compensation provisoire
                
                $compensationTransaction = new Transaction([
                    'booking_id' => $booking->id,
                    'user_id' => $booking->trip->user_id,
                    'type' => 'no_show_compensation',
                    'amount' => $compensationAmount,
                    'fee_amount' => 0.00,
                    'net_amount' => $compensationAmount,
                    'status' => 'pending',
                    'description' => 'Compensation pour no-show de l\'expéditeur',
                    'stripe_fee' => 0.00,
                    'kiloshare_fee' => 0.00
                ]);
                $compensationTransaction->save();

                $escrow->status = 'no_show';
                $escrow->save();
            }

            DB::commit();
            
        } catch (Exception $e) {
            DB::rollBack();
            throw $e;
        }
    }

    /**
     * Calcule les frais Stripe
     */
    private function calculateStripeFees(float $amount): float
    {
        return ($amount * self::STRIPE_FEE_RATE) + self::STRIPE_FIXED_FEE;
    }

    /**
     * Enregistre une tentative d'annulation
     */
    private function logCancellationAttempt(int $userId, ?int $tripId, ?int $bookingId, string $attemptType, bool $isAllowed, ?string $denialReason = null): void
    {
        DB::table('cancellation_attempts')->insert([
            'user_id' => $userId,
            'trip_id' => $tripId,
            'booking_id' => $bookingId,
            'attempt_type' => $attemptType,
            'is_allowed' => $isAllowed,
            'denial_reason' => $denialReason,
            'created_at' => Carbon::now()
        ]);
    }

    /**
     * Génère le message d'annulation approprié
     */
    private function getCancellationMessage(string $cancelType, int $refundRate): string
    {
        switch ($cancelType) {
            case 'negotiation_cancel':
                return 'Demande de réservation annulée. Remboursement intégral en cours.';
            case 'early_cancel':
                return 'Réservation annulée avec plus de 24h d\'avance. Remboursement (moins les frais) en cours.';
            case 'late_cancel':
                return 'Réservation annulée avec moins de 24h d\'avance. Remboursement partiel (50%) en cours. Le voyageur recevra 50% en compensation.';
            default:
                return 'Réservation annulée avec succès.';
        }
    }

    /**
     * Récupère le résumé des annulations d'un utilisateur
     */
    public function getUserCancellationSummary(int $userId): array
    {
        $summary = DB::table('user_cancellation_summary')
                    ->where('user_id', $userId)
                    ->first();

        return [
            'cancellation_count' => $summary->cancellation_count ?? 0,
            'last_cancellation_date' => $summary->last_cancellation_date,
            'can_cancel_with_booking' => $summary->can_cancel_with_booking ?? true,
            'is_suspended' => $summary->is_suspended ?? false,
            'public_reports_count' => $summary->public_cancellation_reports ?? 0
        ];
    }
}