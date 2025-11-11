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
use KiloShare\Services\EmailService;
use Carbon\Carbon;
use Exception;

class DeliveryCodeService
{
    private NotificationService $notificationService;
    private SmartNotificationService $smartNotificationService;
    private EmailService $emailService;

    public function __construct(
        NotificationService $notificationService,
        SmartNotificationService $smartNotificationService,
        EmailService $emailService
    ) {
        $this->notificationService = $notificationService;
        $this->smartNotificationService = $smartNotificationService;
        $this->emailService = $emailService;
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

        // Calculer la date d'expiration (48h après l'arrivée du voyage)
        $trip = $booking->trip;
        $arrivalDate = Carbon::parse($trip->arrival_date);
        $expiresAt = $arrivalDate->addHours(DeliveryCode::EXPIRY_HOURS_AFTER_ARRIVAL);

        // Créer le nouveau code
        $deliveryCode = new DeliveryCode([
            'booking_id' => $booking->id,
            'status' => DeliveryCode::STATUS_ACTIVE,
            'generated_by' => $booking->receiver_id, // Le transporteur qui génère le code
            'generated_at' => Carbon::now(),
            'expires_at' => $expiresAt,
        ]);

        $deliveryCode->save();

        // Recharger les relations nécessaires pour l'envoi d'email
        $booking->load(['sender', 'receiver', 'trip']);

        // Envoyer le code à l'expéditeur
        $this->sendCodeToSender($deliveryCode, $booking);

        return $deliveryCode;
    }

    /**
     * Envoie le code de livraison à l'expéditeur (pas au destinataire)
     */
    private function sendCodeToSender(DeliveryCode $deliveryCode, Booking $booking): void
    {
        try {
            $sender = $booking->sender; // L'expéditeur du colis
            $trip = $booking->trip;

            if (!$sender || !$trip) {
                error_log("Missing relations - Sender: " . ($sender ? 'OK' : 'NULL') . ", Trip: " . ($trip ? 'OK' : 'NULL'));
                return;
            }

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

        // Créer le contenu HTML de l'email avec le design standard KiloShare
        $isDev = ($_ENV['APP_ENV'] ?? 'production') === 'development';
        $devNote = $isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$sender->email}</p>" : '';

        $emailHtml = "
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset='utf-8'>
            <title>Code de livraison KiloShare</title>
        </head>
        <body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
            <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px;'>
                <h1 style='color: #2563eb; margin-bottom: 30px; text-align: center;'>KiloShare</h1>

                <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$sender->first_name}</strong>,</p>

                <p style='margin: 0 0 25px 0;'>Votre code de livraison a été généré avec succès.</p>

                <div style='background-color: #f0f9ff; padding: 25px; margin: 20px 0; border-radius: 8px; text-align: center;'>
                    <div style='font-size: 48px; font-weight: bold; color: #2563eb; letter-spacing: 8px; margin-bottom: 10px;'>{$deliveryCode->code}</div>
                    <p style='color: #64748b; margin: 0; font-size: 14px;'>Code de livraison</p>
                </div>

                <p style='margin: 20px 0 10px 0;'><strong>Détails de la réservation:</strong></p>
                <ul style='line-height: 1.8; margin: 0 0 20px 0; padding-left: 20px;'>
                    <li><strong>Référence:</strong> {$booking->uuid}</li>
                    <li><strong>Trajet:</strong> {$trip->departure_city} → {$trip->arrival_city}</li>
                    <li><strong>Arrivée prévue:</strong> {$trip->arrival_date->format('d/m/Y à H:i')}</li>
                    <li><strong>Expiration du code:</strong> {$deliveryCode->expires_at->format('d/m/Y à H:i')}</li>
                </ul>

                <div style='background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin-top: 20px; border-radius: 4px;'>
                    <p style='margin: 0; font-size: 14px;'><strong>⚠️ Important:</strong> Communiquez ce code au transporteur lors de la livraison. Le transporteur devra saisir ce code pour confirmer la réception de votre colis.</p>
                </div>

                <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>

                <p style='font-size: 12px; color: #888; text-align: center;'>
                    Cet email a été envoyé par KiloShare<br>
                    © " . date('Y') . " KiloShare. Tous droits réservés.
                </p>

                {$devNote}
            </div>
        </body>
        </html>
        ";

        // Envoyer UN SEUL email
        try {
            $this->emailService->sendHtmlEmail(
                $sender->email,
                $sender->first_name,
                'Code de livraison KiloShare - Réf: ' . $booking->uuid,
                $emailHtml
            );
            error_log("Delivery code email sent successfully to {$sender->email}");
        } catch (\Exception $e) {
            error_log("Failed to send delivery code email: " . $e->getMessage());
        }

        // 🔔 Envoyer une notification FCM push à l'expéditeur
        try {
            $this->smartNotificationService->send(
                $sender->id,
                'delivery_code_generated',
                [
                    'delivery_code' => $deliveryCode->code,
                    'booking_id' => $booking->id,
                    'booking_reference' => $booking->uuid,
                    'package_description' => $booking->package_description,
                    'receiver_name' => $booking->receiver->first_name,
                    'trip_route' => $trip->departure_city . ' → ' . $trip->arrival_city,
                    'message' => 'Votre code de livraison a été généré',
                ],
                [
                    'channels' => ['push', 'in_app'],
                    'priority' => 'high'
                ]
            );
            error_log("Delivery code push notification sent to user {$sender->id}");
        } catch (\Exception $e) {
            error_log("Failed to send delivery code push notification: " . $e->getMessage());
        }
        } catch (\Exception $e) {
            error_log("Error in sendCodeToSender: " . $e->getMessage());
            error_log("Stack trace: " . $e->getTraceAsString());
        }
    }

    /**
     * Valide un code de livraison saisi par le destinataire
     */
    public function validateDeliveryCode(
        Booking $booking,
        string $inputCode,
        User $user,
        ?float $latitude = null,
        ?float $longitude = null,
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
        $validStatuses = [
            Booking::STATUS_ACCEPTED,
            Booking::STATUS_IN_TRANSIT,
            Booking::STATUS_PAYMENT_CONFIRMED,
            Booking::STATUS_PAID
        ];
        if (!in_array($booking->status, $validStatuses)) {
            error_log("SECURITY: Invalid booking status {$booking->status} for delivery validation on booking {$booking->id}");
            return [
                'success' => false,
                'error' => 'Cette réservation n\'est pas dans un état valide pour la validation de livraison',
            ];
        }

        // SÉCURITÉ: Vérifier qu'il y a bien un paiement confirmé/payé
        // En développement, on autorise la validation pour les bookings accepted sans paiement
        if (!$booking->payment_authorization_id && $booking->status !== Booking::STATUS_ACCEPTED) {
            error_log("SECURITY: No payment authorization for booking {$booking->id} during delivery validation");
            return [
                'success' => false,
                'error' => 'Aucun paiement confirmé trouvé pour cette réservation',
            ];
        }

        // Log de tentative de validation
        error_log("DELIVERY: Code validation attempt for booking {$booking->id} by user {$user->id} with code '{$inputCode}'");

        // Valider le code
        $result = $deliveryCode->validateAttempt($inputCode);

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
        ?string $reason = null
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

        // Emails de confirmation de livraison
        $isDev = ($_ENV['APP_ENV'] ?? 'production') === 'development';
        $devNoteSender = $isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$sender->email}</p>" : '';
        $devNoteReceiver = $isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$receiver->email}</p>" : '';

        try {
            // Email à l'expéditeur
            $senderEmailHtml = "
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Livraison confirmée - KiloShare</title>
</head>
<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
    <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px;'>
        <h1 style='color: #2563eb; margin-bottom: 30px; text-align: center;'>KiloShare</h1>

        <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$sender->first_name}</strong>,</p>

        <p style='margin: 0 0 25px 0;'>La livraison de votre colis a été confirmée avec succès.</p>

        <p style='margin: 20px 0 10px 0;'><strong>Détails de la livraison:</strong></p>
        <ul style='line-height: 1.8; margin: 0 0 20px 0; padding-left: 20px;'>
            <li><strong>Référence:</strong> {$booking->uuid}</li>
            <li><strong>Trajet:</strong> {$trip->departure_city} → {$trip->arrival_city}</li>
            <li><strong>Colis:</strong> {$booking->package_description}</li>
            <li><strong>Confirmée le:</strong> {$booking->delivery_confirmed_at->format('d/m/Y à H:i')}</li>
        </ul>

        <div style='background-color: #dcfce7; padding: 15px; margin-top: 20px; border-radius: 4px;'>
            <p style='margin: 0; font-size: 14px;'><strong>✅ Transaction terminée:</strong> Votre colis a été livré avec succès. Merci d'avoir utilisé KiloShare !</p>
        </div>

        <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>

        <p style='font-size: 12px; color: #888; text-align: center;'>
            Cet email a été envoyé par KiloShare<br>
            © " . date('Y') . " KiloShare. Tous droits réservés.
        </p>

        {$devNoteSender}
    </div>
</body>
</html>
";

            // Email au transporteur
            $receiverEmailHtml = "
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Livraison confirmée - KiloShare</title>
</head>
<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
    <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px;'>
        <h1 style='color: #2563eb; margin-bottom: 30px; text-align: center;'>KiloShare</h1>

        <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$receiver->first_name}</strong>,</p>

        <p style='margin: 0 0 25px 0;'>Vous avez confirmé la livraison d'un colis avec succès.</p>

        <p style='margin: 20px 0 10px 0;'><strong>Détails de la livraison:</strong></p>
        <ul style='line-height: 1.8; margin: 0 0 20px 0; padding-left: 20px;'>
            <li><strong>Référence:</strong> {$booking->uuid}</li>
            <li><strong>Trajet:</strong> {$trip->departure_city} → {$trip->arrival_city}</li>
            <li><strong>Colis:</strong> {$booking->package_description}</li>
            <li><strong>Confirmée le:</strong> {$booking->delivery_confirmed_at->format('d/m/Y à H:i')}</li>
        </ul>

        <div style='background-color: #dcfce7; padding: 15px; margin-top: 20px; border-radius: 4px;'>
            <p style='margin: 0; font-size: 14px;'><strong>✅ Livraison validée:</strong> Le paiement sera traité et vous recevrez votre compensation. Merci d'avoir utilisé KiloShare !</p>
        </div>

        <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>

        <p style='font-size: 12px; color: #888; text-align: center;'>
            Cet email a été envoyé par KiloShare<br>
            © " . date('Y') . " KiloShare. Tous droits réservés.
        </p>

        {$devNoteReceiver}
    </div>
</body>
</html>
";

            $this->emailService->sendHtmlEmail(
                $sender->email,
                $sender->first_name,
                'Livraison confirmée - KiloShare',
                $senderEmailHtml
            );

            $this->emailService->sendHtmlEmail(
                $receiver->email,
                $receiver->first_name,
                'Livraison confirmée - KiloShare',
                $receiverEmailHtml
            );
        } catch (Exception $e) {
            error_log("Failed to send delivery confirmation emails: " . $e->getMessage());
        }

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