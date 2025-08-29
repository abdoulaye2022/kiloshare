<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Brevo\Client\Configuration;
use Brevo\Client\Api\TransactionalEmailsApi;
use Brevo\Client\Model\SendSmtpEmail;
use Brevo\Client\Model\SendSmtpEmailAttachment;
use KiloShare\Config\Config;
use Exception;

class MailSender
{
    private const SENDER_NAME = 'KiloShare';
    private const SENDER_EMAIL = 'noreply@kiloshare.com';

    public static function send_mail(string $subject, array $to, string $body, array $attachments = []): bool
    {
        // Validation des destinataires
        if (empty($to) || !is_array($to)) {
            error_log('Erreur : Destinataires invalides.');
            return false;
        }
        
        // Redirection des emails en développement
        $originalTo = $to;
        $to = self::redirectEmailsInDevelopment($to);
        
        // Mode test pour développement - commenté pour permettre l'envoi réel
        $appEnv = $_ENV['APP_ENV'] ?? 'production';
        $isDevMode = in_array($appEnv, ['development', 'dev', 'local', 'testing']);
        
        if ($isDevMode) {
            error_log("📧 [DEV MODE] Redirection des emails vers: " . json_encode($to));
            // On continue pour envoyer réellement l'email en dev
        }

        // Configuration de l'API Brevo
        $apiKey = Config::get('email.brevo_api_key') ?? $_ENV['BREVO_API_KEY'] ?? '';
        
        error_log("🔑 Clé API Brevo: " . substr($apiKey, 0, 10) . "...");
        
        if (empty($apiKey)) {
            error_log('❌ Erreur : Clé API Brevo manquante.');
            return false;
        }
        
        // Vérifier si la clé API semble être une vraie clé
        if ($apiKey === '922d8f39a4c6f7b21d04e3a6f1c9he8405f06bd8e7d30ab92ef7c1d64a89f02e3c') {
            error_log('⚠️  Clé API Brevo semble être une clé test/générique');
            // En dev, on va simuler mais avec plus de détails
            if ($isDevMode) {
                self::simulateEmailSending($originalTo, $to, $subject, $body);
                return true;
            }
        }

        $config = Configuration::getDefaultConfiguration()->setApiKey('api-key', $apiKey);
        $apiInstance = new TransactionalEmailsApi(null, $config);

        // Préparation des pièces jointes si nécessaire
        $attachmentObjects = [];
        if (count($attachments)) {
            foreach ($attachments as $attachment) {
                if (isset($attachment['content'], $attachment['name'])) {
                    $attachmentObjects[] = new SendSmtpEmailAttachment([
                        'content' => base64_encode($attachment['content']),
                        'name' => $attachment['name'],
                    ]);
                }
            }
        }

        // Configuration de base de l'email
        $emailConfig = [
            'subject' => $subject,
            'sender' => [
                'name' => self::SENDER_NAME,
                'email' => self::SENDER_EMAIL,
            ],
            'to' => $to,
            'htmlContent' => $body,
            'textContent' => strip_tags($body),
            'params' => ['bodyMessage' => 'made just for you!'],
            'tracking' => [
                'opens' => false,
                'clicks' => false,
                'unsubscribe' => false,
            ],
        ];

        // Ajouter les pièces jointes si présentes
        if (!empty($attachmentObjects)) {
            $emailConfig['attachment'] = $attachmentObjects;
        }

        $sendSmtpEmail = new SendSmtpEmail($emailConfig);

        try {
            $result = $apiInstance->sendTransacEmail($sendSmtpEmail);
            self::logEmailSent($originalTo, $to, $subject);
            return true;
        } catch (Exception $e) {
            error_log('Erreur lors de l\'envoi de l\'email : ' . $e->getMessage());
            return false;
        }
    }

    public static function sendEmailVerification(string $email, string $firstName, string $verificationToken): bool
    {
        $subject = 'Vérifiez votre adresse email - KiloShare';
        $to = [['email' => $email, 'name' => $firstName]];
        
        $verificationUrl = "http://localhost:3000/verify-email?token=" . $verificationToken;
        
        $body = self::headerContent('Vérification email') . "
            <!-- Contenu principal -->
            <tr>
                <td class='content' style='padding: 40px 30px; text-align: center;'>
                    <div style='max-width: 500px; margin: 0 auto;'>
                        <!-- Icône -->
                        <div style='margin-bottom: 30px;'>
                            <div style='background-color: #4096FF; width: 80px; height: 80px; border-radius: 50%; margin: 0 auto; display: flex; align-items: center; justify-content: center;'>
                                <span style='color: white; font-size: 32px; font-weight: bold;'>✉</span>
                            </div>
                        </div>
                        
                        <h1 style='color: #1A202C; font-size: 28px; font-weight: 600; margin: 0 0 20px; line-height: 1.3;'>
                            Bienvenue sur KiloShare !
                        </h1>
                        
                        <p style='color: #4A5568; font-size: 16px; line-height: 1.6; margin: 0 0 30px;'>
                            Bonjour " . htmlspecialchars($firstName) . ",<br><br>
                            Merci de vous être inscrit(e) sur KiloShare ! Pour activer votre compte et commencer à partager vos espaces bagages, veuillez vérifier votre adresse email en cliquant sur le bouton ci-dessous.
                        </p>
                        
                        <!-- Bouton de vérification -->
                        <div style='margin: 40px 0;'>
                            <a href='" . $verificationUrl . "' style='display: inline-block; background-color: #4096FF; color: white; text-decoration: none; padding: 15px 32px; border-radius: 6px; font-weight: 600; font-size: 16px; transition: background-color 0.2s;'>
                                Vérifier mon email
                            </a>
                        </div>
                        
                        <p style='color: #718096; font-size: 14px; line-height: 1.5; margin: 30px 0 0;'>
                            Si vous ne pouvez pas cliquer sur le bouton, copiez et collez ce lien dans votre navigateur :<br>
                            <a href='" . $verificationUrl . "' style='color: #4096FF; word-break: break-all;'>" . $verificationUrl . "</a>
                        </p>
                        
                        <p style='color: #A0AEC0; font-size: 12px; margin: 30px 0 0;'>
                            Ce lien de vérification expire dans 24 heures.<br>
                            Si vous n'avez pas créé de compte KiloShare, ignorez simplement cet email.
                        </p>
                    </div>
                </td>
            </tr>
        " . self::footerContent();

        return self::send_mail($subject, $to, $body);
    }

    public static function sendPasswordReset(string $email, string $firstName, string $resetToken): bool
    {
        $subject = 'Réinitialisation de votre mot de passe - KiloShare';
        $to = [['email' => $email, 'name' => $firstName]];
        
        $resetUrl = Config::get('app.url') . "/reset-password?token=" . $resetToken;
        
        $body = self::headerContent('Réinitialisation mot de passe') . "
            <!-- Contenu principal -->
            <tr>
                <td class='content' style='padding: 40px 30px; text-align: center;'>
                    <div style='max-width: 500px; margin: 0 auto;'>
                        <!-- Icône -->
                        <div style='margin-bottom: 30px;'>
                            <div style='background-color: #F56565; width: 80px; height: 80px; border-radius: 50%; margin: 0 auto; display: flex; align-items: center; justify-content: center;'>
                                <span style='color: white; font-size: 32px; font-weight: bold;'>🔒</span>
                            </div>
                        </div>
                        
                        <h1 style='color: #1A202C; font-size: 28px; font-weight: 600; margin: 0 0 20px; line-height: 1.3;'>
                            Réinitialisation de mot de passe
                        </h1>
                        
                        <p style='color: #4A5568; font-size: 16px; line-height: 1.6; margin: 0 0 30px;'>
                            Bonjour " . htmlspecialchars($firstName) . ",<br><br>
                            Vous avez demandé à réinitialiser votre mot de passe KiloShare. Cliquez sur le bouton ci-dessous pour créer un nouveau mot de passe sécurisé.
                        </p>
                        
                        <!-- Bouton de réinitialisation -->
                        <div style='margin: 40px 0;'>
                            <a href='" . $resetUrl . "' style='display: inline-block; background-color: #F56565; color: white; text-decoration: none; padding: 15px 32px; border-radius: 6px; font-weight: 600; font-size: 16px;'>
                                Réinitialiser mon mot de passe
                            </a>
                        </div>
                        
                        <p style='color: #718096; font-size: 14px; line-height: 1.5; margin: 30px 0 0;'>
                            Si vous ne pouvez pas cliquer sur le bouton, copiez et collez ce lien dans votre navigateur :<br>
                            <a href='" . $resetUrl . "' style='color: #4096FF; word-break: break-all;'>" . $resetUrl . "</a>
                        </p>
                        
                        <p style='color: #A0AEC0; font-size: 12px; margin: 30px 0 0;'>
                            Ce lien de réinitialisation expire dans 1 heure.<br>
                            Si vous n'avez pas demandé cette réinitialisation, ignorez simplement cet email.
                        </p>
                    </div>
                </td>
            </tr>
        " . self::footerContent();

        return self::send_mail($subject, $to, $body);
    }

    public static function headerContent(string $title): string
    {
        return "
            <!DOCTYPE html>
            <html lang='fr'>
            <head>
                <meta charset='UTF-8'>
                <meta name='viewport' content='width=device-width, initial-scale=1.0'>
                <title>" . $title . "</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap');
                </style>
            </head>
            <body style='margin: 0; padding: 0; font-family: Inter, Arial, sans-serif; background-color: #F7FAFC; color: #1A202C;'>
                <table role='presentation' width='100%' cellspacing='0' cellpadding='0' border='0'>
                    <tr>
                        <td align='center' style='padding: 30px 10px;'>
                            <!-- Conteneur principal -->
                            <table class='email-container' role='presentation' width='600' cellspacing='0' cellpadding='0' border='0' style='max-width: 600px; margin: 0 auto; background-color: #FFFFFF; border-radius: 12px; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08); overflow: hidden;'>
                                <!-- En-tête avec logo -->
                                <tr>
                                    <td class='header' style='background: linear-gradient(135deg, #4096FF 0%, #0070F3 100%); padding: 30px 20px; text-align: center;'>
                                        <h2 style='color: white; font-size: 32px; font-weight: 600; margin: 0; letter-spacing: -0.5px;'>
                                            KiloShare
                                        </h2>
                                        <p style='color: rgba(255,255,255,0.9); font-size: 14px; margin: 8px 0 0; font-weight: 400;'>
                                            Partagez. Transportez. Économisez.
                                        </p>
                                    </td>
                                </tr>
        ";
    }

    public static function footerContent(): string
    {
        return "
                                <!-- Pied de page -->
                                <tr>
                                    <td class='footer' style='background-color: #1A202C; color: #FFFFFF; text-align: center; padding: 30px 20px;'>
                                        <h3 style='color: #FFFFFF; font-size: 24px; font-weight: 600; margin: 0 0 15px; letter-spacing: -0.5px;'>
                                            KiloShare
                                        </h3>
                                        
                                        <p style='margin: 0 0 20px; font-size: 14px; color: #CBD5E0; line-height: 1.5;'>
                                            La plateforme de partage d'espace bagages qui connecte voyageurs et expéditeurs pour des transports plus économiques et écologiques.
                                        </p>
                                        
                                        <div style='margin: 25px 0;'>
                                            <p style='margin: 0 0 15px; font-size: 13px; color: #A0AEC0;'>
                                                <a href='" . Config::get('app.url', 'https://kiloshare.com') . "' style='color: #4096FF; text-decoration: none; margin: 0 10px;'>Accueil</a> | 
                                                <a href='" . Config::get('app.url', 'https://kiloshare.com') . "/how-it-works' style='color: #4096FF; text-decoration: none; margin: 0 10px;'>Comment ça marche</a> | 
                                                <a href='" . Config::get('app.url', 'https://kiloshare.com') . "/contact' style='color: #4096FF; text-decoration: none; margin: 0 10px;'>Contact</a>
                                            </p>
                                            <p style='margin: 0; font-size: 13px; color: #A0AEC0;'>
                                                <a href='" . Config::get('app.url', 'https://kiloshare.com') . "/privacy' style='color: #4096FF; text-decoration: none; margin: 0 10px;'>Confidentialité</a> | 
                                                <a href='" . Config::get('app.url', 'https://kiloshare.com') . "/terms' style='color: #4096FF; text-decoration: none; margin: 0 10px;'>Conditions d'utilisation</a>
                                            </p>
                                        </div>
                                        
                                        <p style='margin: 25px 0 0; font-size: 11px; color: #718096; line-height: 1.4;'>
                                            © 2024 KiloShare. Tous droits réservés.<br>
                                            Si vous ne souhaitez plus recevoir nos emails, <a href='#' style='color: #4096FF; text-decoration: none;'>cliquez ici pour vous désabonner</a>.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>
                </table>
            </body>
            </html>
        ";
    }
    
    /**
     * Redirige les emails vers l'adresse de développement si on est en local
     */
    private static function redirectEmailsInDevelopment(array $to): array
    {
        $appEnv = $_ENV['APP_ENV'] ?? 'production';
        
        // Si on est en environnement de développement
        if (in_array($appEnv, ['development', 'dev', 'local', 'testing'])) {
            $devEmail = $_ENV['DEV_EMAIL'] ?? 'm2atech@gmail.com';
            
            // Remplacer tous les destinataires par l'email de dev
            $redirectedTo = [];
            foreach ($to as $recipient) {
                $originalName = $recipient['name'] ?? 'Destinataire';
                $redirectedTo[] = [
                    'email' => $devEmail,
                    'name' => "[DEV] {$originalName}"
                ];
            }
            
            return $redirectedTo;
        }
        
        // En production, retourner les destinataires originaux
        return $to;
    }
    
    /**
     * Log l'envoi d'email avec information de redirection si applicable
     */
    private static function logEmailSent(array $originalTo, array $finalTo, string $subject): void
    {
        $appEnv = $_ENV['APP_ENV'] ?? 'production';
        
        if (in_array($appEnv, ['development', 'dev', 'local', 'testing'])) {
            // En développement : afficher la redirection
            error_log("📧 [DEV] Email redirigé vers développement:");
            error_log("   Subject: {$subject}");
            error_log("   Destinataires originaux:");
            foreach ($originalTo as $recipient) {
                error_log("   - {$recipient['email']} ({$recipient['name']})");
            }
            error_log("   Envoyé réellement à: {$finalTo[0]['email']}");
            error_log("   ⚠️ En production, cet email sera envoyé aux vrais destinataires");
        } else {
            // En production : log normal
            error_log("📧 Email envoyé avec succès:");
            error_log("   Subject: {$subject}");
            foreach ($finalTo as $recipient) {
                error_log("   To: {$recipient['email']} ({$recipient['name']})");
            }
        }
    }
    
    private static function simulateEmailSending(array $originalTo, array $redirectedTo, string $subject, string $body): void
    {
        error_log('=== SIMULATION ENVOI EMAIL ===');
        error_log('📧 De: ' . self::SENDER_EMAIL . ' (' . self::SENDER_NAME . ')');
        error_log('📧 À (original): ' . json_encode($originalTo));
        error_log('📧 À (dev): ' . json_encode($redirectedTo));
        error_log('📧 Sujet: ' . $subject);
        error_log('📧 Corps (extrait): ' . substr(strip_tags($body), 0, 100) . '...');
        
        // Extraire le token de vérification s'il existe
        if (preg_match('/token=([a-f0-9]+)/', $body, $matches)) {
            $token = $matches[1];
            error_log("🔑 Token de vérification trouvé: {$token}");
            error_log("🔗 URL de vérification manuelle: http://localhost:8080/api/auth/verify-email");
            error_log("📨 Données POST: {\"token\": \"{$token}\"}");
        }
        
        // Sauvegarder les détails de l'email dans un fichier pour consultation
        $emailLog = [
            'timestamp' => date('Y-m-d H:i:s'),
            'from' => self::SENDER_EMAIL,
            'to_original' => $originalTo,
            'to_dev' => $redirectedTo,
            'subject' => $subject,
            'body_preview' => substr(strip_tags($body), 0, 200),
            'full_body' => $body
        ];
        
        $logFile = __DIR__ . '/../../logs/dev_emails.json';
        if (!file_exists(dirname($logFile))) {
            mkdir(dirname($logFile), 0755, true);
        }
        
        $existingLogs = [];
        if (file_exists($logFile)) {
            $existingLogs = json_decode(file_get_contents($logFile), true) ?: [];
        }
        
        $existingLogs[] = $emailLog;
        file_put_contents($logFile, json_encode($existingLogs, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        
        error_log('✅ Email simulé avec succès - Détails sauvés dans: ' . $logFile);
        error_log('=== FIN SIMULATION ===');
    }
}