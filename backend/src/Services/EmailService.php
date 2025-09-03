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
     * Construire l'URL de vérification
     */
    private function buildVerificationUrl(string $code): string
    {
        $baseUrl = $_ENV['API_BASE_URL'] ?? 'http://localhost:8080';
        return "{$baseUrl}/api/v1/auth/verify-email?code={$code}";
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
                <h1 style='color: #2563eb; margin-bottom: 30px;'>🚀 Bienvenue sur KiloShare !</h1>
                
                <p style='font-size: 16px; margin-bottom: 20px;'>Bonjour <strong>{$userName}</strong>,</p>
                
                <p style='font-size: 16px; margin-bottom: 30px;'>
                    Merci de vous être inscrit sur KiloShare ! Pour activer votre compte et commencer à partager vos voyages, 
                    veuillez vérifier votre adresse email en cliquant sur le bouton ci-dessous :
                </p>
                
                <a href='{$verificationUrl}' 
                   style='display: inline-block; background-color: #2563eb; color: white; padding: 15px 30px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; margin: 20px 0;'>
                    ✉️ Vérifier mon email
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
}