<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Brevo\Client\ApiException;
use Brevo\Client\Api\TransactionalEmailsApi;
use Brevo\Client\Configuration;
use Brevo\Client\Model\SendSmtpEmail;
use Brevo\Client\Model\SendSmtpEmailSender;
use Brevo\Client\Model\SendSmtpEmailTo;
use GuzzleHttp\Client;

class EmailService
{
    private TransactionalEmailsApi $emailApi;
    private string $fromEmail;
    private string $fromName;
    private string $devEmail;
    private bool $isDev;

    public function __construct()
    {
        $apiKey = $_ENV['BREVO_API_KEY'] ?? '';
        $this->fromEmail = $_ENV['MAIL_FROM'] ?? 'noreply@kiloshare.com';
        $this->fromName = 'KiloShare';
        $this->devEmail = $_ENV['DEV_EMAIL'] ?? '';
        $this->isDev = ($_ENV['APP_ENV'] ?? 'production') === 'development';
        
        if (empty($apiKey)) {
            throw new \Exception('BREVO_API_KEY not configured');
        }

        // Configuration Brevo (suppress deprecation warnings for now)
        $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);
        
        $config = Configuration::getDefaultConfiguration()->setApiKey('api-key', $apiKey);
        $this->emailApi = new TransactionalEmailsApi(
            new Client(),
            $config
        );
        
        error_reporting($oldErrorReporting);
    }

    /**
     * Envoyer un email de vérification
     */
    public function sendEmailVerification(string $toEmail, string $userName, string $verificationCode): bool
    {
        try {
            // En dev, rediriger vers l'email de développement
            $recipientEmail = $this->isDev && !empty($this->devEmail) ? $this->devEmail : $toEmail;
            
            $verificationUrl = $this->buildVerificationUrl($verificationCode);
            
            // Suppress deprecation warnings for Brevo models
            $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);
            
            $sendSmtpEmail = new SendSmtpEmail([
                'sender' => new SendSmtpEmailSender([
                    'name' => $this->fromName,
                    'email' => $this->fromEmail
                ]),
                'to' => [
                    new SendSmtpEmailTo([
                        'email' => $recipientEmail,
                        'name' => $userName
                    ])
                ],
                'subject' => 'Vérifiez votre email - KiloShare',
                'htmlContent' => $this->getEmailVerificationTemplate($userName, $verificationUrl, $toEmail),
                'textContent' => $this->getEmailVerificationTextTemplate($userName, $verificationUrl)
            ]);

            $result = $this->emailApi->sendTransacEmail($sendSmtpEmail);
            
            error_reporting($oldErrorReporting);
            
            error_log("Email sent successfully to {$recipientEmail} (original: {$toEmail}) - Message ID: " . $result->getMessageId());
            
            return true;
        } catch (\Exception $e) {
            error_log("Failed to send email verification to {$toEmail}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Obtenir l'URL frontend selon l'environnement
     */
    private function getFrontendUrl(): string
    {
        if ($this->isDev) {
            return $_ENV['FRONTEND_URL_DEV'] ?? 'http://localhost:3000';
        } else {
            return $_ENV['FRONTEND_URL_PROD'] ?? 'https://kiloshare.com';
        }
    }

    /**
     * Construire l'URL de vérification - Redirige vers la plateforme Next.js
     */
    private function buildVerificationUrl(string $code): string
    {
        $frontendUrl = $this->getFrontendUrl();
        return "{$frontendUrl}/verify-email?code={$code}";
    }

    /**
     * Template HTML pour l'email de vérification
     */
    private function getEmailVerificationTemplate(string $userName, string $verificationUrl, string $originalEmail): string
    {
        $devNote = $this->isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$originalEmail}</p>" : '';
        
        return "
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset='utf-8'>
            <title>Vérification email - KiloShare</title>
        </head>
        <body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
            <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;'>
                <h1 style='color: #2563eb; margin-bottom: 30px;'>Bienvenue sur KiloShare</h1>

                <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$userName}</strong>,</p>

                <p style='font-size: 16px; margin-bottom: 30px;'>
                    Merci de vous être inscrit sur KiloShare ! Pour activer votre compte et commencer à partager vos voyages,
                    veuillez vérifier votre adresse email en cliquant sur le bouton ci-dessous :
                </p>

                <a href='{$verificationUrl}'
                   style='display: inline-block; background-color: #2563eb; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; margin: 20px 0;'>
                    Vérifier mon email
                </a>
                
                <p style='font-size: 14px; color: #666; margin-top: 30px;'>
                    Si le bouton ne fonctionne pas, copiez et collez ce lien dans votre navigateur :<br>
                    <a href='{$verificationUrl}' style='color: #2563eb; word-break: break-all;'>{$verificationUrl}</a>
                </p>
                
                <p style='font-size: 14px; color: #666; margin-top: 20px;'>
                    Si vous n'avez pas créé ce compte, ignorez simplement cet email.
                </p>
                
                <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>
                
                <p style='font-size: 12px; color: #888;'>
                    Cet email a été envoyé par KiloShare<br>
                    © " . date('Y') . " KiloShare. Tous droits réservés.
                </p>
                
                {$devNote}
            </div>
        </body>
        </html>";
    }

    /**
     * Template texte pour l'email de vérification
     */
    private function getEmailVerificationTextTemplate(string $userName, string $verificationUrl): string
    {
        return "
Bienvenue sur KiloShare !

Bonjour {$userName},

Merci de vous être inscrit sur KiloShare ! Pour activer votre compte, veuillez vérifier votre adresse email en visitant ce lien :

{$verificationUrl}

Si vous n'avez pas créé ce compte, ignorez simplement cet email.

---
KiloShare Team
© " . date('Y') . " KiloShare. Tous droits réservés.
        ";
    }

    /**
     * Envoyer un email de notification générique
     */
    public function sendNotificationEmail(string $toEmail, string $userName, string $subject, string $message, ?string $actionUrl = null, ?string $actionText = null): bool
    {
        try {
            // En dev, rediriger vers l'email de développement
            $recipientEmail = $this->isDev && !empty($this->devEmail) ? $this->devEmail : $toEmail;

            // Convertir les URLs relatives en URLs absolues
            if ($actionUrl && !str_starts_with($actionUrl, 'http')) {
                $actionUrl = $this->getFrontendUrl() . $actionUrl;
            }

            // Suppress deprecation warnings for Brevo models
            $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);

            $sendSmtpEmail = new SendSmtpEmail([
                'sender' => new SendSmtpEmailSender([
                    'name' => $this->fromName,
                    'email' => $this->fromEmail
                ]),
                'to' => [
                    new SendSmtpEmailTo([
                        'email' => $recipientEmail,
                        'name' => $userName
                    ])
                ],
                'subject' => $subject,
                'htmlContent' => $this->getNotificationTemplate($userName, $subject, $message, $actionUrl, $actionText, $toEmail),
                'textContent' => $this->getNotificationTextTemplate($userName, $message, $actionUrl)
            ]);

            $result = $this->emailApi->sendTransacEmail($sendSmtpEmail);

            error_reporting($oldErrorReporting);

            error_log("Notification email sent successfully to {$recipientEmail} (original: {$toEmail}) - Message ID: " . $result->getMessageId());

            return true;
        } catch (\Exception $e) {
            error_log("Failed to send notification email to {$toEmail}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Template HTML pour l'email de notification
     */
    private function getNotificationTemplate(string $userName, string $subject, string $message, ?string $actionUrl, ?string $actionText, string $originalEmail): string
    {
        $devNote = $this->isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$originalEmail}</p>" : '';

        $actionButton = '';
        if ($actionUrl && $actionText) {
            $actionButton = "
                <div style='text-align: center; margin: 25px 0;'>
                    <a href='{$actionUrl}'
                       style='display: inline-block; background-color: #2563eb; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;'>
                        {$actionText}
                    </a>
                </div>";
        }

        return "
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>{$subject}</title>
</head>
<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
    <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px;'>
        <h1 style='color: #2563eb; margin-bottom: 30px; text-align: center;'>KiloShare</h1>

        <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$userName}</strong>,</p>

        <p style='margin: 0 0 25px 0;'>" . nl2br(htmlspecialchars($message)) . "</p>

        {$actionButton}

        <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>

        <p style='font-size: 12px; color: #888; text-align: center;'>
            Cet email a été envoyé par KiloShare<br>
            © " . date('Y') . " KiloShare. Tous droits réservés.
        </p>

        {$devNote}
    </div>
</body>
</html>";
    }

    /**
     * Template texte pour l'email de notification
     */
    private function getNotificationTextTemplate(string $userName, string $message, ?string $actionUrl): string
    {
        $actionText = '';
        if ($actionUrl) {
            $actionText = "\n\nPour plus de détails, visitez : {$actionUrl}";
        }

        return "
KiloShare Notification

Bonjour {$userName},

{$message}{$actionText}

---
KiloShare Team
© " . date('Y') . " KiloShare. Tous droits réservés.
        ";
    }

    /**
     * Envoyer un email de bienvenue après vérification du compte
     */
    public function sendWelcomeEmail(string $toEmail, string $userName): bool
    {
        try {
            // En dev, rediriger vers l'email de développement
            $recipientEmail = $this->isDev && !empty($this->devEmail) ? $this->devEmail : $toEmail;

            $dashboardUrl = $this->getFrontendUrl() . '/dashboard';

            // Suppress deprecation warnings for Brevo models
            $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);

            $sendSmtpEmail = new SendSmtpEmail([
                'sender' => new SendSmtpEmailSender([
                    'name' => $this->fromName,
                    'email' => $this->fromEmail
                ]),
                'to' => [
                    new SendSmtpEmailTo([
                        'email' => $recipientEmail,
                        'name' => $userName
                    ])
                ],
                'subject' => 'Bienvenue sur KiloShare !',
                'htmlContent' => $this->getWelcomeEmailTemplate($userName, $dashboardUrl, $toEmail),
                'textContent' => $this->getWelcomeEmailTextTemplate($userName, $dashboardUrl)
            ]);

            $result = $this->emailApi->sendTransacEmail($sendSmtpEmail);

            error_reporting($oldErrorReporting);

            error_log("Welcome email sent successfully to {$recipientEmail} (original: {$toEmail}) - Message ID: " . $result->getMessageId());

            return true;
        } catch (\Exception $e) {
            error_log("Failed to send welcome email to {$toEmail}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Template HTML pour l'email de bienvenue
     */
    private function getWelcomeEmailTemplate(string $userName, string $dashboardUrl, string $originalEmail): string
    {
        $devNote = $this->isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$originalEmail}</p>" : '';

        return "
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset='utf-8'>
            <title>Bienvenue sur KiloShare !</title>
        </head>
        <body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
            <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;'>
                <h1 style='color: #2563eb; margin-bottom: 30px;'>Bienvenue sur KiloShare !</h1>

                <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$userName}</strong>,</p>

                <p style='font-size: 16px; margin-bottom: 30px;'>
                    Félicitations ! Votre adresse email a été vérifiée avec succès. Vous faites maintenant partie de la communauté KiloShare.
                </p>

                <div style='background: white; padding: 20px; border-radius: 8px; margin: 30px 0; text-align: left;'>
                    <h2 style='color: #2563eb; font-size: 18px; margin-bottom: 15px;'>Que pouvez-vous faire sur KiloShare ?</h2>

                    <ul style='color: #333; line-height: 1.8; margin: 0; padding-left: 20px;'>
                        <li><strong>Voyagez léger</strong> : Confiez vos colis à des voyageurs de confiance</li>
                        <li><strong>Gagnez en voyageant</strong> : Transportez des colis lors de vos déplacements</li>
                        <li><strong>Restez connecté</strong> : Communiquez facilement avec les autres membres</li>
                        <li><strong>Sécurité garantie</strong> : Transactions sécurisées et système de notation</li>
                    </ul>
                </div>

                <p style='font-size: 16px; margin-bottom: 30px;'>
                    Prêt à commencer ? Connectez-vous à votre compte et explorez toutes les possibilités que KiloShare vous offre.
                </p>

                <a href='{$dashboardUrl}'
                   style='display: inline-block; background-color: #2563eb; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; margin: 20px 0;'>
                    Accéder à mon compte
                </a>

                <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>

                <p style='font-size: 14px; color: #666; margin-top: 20px;'>
                    Besoin d'aide ? N'hésitez pas à consulter notre centre d'aide ou à nous contacter.
                </p>

                <p style='font-size: 12px; color: #888;'>
                    Cet email a été envoyé par KiloShare<br>
                    © " . date('Y') . " KiloShare. Tous droits réservés.
                </p>

                {$devNote}
            </div>
        </body>
        </html>";
    }

    /**
     * Template texte pour l'email de bienvenue
     */
    private function getWelcomeEmailTextTemplate(string $userName, string $dashboardUrl): string
    {
        return "
Bienvenue sur KiloShare !

Bonjour {$userName},

Félicitations ! Votre adresse email a été vérifiée avec succès. Vous faites maintenant partie de la communauté KiloShare.

Que pouvez-vous faire sur KiloShare ?

- Voyagez léger : Confiez vos colis à des voyageurs de confiance
- Gagnez en voyageant : Transportez des colis lors de vos déplacements
- Restez connecté : Communiquez facilement avec les autres membres
- Sécurité garantie : Transactions sécurisées et système de notation

Prêt à commencer ? Connectez-vous à votre compte et explorez toutes les possibilités que KiloShare vous offre.

Accédez à votre compte : {$dashboardUrl}

Besoin d'aide ? N'hésitez pas à consulter notre centre d'aide ou à nous contacter.

---
KiloShare Team
© " . date('Y') . " KiloShare. Tous droits réservés.
        ";
    }

    /**
     * Envoyer un email HTML personnalisé
     */
    public function sendHtmlEmail(string $toEmail, string $userName, string $subject, string $htmlContent): bool
    {
        try {
            // En dev, rediriger vers l'email de développement
            $recipientEmail = $this->isDev && !empty($this->devEmail) ? $this->devEmail : $toEmail;

            // Suppress deprecation warnings for Brevo models
            $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);

            $sendSmtpEmail = new SendSmtpEmail([
                'sender' => new SendSmtpEmailSender([
                    'name' => $this->fromName,
                    'email' => $this->fromEmail
                ]),
                'to' => [
                    new SendSmtpEmailTo([
                        'email' => $recipientEmail,
                        'name' => $userName
                    ])
                ],
                'subject' => $subject,
                'htmlContent' => $htmlContent
            ]);

            $result = $this->emailApi->sendTransacEmail($sendSmtpEmail);

            error_reporting($oldErrorReporting);

            error_log("HTML email sent successfully to {$recipientEmail} (original: {$toEmail}) - Message ID: " . $result->getMessageId());

            return true;
        } catch (\Exception $e) {
            error_log("Failed to send HTML email to {$toEmail}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoyer un email de nouvelle demande de réservation
     */
    public function sendBookingRequestEmail(string $toEmail, string $transporterName, array $bookingData): bool
    {
        try {
            $recipientEmail = $this->isDev && !empty($this->devEmail) ? $this->devEmail : $toEmail;

            $htmlContent = $this->getBookingRequestTemplate($transporterName, $bookingData, $toEmail);

            $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);

            $sendSmtpEmail = new SendSmtpEmail([
                'sender' => new SendSmtpEmailSender([
                    'name' => $this->fromName,
                    'email' => $this->fromEmail
                ]),
                'to' => [
                    new SendSmtpEmailTo([
                        'email' => $recipientEmail,
                        'name' => $transporterName
                    ])
                ],
                'subject' => '📦 Nouvelle demande de réservation',
                'htmlContent' => $htmlContent
            ]);

            $result = $this->emailApi->sendTransacEmail($sendSmtpEmail);

            error_reporting($oldErrorReporting);

            error_log("Booking request email sent successfully to {$recipientEmail} (original: {$toEmail}) - Message ID: " . $result->getMessageId());

            return true;
        } catch (\Exception $e) {
            error_log("Failed to send booking request email to {$toEmail}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Template HTML pour l'email de nouvelle demande
     */
    private function getBookingRequestTemplate(string $transporterName, array $bookingData, string $originalEmail): string
    {
        $devNote = $this->isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$originalEmail}</p>" : '';

        $senderName = $bookingData['sender_name'] ?? 'Expéditeur';
        $weight = $bookingData['weight'] ?? 0;
        $price = number_format($bookingData['price'] ?? 0, 2);
        $packageDescription = htmlspecialchars($bookingData['package_description'] ?? 'Non spécifié');
        $bookingReference = $bookingData['booking_reference'] ?? '';
        $tripRoute = $bookingData['trip_route'] ?? '';
        $actionUrl = $bookingData['action_url'] ?? $this->getFrontendUrl() . '/bookings';

        return "
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Nouvelle demande de réservation</title>
</head>
<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
    <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px;'>
        <h1 style='color: #2563eb; margin-bottom: 30px; text-align: center;'>KiloShare</h1>

        <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$transporterName}</strong>,</p>

        <p style='margin: 0 0 25px 0;'>Vous avez reçu une nouvelle demande de réservation pour votre voyage.</p>

        <div style='background-color: #f0f9ff; padding: 25px; margin: 20px 0; border-radius: 8px;'>
            <h2 style='color: #2563eb; font-size: 20px; margin: 0 0 20px 0;'>Détails de la demande</h2>
            <ul style='line-height: 1.8; margin: 0; padding-left: 20px;'>
                <li><strong>Expéditeur:</strong> {$senderName}</li>
                <li><strong>Trajet:</strong> {$tripRoute}</li>
                <li><strong>Poids demandé:</strong> {$weight} kg</li>
                <li><strong>Prix:</strong> {$price} CAD</li>
                <li><strong>Description du colis:</strong> {$packageDescription}</li>" .
                ($bookingReference ? "<li><strong>Référence:</strong> {$bookingReference}</li>" : "") .
            "</ul>
        </div>

        <div style='text-align: center; margin: 25px 0;'>
            <a href='{$actionUrl}'
               style='display: inline-block; background-color: #2563eb; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;'>
                Voir la demande
            </a>
        </div>

        <div style='background-color: #f0f9ff; border-left: 4px solid #2563eb; padding: 15px; margin-top: 20px; border-radius: 4px;'>
            <p style='margin: 0; font-size: 14px;'><strong>💡 Conseil:</strong> Consultez le profil de l'expéditeur et acceptez ou refusez cette demande depuis votre espace réservations.</p>
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
    }

    /**
     * Envoyer un email de livraison confirmée
     */
    public function sendDeliveryConfirmedEmail(string $toEmail, string $userName, array $deliveryData): bool
    {
        try {
            $recipientEmail = $this->isDev && !empty($this->devEmail) ? $this->devEmail : $toEmail;

            $htmlContent = $this->getDeliveryConfirmedTemplate($userName, $deliveryData, $toEmail);

            $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);

            $sendSmtpEmail = new SendSmtpEmail([
                'sender' => new SendSmtpEmailSender([
                    'name' => $this->fromName,
                    'email' => $this->fromEmail
                ]),
                'to' => [
                    new SendSmtpEmailTo([
                        'email' => $recipientEmail,
                        'name' => $userName
                    ])
                ],
                'subject' => '✅ Livraison confirmée avec succès',
                'htmlContent' => $htmlContent
            ]);

            $result = $this->emailApi->sendTransacEmail($sendSmtpEmail);

            error_reporting($oldErrorReporting);

            error_log("Delivery confirmed email sent successfully to {$recipientEmail} (original: {$toEmail}) - Message ID: " . $result->getMessageId());

            return true;
        } catch (\Exception $e) {
            error_log("Failed to send delivery confirmed email to {$toEmail}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Template HTML pour l'email de livraison confirmée
     */
    private function getDeliveryConfirmedTemplate(string $userName, array $deliveryData, string $originalEmail): string
    {
        $devNote = $this->isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$originalEmail}</p>" : '';

        $packageDescription = htmlspecialchars($deliveryData['package_description'] ?? 'Colis');
        $bookingReference = $deliveryData['booking_reference'] ?? '';
        $tripRoute = $deliveryData['trip_route'] ?? '';
        $confirmedAt = $deliveryData['confirmed_at'] ?? date('d/m/Y à H:i');
        $isReceiver = $deliveryData['is_receiver'] ?? false;
        $senderName = $deliveryData['sender_name'] ?? 'l\'expéditeur';
        $receiverName = $deliveryData['receiver_name'] ?? 'le destinataire';
        $actionUrl = $deliveryData['action_url'] ?? $this->getFrontendUrl() . '/bookings';

        $role = $isReceiver ? 'destinataire' : 'expéditeur';
        $otherParty = $isReceiver ? $senderName : $receiverName;

        return "
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Livraison confirmée</title>
</head>
<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
    <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px;'>
        <h1 style='color: #2563eb; margin-bottom: 30px; text-align: center;'>KiloShare</h1>

        <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$userName}</strong>,</p>

        <p style='margin: 0 0 25px 0;'>Nous avons le plaisir de vous informer que la livraison de votre colis a été confirmée avec succès !</p>

        <div style='background-color: #d1fae5; padding: 25px; margin: 20px 0; border-radius: 8px; text-align: center;'>
            <div style='font-size: 48px; margin-bottom: 10px;'>✅</div>
            <p style='color: #065f46; margin: 0; font-size: 18px; font-weight: bold;'>Livraison confirmée</p>
            <p style='color: #047857; margin: 10px 0 0 0; font-size: 14px;'>Le {$confirmedAt}</p>
        </div>

        <div style='background-color: #f0f9ff; padding: 25px; margin: 20px 0; border-radius: 8px;'>
            <h2 style='color: #2563eb; font-size: 20px; margin: 0 0 20px 0;'>Détails de la livraison</h2>
            <ul style='line-height: 1.8; margin: 0; padding-left: 20px;'>
                <li><strong>Colis:</strong> {$packageDescription}</li>
                <li><strong>Trajet:</strong> {$tripRoute}</li>" .
                ($bookingReference ? "<li><strong>Référence:</strong> {$bookingReference}</li>" : "") .
                "<li><strong>Date de confirmation:</strong> {$confirmedAt}</li>
            </ul>
        </div>

        <div style='text-align: center; margin: 25px 0;'>
            <a href='{$actionUrl}'
               style='display: inline-block; background-color: #2563eb; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;'>
                Voir mes réservations
            </a>
        </div>

        <div style='background-color: #d1fae5; border-left: 4px solid #10b981; padding: 15px; margin-top: 20px; border-radius: 4px;'>
            <p style='margin: 0; font-size: 14px; color: #065f46;'><strong>🎉 Félicitations !</strong> Votre transaction est maintenant terminée. Le paiement sera traité selon les conditions convenues.</p>
        </div>

        <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>

        <p style='font-size: 14px; color: #666; margin-top: 20px; text-align: center;'>
            Merci d'utiliser KiloShare pour vos envois !
        </p>

        <p style='font-size: 12px; color: #888; text-align: center;'>
            Cet email a été envoyé par KiloShare<br>
            © " . date('Y') . " KiloShare. Tous droits réservés.
        </p>

        {$devNote}
    </div>
</body>
</html>
";
    }

    /**
     * Envoyer un email de réservation acceptée
     */
    public function sendBookingAcceptedEmail(string $toEmail, string $userName, array $bookingData): bool
    {
        try {
            // En dev, rediriger vers l'email de développement
            $recipientEmail = $this->isDev && !empty($this->devEmail) ? $this->devEmail : $toEmail;

            $subject = '✅ Votre réservation a été acceptée';

            // Convertir les URLs relatives en URLs absolues
            $actionUrl = $bookingData['action_url'] ?? null;
            if ($actionUrl && !str_starts_with($actionUrl, 'http')) {
                $actionUrl = $this->getFrontendUrl() . $actionUrl;
            }

            // Suppress deprecation warnings for Brevo models
            $oldErrorReporting = error_reporting(E_ALL & ~E_DEPRECATED);

            $sendSmtpEmail = new SendSmtpEmail([
                'sender' => new SendSmtpEmailSender([
                    'name' => $this->fromName,
                    'email' => $this->fromEmail
                ]),
                'to' => [
                    new SendSmtpEmailTo([
                        'email' => $recipientEmail,
                        'name' => $userName
                    ])
                ],
                'subject' => $subject,
                'htmlContent' => $this->getBookingAcceptedTemplate($userName, $bookingData, $toEmail),
            ]);

            $result = $this->emailApi->sendTransacEmail($sendSmtpEmail);

            error_reporting($oldErrorReporting);

            error_log("Booking accepted email sent successfully to {$recipientEmail} (original: {$toEmail})");

            return true;
        } catch (\Exception $e) {
            error_log("Failed to send booking accepted email to {$toEmail}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Template HTML pour l'email de réservation acceptée (style simple inspiré du welcome)
     */
    private function getBookingAcceptedTemplate(string $userName, array $data, string $originalEmail): string
    {
        $devNote = $this->isDev ? "<p style='color: #ff6b6b; font-size: 12px; margin-top: 20px;'><strong>Note dev:</strong> Cet email était destiné à {$originalEmail}</p>" : '';

        $transporterName = htmlspecialchars($data['transporter_name'] ?? 'Le transporteur');
        $tripTitle = htmlspecialchars($data['trip_title'] ?? 'Votre voyage');
        $totalAmount = number_format((float)($data['total_amount'] ?? 0), 2);
        $actionUrl = $data['action_url'] ?? '#';

        $actionButton = '';
        if ($actionUrl !== '#') {
            $actionButton = "
                <a href='{$actionUrl}'
                   style='display: inline-block; background-color: #10b981; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; margin: 20px 0;'>
                    Voir ma réservation
                </a>";
        }

        return "
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <title>Réservation acceptée</title>
</head>
<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>
    <div style='background-color: #f8f9fa; padding: 30px; border-radius: 10px; text-align: center;'>
        <h1 style='color: #2563eb; margin-bottom: 30px;'>✅ Réservation acceptée</h1>

        <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$userName}</strong>,</p>

        <p style='font-size: 16px; margin-bottom: 30px;'>
            Bonne nouvelle ! <strong>{$transporterName}</strong> a accepté votre demande de transport pour le voyage <strong>{$tripTitle}</strong>.
        </p>

        <div style='background: white; padding: 20px; border-radius: 8px; margin: 30px 0;'>
            <p style='font-size: 18px; color: #10b981; font-weight: bold; margin: 0;'>
                Montant : {$totalAmount} CAD
            </p>
        </div>

        <p style='font-size: 16px; margin-bottom: 30px;'>
            Le transporteur récupérera votre colis à l'adresse convenue. Vous recevrez un code de livraison à communiquer au destinataire.
        </p>

        {$actionButton}

        <hr style='margin: 30px 0; border: none; border-top: 1px solid #ddd;'>

        <p style='font-size: 14px; color: #666; margin-top: 20px;'>
            Besoin d'aide ? N'hésitez pas à nous contacter.
        </p>

        <p style='font-size: 12px; color: #888;'>
            Cet email a été envoyé par KiloShare<br>
            © " . date('Y') . " KiloShare. Tous droits réservés.
        </p>

        {$devNote}
    </div>
</body>
</html>
";
    }
}