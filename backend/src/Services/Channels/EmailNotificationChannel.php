<?php

declare(strict_types=1);

namespace KiloShare\Services\Channels;

use KiloShare\Models\User;
use Exception;

class EmailNotificationChannel implements NotificationChannelInterface
{
    private string $smtpHost;
    private int $smtpPort;
    private string $smtpUsername;
    private string $smtpPassword;
    private string $fromEmail;
    private string $fromName;

    public function __construct()
    {
        $this->smtpHost = $_ENV['SMTP_HOST'] ?? 'smtp.gmail.com';
        $this->smtpPort = (int)($_ENV['SMTP_PORT'] ?? 587);
        $this->smtpUsername = $_ENV['SMTP_USERNAME'] ?? '';
        $this->smtpPassword = $_ENV['SMTP_PASSWORD'] ?? '';
        $this->fromEmail = $_ENV['MAIL_FROM_EMAIL'] ?? 'noreply@kiloshare.com';
        $this->fromName = $_ENV['MAIL_FROM_NAME'] ?? 'KiloShare';
    }

    public function send(User $user, array $rendered, array $data = []): array
    {
        try {
            $to = $this->getRecipient($user);
            if (!$to) {
                return ['success' => false, 'error' => 'No email address available'];
            }

            $subject = $rendered['title'] ?? 'Notification KiloShare';
            $body = $this->buildEmailBody($rendered, $data);

            $headers = [
                'From: ' . $this->fromName . ' <' . $this->fromEmail . '>',
                'Reply-To: ' . $this->fromEmail,
                'X-Mailer: KiloShare Notification System',
                'MIME-Version: 1.0',
                'Content-Type: text/html; charset=UTF-8'
            ];

            if ($this->smtpUsername && $this->smtpPassword) {
                return $this->sendViaSMTP($to, $subject, $body, $headers);
            } else {
                return $this->sendViaMail($to, $subject, $body, $headers);
            }

        } catch (Exception $e) {
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    private function buildEmailBody(array $rendered, array $data): string
    {
        $message = $rendered['message'] ?? '';
        $actionUrl = $data['action_url'] ?? null;
        $actionText = $data['action_text'] ?? 'Voir détails';

        $html = '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>' . htmlspecialchars($rendered['title'] ?? '') . '</title>
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: #f8f9fa; padding: 20px; border-radius: 10px;">
        <h2 style="color: #2c5aa0; margin-bottom: 20px;">KiloShare</h2>
        <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #2c5aa0;">
            <p style="color: #333; line-height: 1.6; margin: 0;">' . nl2br(htmlspecialchars($message)) . '</p>';

        if ($actionUrl) {
            $html .= '<p style="margin-top: 20px;">
                <a href="' . htmlspecialchars($actionUrl) . '" 
                   style="background: #2c5aa0; color: white; padding: 12px 24px; 
                          text-decoration: none; border-radius: 5px; display: inline-block;">' 
                   . htmlspecialchars($actionText) . '</a>
            </p>';
        }

        $html .= '</div>
        <p style="color: #666; font-size: 12px; margin-top: 20px; text-align: center;">
            Ceci est un message automatique de KiloShare. Merci de ne pas répondre à cet email.
        </p>
    </div>
</body>
</html>';

        return $html;
    }

    private function sendViaSMTP(string $to, string $subject, string $body, array $headers): array
    {
        // Simple SMTP implementation - in production, use PHPMailer or similar
        $socket = fsockopen($this->smtpHost, $this->smtpPort, $errno, $errstr, 30);
        if (!$socket) {
            return ['success' => false, 'error' => "SMTP connection failed: $errstr ($errno)"];
        }

        try {
            // Basic SMTP conversation
            $this->smtpCommand($socket, null, '220');
            $this->smtpCommand($socket, "EHLO " . gethostname(), '250');
            $this->smtpCommand($socket, "STARTTLS", '220');
            
            stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT);
            
            $this->smtpCommand($socket, "EHLO " . gethostname(), '250');
            $this->smtpCommand($socket, "AUTH LOGIN", '334');
            $this->smtpCommand($socket, base64_encode($this->smtpUsername), '334');
            $this->smtpCommand($socket, base64_encode($this->smtpPassword), '235');
            
            $this->smtpCommand($socket, "MAIL FROM: <" . $this->fromEmail . ">", '250');
            $this->smtpCommand($socket, "RCPT TO: <$to>", '250');
            $this->smtpCommand($socket, "DATA", '354');
            
            $email = implode("\r\n", $headers) . "\r\n";
            $email .= "To: $to\r\n";
            $email .= "Subject: $subject\r\n\r\n";
            $email .= $body . "\r\n.\r\n";
            
            fwrite($socket, $email);
            $this->smtpCommand($socket, null, '250');
            $this->smtpCommand($socket, "QUIT", '221');
            
            fclose($socket);
            return ['success' => true, 'provider' => 'smtp'];
            
        } catch (Exception $e) {
            fclose($socket);
            return ['success' => false, 'error' => $e->getMessage()];
        }
    }

    private function sendViaMail(string $to, string $subject, string $body, array $headers): array
    {
        $success = mail($to, $subject, $body, implode("\r\n", $headers));
        return [
            'success' => $success,
            'provider' => 'mail',
            'error' => $success ? null : 'Mail function failed'
        ];
    }

    private function smtpCommand($socket, ?string $command, string $expectedCode): void
    {
        if ($command !== null) {
            fwrite($socket, $command . "\r\n");
        }
        
        $response = fgets($socket, 512);
        if (substr($response, 0, 3) !== $expectedCode) {
            throw new Exception("SMTP Error: Expected $expectedCode, got: $response");
        }
    }

    public function getRecipient(User $user): ?string
    {
        return $user->email;
    }

    public function isAvailable(User $user): bool
    {
        return !empty($user->email) && filter_var($user->email, FILTER_VALIDATE_EMAIL);
    }

    public function getName(): string
    {
        return 'email';
    }

    public function getDisplayName(): string
    {
        return 'Email';
    }

    public function getCost(): int
    {
        return 1;
    }
}