<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Twilio\Rest\Client;
use Twilio\Exceptions\TwilioException;

class TwilioSmsService
{
    private Client $twilio;
    private string $fromNumber;

    public function __construct(
        string $accountSid,
        string $authToken,
        string $fromNumber
    ) {
        $this->twilio = new Client($accountSid, $authToken);
        $this->fromNumber = $fromNumber;
    }

    /**
     * Envoie un SMS de vérification avec un code
     */
    public function sendVerificationCode(string $phoneNumber, string $code): bool
    {
        try {
            $message = "Votre code de vérification KiloShare est : {$code}. Ce code expire dans 10 minutes.";
            
            // Mode test/développement : simuler l'envoi de SMS
            if ($_ENV['APP_ENV'] === 'development') {
                error_log("MODE TEST SMS - Code: {$code} pour le numéro: {$phoneNumber}");
                error_log("MESSAGE: {$message}");
                
                // En mode développement, écrire le code dans un fichier temporaire pour debug
                $debugFile = __DIR__ . '/../../debug_sms.log';
                file_put_contents($debugFile, "SMS Code for {$phoneNumber}: {$code}\n", FILE_APPEND | LOCK_EX);
                
                return true;
            }
            
            $this->twilio->messages->create(
                $this->formatPhoneNumber($phoneNumber),
                [
                    'from' => $this->fromNumber,
                    'body' => $message
                ]
            );

            error_log("SMS envoyé avec succès au numéro : {$phoneNumber}");
            return true;
        } catch (TwilioException $e) {
            error_log("Erreur Twilio SMS : " . $e->getMessage());
            return false;
        } catch (\Exception $e) {
            error_log("Erreur générale SMS : " . $e->getMessage());
            return false;
        }
    }

    /**
     * Envoie un SMS de bienvenue
     */
    public function sendWelcomeSms(string $phoneNumber, string $firstName): bool
    {
        try {
            $message = "Bienvenue sur KiloShare, {$firstName} ! 🎉 Merci de rejoindre notre communauté de partage.";
            
            // Mode test/développement : simuler l'envoi de SMS
            if ($_ENV['APP_ENV'] === 'development') {
                error_log("MODE TEST SMS BIENVENUE - Pour: {$firstName} ({$phoneNumber})");
                error_log("MESSAGE: {$message}");
                return true;
            }
            
            $this->twilio->messages->create(
                $this->formatPhoneNumber($phoneNumber),
                [
                    'from' => $this->fromNumber,
                    'body' => $message
                ]
            );

            error_log("SMS de bienvenue envoyé au numéro : {$phoneNumber}");
            return true;
        } catch (TwilioException $e) {
            error_log("Erreur Twilio SMS bienvenue : " . $e->getMessage());
            return false;
        } catch (\Exception $e) {
            error_log("Erreur générale SMS bienvenue : " . $e->getMessage());
            return false;
        }
    }

    /**
     * Formate le numéro de téléphone au format international
     */
    private function formatPhoneNumber(string $phoneNumber): string
    {
        // Supprimer tous les espaces et caractères non numériques sauf le +
        $cleanNumber = preg_replace('/[^\+\d]/', '', $phoneNumber);
        
        // Si le numéro ne commence pas par +, déterminer le pays
        if (!str_starts_with($cleanNumber, '+')) {
            if (str_starts_with($cleanNumber, '0')) {
                // Numéro français qui commence par 0
                $cleanNumber = '+33' . substr($cleanNumber, 1);
            } elseif (str_starts_with($cleanNumber, '1')) {
                // Numéro nord-américain qui commence par 1
                $cleanNumber = '+1' . substr($cleanNumber, 1);
            } elseif (strlen($cleanNumber) === 10 && preg_match('/^[2-9]\d{2}\d{7}$/', $cleanNumber)) {
                // Numéro nord-américain sans le 1 (10 chiffres, commence par 2-9)
                $cleanNumber = '+1' . $cleanNumber;
            } elseif (strlen($cleanNumber) === 9 && preg_match('/^[1-9]\d{8}$/', $cleanNumber)) {
                // Numéro français sans le 0 (9 chiffres)
                $cleanNumber = '+33' . $cleanNumber;
            } else {
                // Format international par défaut
                $cleanNumber = '+' . $cleanNumber;
            }
        }

        return $cleanNumber;
    }

    /**
     * Génère un code de vérification à 6 chiffres
     */
    public static function generateVerificationCode(): string
    {
        return str_pad((string) rand(0, 999999), 6, '0', STR_PAD_LEFT);
    }

    /**
     * Valide le format d'un numéro de téléphone
     */
    public static function validatePhoneNumber(string $phoneNumber): bool
    {
        $cleanNumber = preg_replace('/[^\+\d]/', '', $phoneNumber);
        
        // Patterns pour différents pays
        $patterns = [
            // France : +33 X XX XX XX XX ou 0X XX XX XX XX
            '/^(\+33[1-9]\d{8}|0[1-9]\d{8})$/',
            // États-Unis/Canada : +1 XXX XXX XXXX, 1 XXX XXX XXXX ou XXX XXX XXXX (10 chiffres)
            '/^(\+1[2-9]\d{2}\d{7}|1[2-9]\d{2}\d{7}|[2-9]\d{2}\d{7})$/',
            // Format international général (10-15 chiffres avec +)
            '/^\+\d{10,15}$/'
        ];
        
        foreach ($patterns as $pattern) {
            if (preg_match($pattern, $cleanNumber)) {
                return true;
            }
        }
        
        return false;
    }
}