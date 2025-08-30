<?php

declare(strict_types=1);

namespace KiloShare\Services;

use PDO;
use DateTime;
use DateInterval;

class PhoneVerificationService
{
    private PDO $db;
    private TwilioSmsService $smsService;

    public function __construct(PDO $db, TwilioSmsService $smsService)
    {
        $this->db = $db;
        $this->smsService = $smsService;
    }

    /**
     * Envoie un code de vérification par SMS
     */
    public function sendVerificationCode(string $phoneNumber): array
    {
        try {
            // Valider le numéro de téléphone
            if (!TwilioSmsService::validatePhoneNumber($phoneNumber)) {
                return [
                    'success' => false,
                    'message' => 'Numéro de téléphone invalide'
                ];
            }

            // Formater le numéro
            $formattedPhone = $this->formatPhoneNumber($phoneNumber);
            
            // Vérifier s'il y a déjà un code non expiré
            if ($this->hasValidCode($formattedPhone)) {
                return [
                    'success' => false,
                    'message' => 'Un code a déjà été envoyé. Veuillez attendre avant d\'en demander un nouveau.'
                ];
            }

            // Générer et sauvegarder le code
            $code = TwilioSmsService::generateVerificationCode();
            $this->saveVerificationCode($formattedPhone, $code);

            // Envoyer le SMS
            $smsSent = $this->smsService->sendVerificationCode($formattedPhone, $code);

            if (!$smsSent) {
                return [
                    'success' => false,
                    'message' => 'Erreur lors de l\'envoi du SMS'
                ];
            }

            return [
                'success' => true,
                'message' => 'Code de vérification envoyé par SMS',
                'phone' => $formattedPhone
            ];
        } catch (\Exception $e) {
            error_log("Erreur envoi code vérification : " . $e->getMessage());
            return [
                'success' => false,
                'message' => 'Erreur lors de l\'envoi du code'
            ];
        }
    }

    /**
     * Vérifie un code de vérification
     */
    public function verifyCode(string $phoneNumber, string $code): array
    {
        try {
            $formattedPhone = $this->formatPhoneNumber($phoneNumber);
            
            $stmt = $this->db->prepare("
                SELECT * FROM phone_verifications 
                WHERE phone_number = ? AND code = ? AND used = 0 AND expires_at > NOW()
                ORDER BY created_at DESC LIMIT 1
            ");
            $stmt->execute([$formattedPhone, $code]);
            $verification = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$verification) {
                return [
                    'success' => false,
                    'message' => 'Code invalide ou expiré'
                ];
            }

            // Marquer le code comme utilisé
            $this->markCodeAsUsed($verification['id']);

            return [
                'success' => true,
                'message' => 'Code vérifié avec succès',
                'phone' => $formattedPhone
            ];
        } catch (\Exception $e) {
            error_log("Erreur vérification code : " . $e->getMessage());
            return [
                'success' => false,
                'message' => 'Erreur lors de la vérification'
            ];
        }
    }

    /**
     * Sauvegarde un code de vérification
     */
    private function saveVerificationCode(string $phoneNumber, string $code): void
    {
        $expiresAt = (new DateTime())->add(new DateInterval('PT10M')); // 10 minutes
        
        $stmt = $this->db->prepare("
            INSERT INTO phone_verifications (phone_number, code, expires_at, created_at)
            VALUES (?, ?, ?, NOW())
        ");
        $stmt->execute([$phoneNumber, $code, $expiresAt->format('Y-m-d H:i:s')]);
    }

    /**
     * Vérifie s'il y a déjà un code valide
     */
    private function hasValidCode(string $phoneNumber): bool
    {
        $stmt = $this->db->prepare("
            SELECT COUNT(*) FROM phone_verifications 
            WHERE phone_number = ? AND used = 0 AND expires_at > NOW()
            AND created_at > DATE_SUB(NOW(), INTERVAL 1 MINUTE)
        ");
        $stmt->execute([$phoneNumber]);
        
        return $stmt->fetchColumn() > 0;
    }

    /**
     * Marque un code comme utilisé
     */
    private function markCodeAsUsed(int $verificationId): void
    {
        $stmt = $this->db->prepare("
            UPDATE phone_verifications SET used = 1, used_at = NOW()
            WHERE id = ?
        ");
        $stmt->execute([$verificationId]);
    }

    /**
     * Formate le numéro de téléphone
     */
    private function formatPhoneNumber(string $phoneNumber): string
    {
        $cleanNumber = preg_replace('/[^\+\d]/', '', $phoneNumber);
        
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
     * Nettoie les codes expirés (à appeler périodiquement)
     */
    public function cleanupExpiredCodes(): void
    {
        $stmt = $this->db->prepare("
            DELETE FROM phone_verifications 
            WHERE expires_at < DATE_SUB(NOW(), INTERVAL 1 DAY)
        ");
        $stmt->execute();
    }
}