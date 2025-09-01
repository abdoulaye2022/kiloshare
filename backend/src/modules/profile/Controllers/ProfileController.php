<?php

namespace App\Modules\Profile\Controllers;

use App\Modules\Profile\Services\ProfileService;
use App\Services\FtpUploadService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Log\LoggerInterface;
use Exception;

class ProfileController
{
    private ProfileService $profileService;
    private FtpUploadService $ftpUploadService;
    private LoggerInterface $logger;

    public function __construct(
        ProfileService $profileService,
        FtpUploadService $ftpUploadService,
        LoggerInterface $logger
    ) {
        $this->profileService = $profileService;
        $this->ftpUploadService = $ftpUploadService;
        $this->logger = $logger;
    }

    public function getProfile(Request $request, Response $response, array $args): Response
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
            
            $profile = $this->profileService->getUserProfile($userId);

            if (!$profile) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Profil non trouvé'
                ]));
                return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            }

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $profile
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Erreur lors de la récupération du profil: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function createProfile(Request $request, Response $response): Response
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

            $profile = $this->profileService->createUserProfile($userId, $data);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Profil créé avec succès',
                'data' => $profile
            ]));
            return $response->withStatus(201)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Erreur lors de la création du profil: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage()
            ]));
            return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
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

            $profile = $this->profileService->updateUserProfile($userId, $data);

            $response->getBody()->write(json_encode([
                'success' => true,
                'message' => 'Profil mis à jour avec succès',
                'data' => $profile
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Erreur lors de la mise à jour du profil: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => $e->getMessage()
            ]));
            return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
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

            $result = $this->ftpUploadService->uploadFile($uploadedFile, 'avatars', $userId);
            
            if ($result['success']) {
                $this->profileService->updateAvatarUrl($userId, $result['file_url']);
                
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

        } catch (Exception $e) {
            $this->logger->error('Erreur lors du téléchargement de l\'avatar: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function uploadDocument(Request $request, Response $response): Response
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
            $parsedBody = $request->getParsedBody();
            
            if (!isset($uploadedFiles['document'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Aucun fichier document fourni'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $documentType = $parsedBody['document_type'] ?? null;
            $documentNumber = $parsedBody['document_number'] ?? null;
            $expiryDate = $parsedBody['expiry_date'] ?? null;

            if (!$documentType) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Type de document requis'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $uploadedFile = $uploadedFiles['document'];
            
            if ($uploadedFile->getError() !== UPLOAD_ERR_OK) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Erreur lors du téléchargement du fichier'
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

            $result = $this->ftpUploadService->uploadFile($uploadedFile, 'documents', $userId);
            
            if ($result['success']) {
                $document = $this->profileService->uploadVerificationDocument(
                    $userId,
                    $documentType,
                    $documentNumber,
                    $result['file_path'],
                    $result['file_name'],
                    $uploadedFile->getSize(),
                    $uploadedFile->getClientMediaType(),
                    $expiryDate
                );
                
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'message' => 'Document téléchargé avec succès',
                    'data' => $document
                ]));
                return $response->withStatus(201)->withHeader('Content-Type', 'application/json');
            } else {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => $result['message']
                ]));
                return $response->withStatus(400)->withHeader('Content-Type', 'application/json');
            }

        } catch (Exception $e) {
            $this->logger->error('Erreur lors du téléchargement du document: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function getUserDocuments(Request $request, Response $response): Response
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
            $documents = $this->profileService->getUserDocuments($userId);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $documents
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Erreur lors de la récupération des documents: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function getUserBadges(Request $request, Response $response): Response
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
            $badges = $this->profileService->getUserBadges($userId);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $badges
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Erreur lors de la récupération des badges: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function getVerificationStatus(Request $request, Response $response): Response
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
            $status = $this->profileService->getVerificationStatus($userId);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $status
            ]));
            return $response->withStatus(200)->withHeader('Content-Type', 'application/json');

        } catch (Exception $e) {
            $this->logger->error('Erreur lors de la récupération du statut de vérification: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }

    public function deleteDocument(Request $request, Response $response, array $args): Response
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
            $documentId = (int) $args['documentId'];
            
            $result = $this->profileService->deleteUserDocument($userId, $documentId);

            if ($result) {
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'message' => 'Document supprimé avec succès'
                ]));
                return $response->withStatus(200)->withHeader('Content-Type', 'application/json');
            } else {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Document non trouvé ou non autorisé'
                ]));
                return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            }

        } catch (Exception $e) {
            $this->logger->error('Erreur lors de la suppression du document: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur serveur'
            ]));
            return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
        }
    }
}