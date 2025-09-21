<?php

declare(strict_types=1);

namespace KiloShare\Services;

use KiloShare\Models\Booking;
use KiloShare\Models\DeliveryCode;
use KiloShare\Models\DeliveryCodeAttempt;
use KiloShare\Models\User;
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

        // Vérifier que l'utilisateur est autorisé (destinataire ou expéditeur)
        if ($user->id !== $booking->receiver_id && $user->id !== $booking->sender_id) {
            return [
                'success' => false,
                'error' => 'Vous n\'êtes pas autorisé à valider ce code de livraison',
            ];
        }

        // Valider le code
        $result = $deliveryCode->validateAttempt($inputCode, $user->id, $latitude, $longitude);

        if ($result['success']) {
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
            $this->triggerPaymentRelease($booking);

            $result['message'] = 'Livraison confirmée avec succès. Le paiement va être libéré.';
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
        // TODO: Intégrer avec le service de paiement Stripe
        // pour libérer les fonds en attente

        // Pour l'instant, log de l'action
        error_log("Payment release triggered for booking {$booking->id}");

        // Dans une implémentation complète, ceci appellerait
        // le service de paiement pour capturer/libérer les fonds
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