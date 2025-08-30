<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use KiloShare\Services\PhoneVerificationService;
use KiloShare\Services\JwtService;
use KiloShare\Services\TwilioSmsService;
use PDO;
use Exception;

class PhoneAuthController
{
    private PDO $db;
    private JwtService $jwtService;
    private PhoneVerificationService $phoneVerificationService;
    private TwilioSmsService $twilioService;

    public function __construct(
        PDO $db,
        JwtService $jwtService,
        PhoneVerificationService $phoneVerificationService,
        TwilioSmsService $twilioService
    ) {
        $this->db = $db;
        $this->jwtService = $jwtService;
        $this->phoneVerificationService = $phoneVerificationService;
        $this->twilioService = $twilioService;
    }

    /**
     * Envoie un code de vérification SMS
     */
    public function sendVerificationCode(Request $request, Response $response): Response
    {
        try {
            $data = json_decode($request->getBody()->getContents(), true);
            
            if (!isset($data['phone_number']) || empty($data['phone_number'])) {
                return $this->errorResponse($response, 'Numéro de téléphone requis', 400);
            }

            $phoneNumber = trim($data['phone_number']);
            $result = $this->phoneVerificationService->sendVerificationCode($phoneNumber);

            if (!$result['success']) {
                return $this->errorResponse($response, $result['message'], 400);
            }

            return $this->successResponse($response, [
                'message' => $result['message'],
                'phone' => $result['phone']
            ]);
        } catch (Exception $e) {
            error_log("Erreur sendVerificationCode : " . $e->getMessage());
            return $this->errorResponse($response, 'Erreur interne du serveur', 500);
        }
    }

    /**
     * Vérifie le code et connecte/crée l'utilisateur
     */
    public function verifyCodeAndLogin(Request $request, Response $response): Response
    {
        try {
            $data = json_decode($request->getBody()->getContents(), true);
            
            if (!isset($data['phone_number']) || !isset($data['code'])) {
                return $this->errorResponse($response, 'Numéro de téléphone et code requis', 400);
            }

            $phoneNumber = trim($data['phone_number']);
            $code = trim($data['code']);

            // Vérifier le code
            $verificationResult = $this->phoneVerificationService->verifyCode($phoneNumber, $code);
            
            if (!$verificationResult['success']) {
                return $this->errorResponse($response, $verificationResult['message'], 400);
            }

            $formattedPhone = $verificationResult['phone'];

            // Rechercher ou créer l'utilisateur
            $user = $this->findOrCreateUserByPhone($formattedPhone, $data);

            if (!$user) {
                return $this->errorResponse($response, 'Erreur lors de la création de l\'utilisateur', 500);
            }

            // Générer les tokens JWT
            $accessToken = $this->jwtService->generateAccessToken($user);
            $refreshToken = $this->jwtService->generateRefreshToken($user);

            // Sauvegarder le refresh token
            $this->saveRefreshToken((int)$user['id'], $refreshToken);

            $expiryDate = new \DateTime();
            $expiryDate->add(new \DateInterval('PT3600S')); // 1 heure

            return $this->successResponse($response, [
                'user' => [
                    'id' => (int)$user['id'],
                    'phone_number' => $user['phone_number'],
                    'first_name' => $user['first_name'],
                    'last_name' => $user['last_name'],
                    'email' => $user['email'],
                    'phone_verified_at' => $user['phone_verified_at'],
                    'created_at' => $user['created_at']
                ],
                'tokens' => [
                    'access_token' => $accessToken,
                    'refresh_token' => $refreshToken,
                    'expires_in' => 3600,
                    'expires_at' => $expiryDate->format('Y-m-d H:i:s')
                ]
            ]);
        } catch (Exception $e) {
            error_log("Erreur verifyCodeAndLogin : " . $e->getMessage());
            return $this->errorResponse($response, 'Erreur interne du serveur', 500);
        }
    }

    /**
     * Recherche ou crée un utilisateur par téléphone
     */
    private function findOrCreateUserByPhone(string $phoneNumber, array $data): ?array
    {
        try {
            // Rechercher un utilisateur existant
            $stmt = $this->db->prepare("SELECT * FROM users WHERE phone_number = ?");
            $stmt->execute([$phoneNumber]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);

            if ($user) {
                // Mettre à jour la vérification du téléphone
                $this->updatePhoneVerification((int)$user['id']);
                return $user;
            }

            // Créer un nouvel utilisateur
            $firstName = $data['first_name'] ?? 'Utilisateur';
            $lastName = $data['last_name'] ?? '';
            $email = $data['email'] ?? null;

            // Générer un email temporaire si pas fourni
            if (!$email) {
                $phoneDigits = preg_replace('/[^\d]/', '', $phoneNumber);
                $email = "user_{$phoneDigits}@kiloshare-temp.com";
            }

            // Générer un UUID pour l'utilisateur
            $uuid = $this->generateUUID();
            
            $stmt = $this->db->prepare("
                INSERT INTO users (uuid, phone_number, first_name, last_name, email, phone_verified_at, created_at)
                VALUES (?, ?, ?, ?, ?, NOW(), NOW())
            ");
            
            $stmt->execute([$uuid, $phoneNumber, $firstName, $lastName, $email]);
            $userId = $this->db->lastInsertId();

            // Envoyer SMS de bienvenue
            $this->twilioService->sendWelcomeSms($phoneNumber, $firstName);

            // Récupérer l'utilisateur créé
            $stmt = $this->db->prepare("SELECT * FROM users WHERE id = ?");
            $stmt->execute([$userId]);
            
            return $stmt->fetch(PDO::FETCH_ASSOC);
        } catch (Exception $e) {
            error_log("Erreur findOrCreateUserByPhone : " . $e->getMessage());
            return null;
        }
    }

    /**
     * Met à jour la vérification du téléphone
     */
    private function updatePhoneVerification(int $userId): void
    {
        $stmt = $this->db->prepare("
            UPDATE users SET phone_verified_at = NOW() WHERE id = ? AND phone_verified_at IS NULL
        ");
        $stmt->execute([$userId]);
    }

    /**
     * Sauvegarde le refresh token
     */
    private function saveRefreshToken(int $userId, string $refreshToken): void
    {
        try {
            // Supprimer les anciens refresh tokens de cet utilisateur
            $stmt = $this->db->prepare("DELETE FROM refresh_tokens WHERE user_id = ?");
            $stmt->execute([$userId]);

            // Ajouter le nouveau refresh token
            $expiryDate = new \DateTime();
            $expiryDate->add(new \DateInterval('P30D')); // 30 jours

            $stmt = $this->db->prepare("
                INSERT INTO refresh_tokens (user_id, token, expires_at, created_at)
                VALUES (?, ?, ?, NOW())
            ");
            $stmt->execute([$userId, $refreshToken, $expiryDate->format('Y-m-d H:i:s')]);
        } catch (Exception $e) {
            error_log("Erreur saveRefreshToken : " . $e->getMessage());
        }
    }

    /**
     * Réponse de succès
     */
    private function successResponse(Response $response, array $data): Response
    {
        $response->getBody()->write(json_encode([
            'success' => true,
            'data' => $data
        ]));

        return $response->withHeader('Content-Type', 'application/json');
    }

    /**
     * Réponse d'erreur
     */
    private function errorResponse(Response $response, string $message, int $statusCode = 400): Response
    {
        $response->getBody()->write(json_encode([
            'success' => false,
            'message' => $message
        ]));

        return $response
            ->withStatus($statusCode)
            ->withHeader('Content-Type', 'application/json');
    }

    /**
     * Génère un UUID v4
     */
    private function generateUUID(): string
    {
        return sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }
}