<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\Booking;
use KiloShare\Models\PaymentAuthorization;
use KiloShare\Models\User;
use KiloShare\Models\PaymentEventLog;

class BookingStatusService
{
    private PaymentAuthorizationService $paymentService;
    private NotificationService $notificationService;

    public function __construct(
        PaymentAuthorizationService $paymentService,
        NotificationService $notificationService
    ) {
        $this->paymentService = $paymentService;
        $this->notificationService = $notificationService;
    }

    /**
     * Accepter une réservation
     */
    public function acceptBooking(Booking $booking, User $transporter, ?float $finalPrice = null): array
    {
        if (!$booking->canBeAccepted()) {
            throw new \Exception('Cette réservation ne peut plus être acceptée');
        }

        if ($booking->trip->user_id !== $transporter->id) {
            throw new \Exception('Seul le propriétaire du voyage peut accepter cette réservation');
        }

        // Mettre à jour la réservation
        $booking->accept($finalPrice);

        // Créer l'autorisation de paiement automatiquement
        $sender = $booking->sender;
        $authorization = $this->paymentService->createAuthorization($booking, $sender);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'payment_authorization' => $authorization,
            'message' => 'Réservation acceptée avec succès. Une autorisation de paiement a été créée.',
        ];
    }

    /**
     * Rejeter une réservation
     */
    public function rejectBooking(Booking $booking, User $transporter, ?string $reason = null): array
    {
        if (!$booking->canBeRejected()) {
            throw new \Exception('Cette réservation ne peut plus être rejetée');
        }

        if ($booking->trip->user_id !== $transporter->id) {
            throw new \Exception('Seul le propriétaire du voyage peut rejeter cette réservation');
        }

        // Mettre à jour la réservation
        $booking->status = Booking::STATUS_REJECTED;
        if ($reason) {
            $booking->rejection_reason = $reason;
        }
        $booking->save();

        // Notifier l'expéditeur
        $this->notificationService->sendBookingRejectedNotification($booking, $reason);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'message' => 'Réservation rejetée avec succès',
        ];
    }

    /**
     * Confirmer un paiement par l'expéditeur
     */
    public function confirmPayment(Booking $booking, User $sender): array
    {
        if (!$booking->canBePaymentConfirmed()) {
            throw new \Exception('Le paiement de cette réservation ne peut plus être confirmé');
        }

        if ($booking->sender_id !== $sender->id) {
            throw new \Exception('Seul l\'expéditeur peut confirmer le paiement');
        }

        if (!$booking->paymentAuthorization) {
            throw new \Exception('Aucune autorisation de paiement trouvée pour cette réservation');
        }

        // Confirmer le paiement via le service
        $this->paymentService->confirmAuthorization($booking->paymentAuthorization, $sender);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'message' => 'Paiement confirmé avec succès',
        ];
    }

    /**
     * Capturer un paiement (manuelle)
     */
    public function capturePayment(Booking $booking, string $reason = PaymentAuthorization::CAPTURE_REASON_MANUAL): array
    {
        if (!$booking->canBePaymentCaptured()) {
            throw new \Exception('Le paiement de cette réservation ne peut plus être capturé');
        }

        if (!$booking->paymentAuthorization) {
            throw new \Exception('Aucune autorisation de paiement trouvée pour cette réservation');
        }

        // Capturer via le service
        $this->paymentService->capturePayment($booking->paymentAuthorization, $reason);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'message' => 'Paiement capturé avec succès',
        ];
    }

    /**
     * Annuler une réservation
     */
    public function cancelBooking(Booking $booking, User $user, ?string $reason = null): array
    {
        if (!$booking->canBeCancelledBy($user)) {
            throw new \Exception('Vous ne pouvez pas annuler cette réservation');
        }

        $requiresRefund = $booking->canBeCancelledWithRefund();

        // Si un paiement est en cours, l'annuler
        if ($booking->paymentAuthorization && !$booking->paymentAuthorization->isCancelled()) {
            try {
                $this->paymentService->cancelAuthorization($booking->paymentAuthorization, $user, $reason);
            } catch (\Exception $e) {
                // Logger l'erreur mais continuer l'annulation de la réservation
                error_log("Erreur lors de l'annulation du paiement: " . $e->getMessage());
            }
        }

        // Déterminer le type d'annulation
        $cancellationType = $this->determineCancellationType($booking, $user);

        // Mettre à jour la réservation
        $booking->status = Booking::STATUS_CANCELLED;
        $booking->cancelled_at = now();
        $booking->cancellation_type = $cancellationType;

        if ($reason) {
            $booking->cancellation_reason = $reason;
        }

        $booking->save();

        // Notifier les parties concernées
        $this->notificationService->sendBookingCancelledNotification($booking, $user, $reason, $requiresRefund);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'refund_processed' => $requiresRefund,
            'message' => $requiresRefund
                ? 'Réservation annulée avec succès. Le remboursement sera traité.'
                : 'Réservation annulée avec succès',
        ];
    }

    /**
     * Démarrer le transport
     */
    public function startTransit(Booking $booking, User $transporter): array
    {
        if (!$booking->isPaid()) {
            throw new \Exception('Le paiement doit être finalisé avant de démarrer le transport');
        }

        if ($booking->trip->user_id !== $transporter->id) {
            throw new \Exception('Seul le transporteur peut démarrer le transport');
        }

        $booking->status = Booking::STATUS_IN_TRANSIT;
        $booking->save();

        // Générer le code de livraison si pas déjà fait
        if (!$booking->deliveryCode) {
            // Appeler le service de code de livraison
            // TODO: Intégrer avec DeliveryCodeService
        }

        $this->notificationService->sendTransitStartedNotification($booking);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'message' => 'Transport démarré avec succès',
        ];
    }

    /**
     * Marquer comme livré
     */
    public function markAsDelivered(Booking $booking, User $transporter): array
    {
        if (!$booking->isInTransit()) {
            throw new \Exception('La réservation doit être en transit pour être marquée comme livrée');
        }

        if ($booking->trip->user_id !== $transporter->id) {
            throw new \Exception('Seul le transporteur peut marquer comme livré');
        }

        $booking->status = Booking::STATUS_DELIVERED;
        $booking->delivery_date = now();
        $booking->save();

        $this->notificationService->sendDeliveryNotification($booking);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'message' => 'Réservation marquée comme livrée',
        ];
    }

    /**
     * Compléter la réservation
     */
    public function completeBooking(Booking $booking, User $sender): array
    {
        if (!$booking->isDelivered()) {
            throw new \Exception('La réservation doit être livrée pour être complétée');
        }

        if ($booking->sender_id !== $sender->id) {
            throw new \Exception('Seul l\'expéditeur peut compléter la réservation');
        }

        $booking->complete();

        $this->notificationService->sendBookingCompletedNotification($booking);

        return [
            'success' => true,
            'booking' => $booking->fresh(),
            'message' => 'Réservation complétée avec succès',
        ];
    }

    /**
     * Obtenir l'historique des changements de statut
     */
    public function getStatusHistory(Booking $booking): array
    {
        if (!$booking->paymentAuthorization) {
            return [];
        }

        return PaymentEventLog::getEventStatistics($booking->paymentAuthorization->id);
    }

    /**
     * Obtenir les actions disponibles pour un utilisateur
     */
    public function getAvailableActions(Booking $booking, User $user): array
    {
        $actions = [];
        $isTransporter = $booking->trip->user_id === $user->id;
        $isSender = $booking->sender_id === $user->id;

        switch ($booking->status) {
            case Booking::STATUS_PENDING:
                if ($isTransporter) {
                    $actions[] = 'accept';
                    $actions[] = 'reject';
                }
                if ($isSender) {
                    $actions[] = 'cancel';
                }
                break;

            case Booking::STATUS_ACCEPTED:
                if ($isSender || $isTransporter) {
                    $actions[] = 'cancel';
                }
                break;

            case Booking::STATUS_PAYMENT_AUTHORIZED:
                if ($isSender) {
                    $actions[] = 'confirm_payment';
                    $actions[] = 'cancel_payment';
                }
                if ($isTransporter) {
                    $actions[] = 'cancel';
                }
                break;

            case Booking::STATUS_PAYMENT_CONFIRMED:
                if ($isTransporter) {
                    $actions[] = 'capture_payment'; // Action manuelle si nécessaire
                }
                if ($isSender || $isTransporter) {
                    $actions[] = 'cancel';
                }
                break;

            case Booking::STATUS_PAID:
                if ($isTransporter) {
                    $actions[] = 'start_transit';
                }
                break;

            case Booking::STATUS_IN_TRANSIT:
                if ($isTransporter) {
                    $actions[] = 'mark_delivered';
                }
                break;

            case Booking::STATUS_DELIVERED:
                if ($isSender) {
                    $actions[] = 'complete';
                }
                break;
        }

        return $actions;
    }

    /**
     * Valider si une action est autorisée
     */
    public function canPerformAction(Booking $booking, User $user, string $action): bool
    {
        $availableActions = $this->getAvailableActions($booking, $user);
        return in_array($action, $availableActions);
    }

    /**
     * Obtenir les détails de progression
     */
    public function getProgressDetails(Booking $booking): array
    {
        $steps = [
            'created' => true,
            'accepted' => $booking->isAccepted() || $booking->isPaymentAuthorized() || $booking->isPaymentConfirmed() || $booking->isPaid() || $booking->isInTransit() || $booking->isDelivered() || $booking->isCompleted(),
            'payment_authorized' => $booking->isPaymentAuthorized() || $booking->isPaymentConfirmed() || $booking->isPaid() || $booking->isInTransit() || $booking->isDelivered() || $booking->isCompleted(),
            'payment_confirmed' => $booking->isPaymentConfirmed() || $booking->isPaid() || $booking->isInTransit() || $booking->isDelivered() || $booking->isCompleted(),
            'paid' => $booking->isPaid() || $booking->isInTransit() || $booking->isDelivered() || $booking->isCompleted(),
            'in_transit' => $booking->isInTransit() || $booking->isDelivered() || $booking->isCompleted(),
            'delivered' => $booking->isDelivered() || $booking->isCompleted(),
            'completed' => $booking->isCompleted(),
        ];

        $currentStep = 'created';
        if ($booking->isCompleted()) $currentStep = 'completed';
        elseif ($booking->isDelivered()) $currentStep = 'delivered';
        elseif ($booking->isInTransit()) $currentStep = 'in_transit';
        elseif ($booking->isPaid()) $currentStep = 'paid';
        elseif ($booking->isPaymentConfirmed()) $currentStep = 'payment_confirmed';
        elseif ($booking->isPaymentAuthorized()) $currentStep = 'payment_authorized';
        elseif ($booking->isAccepted()) $currentStep = 'accepted';

        return [
            'steps' => $steps,
            'current_step' => $currentStep,
            'progress_percentage' => $this->calculateProgressPercentage($booking),
            'is_cancelled' => $booking->isCancelled(),
        ];
    }

    /**
     * Calculer le pourcentage de progression
     */
    private function calculateProgressPercentage(Booking $booking): int
    {
        if ($booking->isCancelled()) return 0;
        if ($booking->isCompleted()) return 100;
        if ($booking->isDelivered()) return 85;
        if ($booking->isInTransit()) return 70;
        if ($booking->isPaid()) return 60;
        if ($booking->isPaymentConfirmed()) return 45;
        if ($booking->isPaymentAuthorized()) return 30;
        if ($booking->isAccepted()) return 15;
        return 5; // Créée
    }

    /**
     * Déterminer le type d'annulation
     */
    private function determineCancellationType(Booking $booking, User $user): string
    {
        if ($booking->sender_id === $user->id) {
            return Booking::CANCELLATION_BY_SENDER;
        }

        if ($booking->trip->user_id === $user->id) {
            return Booking::CANCELLATION_BY_TRAVELER;
        }

        // Cas d'annulation système (expiration)
        return 'system';
    }

    /**
     * Statistiques des réservations par statut
     */
    public function getBookingStatistics(int $days = 30): array
    {
        $startDate = now()->subDays($days);

        $stats = [
            'total_bookings' => Booking::where('created_at', '>=', $startDate)->count(),
            'by_status' => Booking::where('created_at', '>=', $startDate)
                                 ->selectRaw('status, COUNT(*) as count')
                                 ->groupBy('status')
                                 ->pluck('count', 'status')
                                 ->toArray(),
            'conversion_rate' => $this->calculateConversionRate($days),
            'average_completion_time' => $this->getAverageCompletionTime($days),
            'cancellation_rate' => $this->calculateCancellationRate($days),
        ];

        return $stats;
    }

    private function calculateConversionRate(int $days): float
    {
        $startDate = now()->subDays($days);
        $total = Booking::where('created_at', '>=', $startDate)->count();
        $completed = Booking::where('created_at', '>=', $startDate)
                           ->where('status', Booking::STATUS_COMPLETED)
                           ->count();

        return $total > 0 ? ($completed / $total) * 100 : 0;
    }

    private function getAverageCompletionTime(int $days): ?float
    {
        $completedBookings = Booking::where('created_at', '>=', now()->subDays($days))
                                  ->where('status', Booking::STATUS_COMPLETED)
                                  ->get();

        if ($completedBookings->isEmpty()) {
            return null;
        }

        $totalHours = $completedBookings->sum(function ($booking) {
            return $booking->created_at->diffInHours($booking->updated_at);
        });

        return $totalHours / $completedBookings->count();
    }

    private function calculateCancellationRate(int $days): float
    {
        $startDate = now()->subDays($days);
        $total = Booking::where('created_at', '>=', $startDate)->count();
        $cancelled = Booking::cancelled()
                           ->where('created_at', '>=', $startDate)
                           ->count();

        return $total > 0 ? ($cancelled / $total) * 100 : 0;
    }
}