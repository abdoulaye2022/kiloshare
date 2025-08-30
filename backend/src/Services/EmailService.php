<?php

declare(strict_types=1);

namespace KiloShare\Services;

class EmailService
{
    private array $config;

    public function __construct(array $config)
    {
        $this->config = $config;
    }

    /**
     * Send welcome email to new user
     */
    public function sendWelcomeEmail(array $user): bool
    {
        try {
            $subject = "Bienvenue sur KiloShare ! 🎉";
            $htmlContent = $this->generateWelcomeEmailTemplate($user);
            $textContent = $this->generateWelcomeEmailText($user);

            return $this->sendEmail(
                $user['email'],
                $user['first_name'] . ' ' . $user['last_name'],
                $subject,
                $htmlContent,
                $textContent
            );
        } catch (\Exception $e) {
            error_log('Failed to send welcome email: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Send verification email
     */
    public function sendVerificationEmail(array $user, string $verificationToken): bool
    {
        try {
            $subject = "Vérifiez votre adresse email - KiloShare";
            $verificationUrl = $this->config['app']['url'] . '/verify-email?token=' . $verificationToken;
            
            $htmlContent = $this->generateVerificationEmailTemplate($user, $verificationUrl);
            $textContent = $this->generateVerificationEmailText($user, $verificationUrl);

            return $this->sendEmail(
                $user['email'],
                $user['first_name'] . ' ' . $user['last_name'],
                $subject,
                $htmlContent,
                $textContent
            );
        } catch (\Exception $e) {
            error_log('Failed to send verification email: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Send password reset email
     */
    public function sendPasswordResetEmail(array $user, string $resetToken): bool
    {
        try {
            $subject = "Réinitialisation de votre mot de passe - KiloShare";
            $resetUrl = $this->config['app']['url'] . '/reset-password?token=' . $resetToken;
            
            $htmlContent = $this->generatePasswordResetEmailTemplate($user, $resetUrl);
            $textContent = $this->generatePasswordResetEmailText($user, $resetUrl);

            return $this->sendEmail(
                $user['email'],
                $user['first_name'] . ' ' . $user['last_name'],
                $subject,
                $htmlContent,
                $textContent
            );
        } catch (\Exception $e) {
            error_log('Failed to send password reset email: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Send email using Brevo API
     */
    private function sendEmail(string $email, string $name, string $subject, string $htmlContent, string $textContent): bool
    {
        $brevoApiKey = $this->config['email']['brevo_api_key'];
        
        if (empty($brevoApiKey)) {
            error_log('Brevo API key not configured');
            return false;
        }

        $data = [
            'sender' => [
                'name' => $this->config['email']['from_name'],
                'email' => $this->config['email']['from_address']
            ],
            'to' => [
                [
                    'email' => $email,
                    'name' => trim($name) ?: 'Utilisateur'
                ]
            ],
            'subject' => $subject,
            'htmlContent' => $htmlContent,
            'textContent' => $textContent
        ];

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, 'https://api.brevo.com/v3/smtp/email');
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Accept: application/json',
            'Content-Type: application/json',
            'api-key: ' . $brevoApiKey
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode === 201) {
            return true;
        } else {
            error_log('Failed to send email via Brevo. HTTP Code: ' . $httpCode . ', Response: ' . $response);
            return false;
        }
    }

    /**
     * Generate welcome email HTML template
     */
    private function generateWelcomeEmailTemplate(array $user): string
    {
        $firstName = htmlspecialchars($user['first_name'] ?: 'Nouvel utilisateur');
        
        return '
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Bienvenue sur KiloShare</title>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f4f4f4; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; background-color: white; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
                .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                .content { padding: 30px 20px; }
                .footer { background-color: #f8f9fa; padding: 20px; text-align: center; border-radius: 0 0 8px 8px; font-size: 12px; color: #666; }
                .button { display: inline-block; background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                .features { background-color: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
                .feature-item { margin: 10px 0; }
                .emoji { font-size: 18px; margin-right: 8px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🎉 Bienvenue sur KiloShare !</h1>
                </div>
                
                <div class="content">
                    <p>Bonjour ' . $firstName . ',</p>
                    
                    <p>Félicitations ! Votre compte KiloShare a été créé avec succès. Nous sommes ravis de vous accueillir dans notre communauté !</p>
                    
                    <div class="features">
                        <h3>Découvrez ce que vous pouvez faire avec KiloShare :</h3>
                        <div class="feature-item">
                            <span class="emoji">📦</span>
                            <strong>Partager vos colis</strong> - Optimisez vos envois en partageant l\'espace avec d\'autres utilisateurs
                        </div>
                        <div class="feature-item">
                            <span class="emoji">🚚</span>
                            <strong>Économiser sur les frais</strong> - Réduisez vos coûts de livraison en mutualisant les envois
                        </div>
                        <div class="feature-item">
                            <span class="emoji">🌍</span>
                            <strong>Expédier partout</strong> - Accédez à un réseau mondial de partenaires de confiance
                        </div>
                        <div class="feature-item">
                            <span class="emoji">🔒</span>
                            <strong>Sécurité garantie</strong> - Vos envois sont protégés et assurés
                        </div>
                    </div>
                    
                    <p>Pour commencer à utiliser KiloShare, connectez-vous simplement avec votre compte et explorez toutes nos fonctionnalités.</p>
                    
                    <p>Si vous avez des questions, notre équipe support est là pour vous aider à <strong>support@kiloshare.com</strong></p>
                    
                    <p>Encore une fois, bienvenue dans la famille KiloShare ! 🚀</p>
                    
                    <p>Cordialement,<br>
                    L\'équipe KiloShare</p>
                </div>
                
                <div class="footer">
                    <p>© 2025 KiloShare - Votre solution de partage de colis</p>
                    <p>Si vous n\'avez pas créé ce compte, veuillez nous contacter immédiatement.</p>
                </div>
            </div>
        </body>
        </html>';
    }

    /**
     * Generate welcome email text version
     */
    private function generateWelcomeEmailText(array $user): string
    {
        $firstName = $user['first_name'] ?: 'Nouvel utilisateur';
        
        return "
Bienvenue sur KiloShare !

Bonjour $firstName,

Félicitations ! Votre compte KiloShare a été créé avec succès. Nous sommes ravis de vous accueillir dans notre communauté !

Découvrez ce que vous pouvez faire avec KiloShare :

• Partager vos colis - Optimisez vos envois en partageant l'espace avec d'autres utilisateurs
• Économiser sur les frais - Réduisez vos coûts de livraison en mutualisant les envois  
• Expédier partout - Accédez à un réseau mondial de partenaires de confiance
• Sécurité garantie - Vos envois sont protégés et assurés

Pour commencer à utiliser KiloShare, connectez-vous simplement avec votre compte et explorez toutes nos fonctionnalités.

Si vous avez des questions, notre équipe support est là pour vous aider à support@kiloshare.com

Encore une fois, bienvenue dans la famille KiloShare !

Cordialement,
L'équipe KiloShare

---
© 2025 KiloShare - Votre solution de partage de colis
Si vous n'avez pas créé ce compte, veuillez nous contacter immédiatement.
        ";
    }

    /**
     * Generate verification email HTML template
     */
    private function generateVerificationEmailTemplate(array $user, string $verificationUrl): string
    {
        $firstName = htmlspecialchars($user['first_name'] ?: 'Utilisateur');
        
        return '
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Vérifiez votre email - KiloShare</title>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f4f4f4; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; background-color: white; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
                .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                .content { padding: 30px 20px; text-align: center; }
                .footer { background-color: #f8f9fa; padding: 20px; text-align: center; border-radius: 0 0 8px 8px; font-size: 12px; color: #666; }
                .button { display: inline-block; background-color: #4CAF50; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; font-weight: bold; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>✉️ Vérifiez votre adresse email</h1>
                </div>
                
                <div class="content">
                    <p>Bonjour ' . $firstName . ',</p>
                    <p>Merci de vous être inscrit sur KiloShare ! Pour activer votre compte, veuillez cliquer sur le bouton ci-dessous :</p>
                    <a href="' . htmlspecialchars($verificationUrl) . '" class="button">Vérifier mon email</a>
                    <p>Ce lien expirera dans 24 heures pour des raisons de sécurité.</p>
                </div>
                
                <div class="footer">
                    <p>© 2025 KiloShare</p>
                </div>
            </div>
        </body>
        </html>';
    }

    /**
     * Generate verification email text version
     */
    private function generateVerificationEmailText(array $user, string $verificationUrl): string
    {
        $firstName = $user['first_name'] ?: 'Utilisateur';
        
        return "
Vérifiez votre adresse email - KiloShare

Bonjour $firstName,

Merci de vous être inscrit sur KiloShare ! Pour activer votre compte, veuillez cliquer sur le lien suivant :

$verificationUrl

Ce lien expirera dans 24 heures pour des raisons de sécurité.

© 2025 KiloShare
        ";
    }

    /**
     * Generate password reset email HTML template
     */
    private function generatePasswordResetEmailTemplate(array $user, string $resetUrl): string
    {
        $firstName = htmlspecialchars($user['first_name'] ?: 'Utilisateur');
        
        return '
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>Réinitialisation du mot de passe - KiloShare</title>
            <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f4f4f4; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; background-color: white; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
                .header { background-color: #FF5722; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                .content { padding: 30px 20px; text-align: center; }
                .footer { background-color: #f8f9fa; padding: 20px; text-align: center; border-radius: 0 0 8px 8px; font-size: 12px; color: #666; }
                .button { display: inline-block; background-color: #FF5722; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; font-weight: bold; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🔒 Réinitialisation du mot de passe</h1>
                </div>
                
                <div class="content">
                    <p>Bonjour ' . $firstName . ',</p>
                    <p>Vous avez demandé à réinitialiser votre mot de passe. Cliquez sur le bouton ci-dessous pour créer un nouveau mot de passe :</p>
                    <a href="' . htmlspecialchars($resetUrl) . '" class="button">Réinitialiser le mot de passe</a>
                    <p>Ce lien expirera dans 1 heure pour des raisons de sécurité.</p>
                    <p>Si vous n\'avez pas demandé cette réinitialisation, ignorez cet email.</p>
                </div>
                
                <div class="footer">
                    <p>© 2025 KiloShare</p>
                </div>
            </div>
        </body>
        </html>';
    }

    /**
     * Generate password reset email text version
     */
    private function generatePasswordResetEmailText(array $user, string $resetUrl): string
    {
        $firstName = $user['first_name'] ?: 'Utilisateur';
        
        return "
Réinitialisation du mot de passe - KiloShare

Bonjour $firstName,

Vous avez demandé à réinitialiser votre mot de passe. Cliquez sur le lien suivant pour créer un nouveau mot de passe :

$resetUrl

Ce lien expirera dans 1 heure pour des raisons de sécurité.

Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.

© 2025 KiloShare
        ";
    }
}