<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\Booking;
use KiloShare\Models\DeliveryCode;
use KiloShare\Models\DeliveryCodeAttempt;
use KiloShare\Models\PaymentAuthorization;
use KiloShare\Models\User;
use KiloShare\Services\PaymentAuthorizationService;
use KiloShare\Services\SmartNotificationService;
use Carbon\Carbon;
use Exception;

class DeliveryCodeService
{
    private NotificationService $notificationService;
    private SmartNotificationService $smartNotificationService;

    public function __construct(
        NotificationService $notificationService,
        SmartNotificationService $smartNotificationService
    ) {
        $this->notificationService = $notificationService;
        $this->smartNotificationService = $smartNotificationService;
    }

    /**
     * Génère un code de livraison pour une réservation confirmée
     */
    public function generateDeliveryCode(Booking $booking): DeliveryCode
    {
        // Vérifier qu'il n'y a pas déjà un code actif
        $existingCode = DeliveryCode::where('booking_id', $booking->id)
            ->where('status', DeliveryCode::STATUS_ACTIVE)
            ->first();

        if ($existingCode) {
            throw new Exception('Un code de livraison actif existe déjà pour cette réservation');
        }

        // Créer le nouveau code
        $deliveryCode = new DeliveryCode([
            'booking_id' => $booking->id,
            'status' => DeliveryCode::STATUS_ACTIVE,
            'generated_at' => Carbon::now(),
        ]);

        // Définir la date d'expiration basée sur la date d'arrivée du voyage
        $deliveryCode->setExpiryBasedOnTrip();
        $deliveryCode->save();

        // Marquer la réservation comme nécessitant un code de livraison
        $booking->delivery_code_required = true;
        $booking->save();

        // Envoyer le code à l'expéditeur
        $this->sendCodeToSender($deliveryCode);

        return $deliveryCode;
    }

    /**
     * Envoie le code de livraison à l'expéditeur (pas au destinataire)
     */
    private function sendCodeToSender(DeliveryCode $deliveryCode): void
    {
        $booking = $deliveryCode->booking;
        $sender = $booking->sender; // L'expéditeur du colis
        $trip = $booking->trip;

        // Email à l'expéditeur
        $emailData = [
            'user_name' => $sender->first_name,
            'delivery_code' => $deliveryCode->code,
            'booking_reference' => $booking->uuid,
            'departure_city' => $trip->departure_city,
            'arrival_city' => $trip->arrival_city,
            'arrival_date' => $trip->arrival_date->format('d/m/Y à H:i'),
            'expires_at' => $deliveryCode->expires_at->format('d/m/Y à H:i'),
            'receiver_name' => $booking->receiver->first_name,
            'package_description' => $booking->package_description,
        ];

        $this->notificationService->sendEmail(
            $sender->email,
            'Code de livraison pour votre colis',
            'delivery_code_generated',
            $emailData
        );

        // Notification push à l'expéditeur
        $this->smartNotificationService->sendDeliveryCodeGenerated(
            $sender,
            $deliveryCode->code,
            $booking
        );

        // SMS si le numéro est disponible (optionnel)
        if ($sender->phone_number) {
            $smsMessage = "KiloShare: Votre code de livraison est {$deliveryCode->code}. " .
                         "Communiquez-le au destinataire à l'arrivée. " .
                         "Expire le {$deliveryCode->expires_at->format('d/m à H:i')}.";

            $this->notificationService->sendSms(
                $sender->phone_number,
                $smsMessage
            );
        }
    }

    /**
     * Valide un code de livraison saisi par le destinataire
     */
    public function validateDeliveryCode(
        Booking $booking,
        string $inputCode,
        User $user,
        float $latitude = null,
        float $longitude = null,
        array $photos = []
    ): array {
        // Récupérer le code actif pour cette réservation
        $deliveryCode = DeliveryCode::where('booking_id', $booking->id)
            ->where('status', DeliveryCode::STATUS_ACTIVE)
            ->first();

        if (!$deliveryCode) {
            return [
                'success' => false,
                'error' => 'Aucun code de livraison actif trouvé pour cette réservation',
            ];
        }

        // SÉCURITÉ: Vérifier que l'utilisateur est autorisé (destinataire ou expéditeur)
        if ($user->id !== $booking->receiver_id && $user->id !== $booking->sender_id) {
            // Log de tentative d'accès non autorisé
            error_log("SECURITY: Unauthorized delivery code validation attempt by user {$user->id} for booking {$booking->id}");
            return [
                'success' => false,
                'error' => 'Vous n\'êtes pas autorisé à valider ce code de livraison',
            ];
        }

        // SÉCURITÉ: Vérifier que la réservation est dans un état valide pour la livraison
        $validStatuses = [Booking::STATUS_IN_TRANSIT, Booking::STATUS_PAYMENT_CONFIRMED, Booking::STATUS_PAID];
        if (!in_array($booking->status, $validStatuses)) {
            error_log("SECURITY: Invalid booking status {$booking->status} for delivery validation on booking {$booking->id}");
            return [
                'success' => false,
                'error' => 'Cette réservation n\'est pas dans un état valide pour la validation de livraison',
            ];
        }

        // SÉCURITÉ: Vérifier qu'il y a bien un paiement confirmé/payé
        if (!$booking->payment_authorization_id) {
            error_log("SECURITY: No payment authorization for booking {$booking->id} during delivery validation");
            return [
                'success' => false,
                'error' => 'Aucun paiement confirmé trouvé pour cette réservation',
            ];
        }

        // Log de tentative de validation
        error_log("DELIVERY: Code validation attempt for booking {$booking->id} by user {$user->id} with code '{$inputCode}'");

        // Valider le code
        $result = $deliveryCode->validateAttempt($inputCode, $user->id, $latitude, $longitude);

        if ($result['success']) {
            // Log du succès de validation
            error_log("DELIVERY: Successful code validation for booking {$booking->id} by user {$user->id}");
            // Marquer le code comme utilisé
            $deliveryCode->markAsUsed($latitude, $longitude, $photos);

            // Marquer la réservation comme confirmée
            $booking->delivery_confirmed_at = Carbon::now();
            $booking->delivery_confirmed_by = $user->id;
            $booking->status = Booking::STATUS_COMPLETED;
            $booking->save();

            // Notifier toutes les parties
            $this->notifyDeliveryConfirmed($booking, $deliveryCode, $user);

            // Déclencher la libération du paiement
            try {
                $this->triggerPaymentRelease($booking);
                $result['message'] = 'Livraison confirmée avec succès. Le paiement a été automatiquement transféré au transporteur.';
                error_log("PAYMENT: Automatic payment capture completed for booking {$booking->id}");
            } catch (Exception $e) {
                error_log("PAYMENT_ERROR: Failed to capture payment for booking {$booking->id}: " . $e->getMessage());
                $result['message'] = 'Livraison confirmée mais erreur lors du transfert de paiement. Un administrateur va vérifier.';
                $result['payment_warning'] = true;
            }
        } else {
            // Log de l'échec de validation
            error_log("DELIVERY: Failed code validation for booking {$booking->id} by user {$user->id}: " . ($result['error'] ?? 'Unknown error'));
        }

        return $result;
    }

    /**
     * Régénère un code de livraison (en cas de perte)
     */
    public function regenerateDeliveryCode(
        Booking $booking,
        User $requestingUser,
        string $reason = null
    ): DeliveryCode {
        // Vérifier que l'utilisateur est autorisé (expéditeur uniquement)
        if ($requestingUser->id !== $booking->sender_id) {
            throw new Exception('Seul l\'expéditeur peut régénérer le code de livraison');
        }

        // Récupérer le code actuel
        $currentCode = DeliveryCode::where('booking_id', $booking->id)
            ->where('status', DeliveryCode::STATUS_ACTIVE)
            ->first();

        if (!$currentCode) {
            throw new Exception('Aucun code actif à régénérer');
        }

        // Régénérer le code
        $newCode = $currentCode->regenerate($requestingUser->id, $reason);

        // Envoyer le nouveau code
        $this->sendCodeToSender($newCode);

        // Notifier que le code a été régénéré
        $this->notifyCodeRegenerated($booking, $newCode, $requestingUser);

        return $newCode;
    }

    /**
     * Récupère le code actif pour une réservation
     */
    public function getActiveDeliveryCode(Booking $booking): ?DeliveryCode
    {
        return DeliveryCode::where('booking_id', $booking->id)
            ->where('status', DeliveryCode::STATUS_ACTIVE)
            ->first();
    }

    /**
     * Vérifie si une réservation nécessite un code de livraison
     */
    public function requiresDeliveryCode(Booking $booking): bool
    {
        // Un code est requis si :
        // 1. La réservation est acceptée/confirmée
        // 2. Le voyage n'est pas encore arrivé ou vient d'arriver (dans les 48h)
        // 3. Pas encore de confirmation de livraison

        if ($booking->status !== Booking::STATUS_ACCEPTED) {
            return false;
        }

        if ($booking->delivery_confirmed_at !== null) {
            return false;
        }

        $trip = $booking->trip;
        $arrivalDate = Carbon::parse($trip->arrival_date);
        $now = Carbon::now();

        // Le code est requis entre 24h avant l'arrivée et 48h après
        $requirementStartDate = $arrivalDate->copy()->subHours(24);
        $requirementEndDate = $arrivalDate->copy()->addHours(48);

        return $now->between($requirementStartDate, $requirementEndDate);
    }

    /**
     * Nettoie les codes expirés
     */
    public function cleanExpiredCodes(): int
    {
        return DeliveryCode::cleanExpiredCodes();
    }

    /**
     * Notifie la confirmation de livraison
     */
    private function notifyDeliveryConfirmed(
        Booking $booking,
        DeliveryCode $deliveryCode,
        User $confirmingUser
    ): void {
        $sender = $booking->sender;
        $receiver = $booking->receiver;
        $trip = $booking->trip;

        // Email à l'expéditeur
        $emailData = [
            'sender_name' => $sender->first_name,
            'receiver_name' => $receiver->first_name,
            'confirming_user' => $confirmingUser->first_name,
            'booking_reference' => $booking->uuid,
            'package_description' => $booking->package_description,
            'confirmed_at' => $booking->delivery_confirmed_at->format('d/m/Y à H:i'),
            'trip_route' => "{$trip->departure_city} → {$trip->arrival_city}",
        ];

        $this->notificationService->sendEmail(
            $sender->email,
            'Livraison confirmée',
            'delivery_confirmed',
            $emailData
        );

        // Email au destinataire (voyageur)
        $this->notificationService->sendEmail(
            $receiver->email,
            'Livraison confirmée',
            'delivery_confirmed_receiver',
            $emailData
        );

        // Notifications push
        $this->smartNotificationService->sendDeliveryConfirmed($sender, $booking);
        $this->smartNotificationService->sendDeliveryConfirmed($receiver, $booking);
    }

    /**
     * Notifie qu'un code a été régénéré
     */
    private function notifyCodeRegenerated(
        Booking $booking,
        DeliveryCode $newCode,
        User $requestingUser
    ): void {
        $trip = $booking->trip;

        // Email de confirmation
        $emailData = [
            'user_name' => $requestingUser->first_name,
            'new_delivery_code' => $newCode->code,
            'booking_reference' => $booking->uuid,
            'trip_route' => "{$trip->departure_city} → {$trip->arrival_city}",
            'expires_at' => $newCode->expires_at->format('d/m/Y à H:i'),
        ];

        $this->notificationService->sendEmail(
            $requestingUser->email,
            'Nouveau code de livraison généré',
            'delivery_code_regenerated',
            $emailData
        );

        // Notification push
        $this->smartNotificationService->sendDeliveryCodeRegenerated(
            $requestingUser,
            $newCode->code,
            $booking
        );
    }

    /**
     * Déclenche la libération du paiement
     */
    private function triggerPaymentRelease(Booking $booking): void
    {
        try {
            // Vérifier qu'il y a bien une autorisation de paiement
            if (!$booking->payment_authorization_id) {
                error_log("No payment authorization found for booking {$booking->id}");
                return;
            }

            // Vérifier que le paiement est dans un état capturable
            $paymentAuth = $booking->paymentAuthorization;
            if (!$paymentAuth || !$paymentAuth->canBeCaptured()) {
                error_log("Payment authorization {$booking->payment_authorization_id} cannot be captured");
                return;
            }

            // Utiliser le service de paiement pour capturer
            $paymentService = new PaymentAuthorizationService();
            $success = $paymentService->capturePayment(
                $paymentAuth,
                PaymentAuthorization::CAPTURE_REASON_DELIVERY_CONFIRMED
            );

            if ($success) {
                // Mettre à jour le statut de la réservation
                $booking->update([
                    'status' => Booking::STATUS_PAID,
                    'payment_captured_at' => Carbon::now(),
                ]);

                // Log du succès
                error_log("Payment successfully captured for booking {$booking->id} after delivery confirmation");

                // Notifier les parties prenantes
                $this->notifyPaymentCaptured($booking);
            } else {
                error_log("Failed to capture payment for booking {$booking->id}");
                throw new Exception('Échec de la capture du paiement');
            }

        } catch (Exception $e) {
            error_log("Error capturing payment for booking {$booking->id}: " . $e->getMessage());
            throw new Exception('Erreur lors de la capture du paiement: ' . $e->getMessage());
        }
    }

    /**
     * Notifie les parties prenantes de la capture du paiement
     */
    private function notifyPaymentCaptured(Booking $booking): void
    {
        try {
            $smartNotificationService = new SmartNotificationService();

            // Notifier l'expéditeur que le paiement a été capturé
            $smartNotificationService->notifyPaymentCaptured(
                $booking->sender,
                $booking,
                'Le paiement a été transféré au transporteur suite à la livraison confirmée.'
            );

            // Notifier le transporteur que le paiement a été reçu
            $smartNotificationService->notifyPaymentReceived(
                $booking->receiver,
                $booking,
                'Vous avez reçu le paiement suite à la livraison confirmée.'
            );

        } catch (Exception $e) {
            error_log("Error sending payment capture notifications for booking {$booking->id}: " . $e->getMessage());
        }
    }

    /**
     * Statistiques des codes de livraison
     */
    public function getDeliveryCodeStats(int $days = 30): array
    {
        $startDate = Carbon::now()->subDays($days);

        return [
            'total_generated' => DeliveryCode::where('created_at', '>=', $startDate)->count(),
            'successfully_used' => DeliveryCode::where('status', DeliveryCode::STATUS_USED)
                ->where('used_at', '>=', $startDate)
                ->count(),
            'expired' => DeliveryCode::where('status', DeliveryCode::STATUS_EXPIRED)
                ->where('updated_at', '>=', $startDate)
                ->count(),
            'currently_active' => DeliveryCode::where('status', DeliveryCode::STATUS_ACTIVE)->count(),
            'total_attempts' => DeliveryCodeAttempt::where('attempted_at', '>=', $startDate)->count(),
            'failed_attempts' => DeliveryCodeAttempt::where('success', false)
                ->where('attempted_at', '>=', $startDate)
                ->count(),
        ];
    }
}