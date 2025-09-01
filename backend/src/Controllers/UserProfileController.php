<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\User;
use App\Services\FtpUploadService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Log\LoggerInterface;

class UserProfileController
{
    private User $userModel;
    private FtpUploadService $ftpUploadService;
    private LoggerInterface $logger;

    public function __construct(
        User $userModel,
        FtpUploadService $ftpUploadService,
        LoggerInterface $logger
    ) {
        $this->userModel = $userModel;
        $this->ftpUploadService = $ftpUploadService;
        $this->logger = $logger;
    }

    public function getProfile(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'User ID not found'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $profile = $this->userModel->findById($userId);

            if (!$profile) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Profil non trouvé'
                ]));
                return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            }

            // Normaliser les données pour l'API
            $profile = User::normalizeForApi($profile);
            
            // Supprimer les données sensibles
            unset($profile['password_hash']);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $profile
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $this->logger->error('Erreur lors de la récupération du profil: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function updateProfile(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'User ID not found'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $data = $request->getParsedBody() ?? [];
            
            if (empty($data)) {
                $rawBody = $request->getBody()->getContents();
                $data = json_decode($rawBody, true) ?? [];
            }

            // Valider les données selon la méthode de connexion de l'utilisateur
            $validation = $this->userModel->validateProfileUpdate($userId, $data);
            if (!$validation['valid']) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => $validation['message']
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            // Mettre à jour le profil
            $updated = $this->userModel->updateProfile($userId, $data);

            if (!$updated) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Aucune modification effectuée'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            // Récupérer le profil mis à jour
            $profile = $this->userModel->findById($userId);
            if ($profile) {
                $profile = User::normalizeForApi($profile);
                unset($profile['password_hash']);
            }

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Profil mis à jour avec succès',
                'data' => $profile
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $this->logger->error('Erreur lors de la mise à jour du profil: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur: ' . $e->getMessage()
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function uploadAvatar(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'User ID not found'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $uploadedFiles = $request->getUploadedFiles();
            
            if (!isset($uploadedFiles['avatar'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Aucun fichier avatar fourni'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $uploadedFile = $uploadedFiles['avatar'];
            
            if ($uploadedFile->getError() !== UPLOAD_ERR_OK) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Erreur lors du téléchargement du fichier'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            // Upload de l'avatar dans le dossier organisé par utilisateur
            $result = $this->ftpUploadService->uploadFile($uploadedFile, 'avatars', $userId);
            
            if ($result['success']) {
                // Mettre à jour l'URL de l'avatar dans la base de données
                $this->userModel->updateProfile($userId, ['profile_picture' => $result['file_url']]);
                
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'message' => 'Avatar téléchargé avec succès',
                    'data' => [
                        'avatar_url' => $result['file_url']
                    ]
                ]));
                return $response->withStatus(200)->withHeader('Content-Type', 'application/json');
            } else {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => $result['message']
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

        } catch (\Exception $e) {
            $this->logger->error('Erreur lors du téléchargement de l\'avatar: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function deleteAvatar(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;
            
            if (!$userId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'User ID not found'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            // Récupérer l'utilisateur pour obtenir l'URL de l'avatar actuel
            $userProfile = $this->userModel->findById($userId);
            if ($userProfile && !empty($userProfile['profile_picture'])) {
                // Extraire le chemin du fichier depuis l'URL
                $avatarUrl = $userProfile['profile_picture'];
                $filePath = str_replace(rtrim($_ENV['APP_URL'] ?? 'http://localhost:8080', '/') . '/uploads/', '', $avatarUrl);
                
                // Supprimer le fichier
                $this->ftpUploadService->deleteFile($filePath);
            }

            // Mettre à jour la base de données
            $this->userModel->updateProfile($userId, ['profile_picture' => null]);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Avatar supprimé avec succès'
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (\Exception $e) {
            $this->logger->error('Erreur lors de la suppression de l\'avatar: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
}