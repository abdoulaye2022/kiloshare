<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Services\CloudinaryService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Log\LoggerInterface;
use Exception;
use InvalidArgumentException;

/**
 * Contrôleur pour la gestion optimisée des images avec Cloudinary
 * 
 * Fournit des endpoints sécurisés pour l'upload, la récupération et la suppression
 * d'images avec compression intelligente et gestion automatique des quotas.
 * 
 * @package KiloShare\Controllers
 * @author KiloShare Team
 * @since 1.0.0
 */
class ImageController
{
    private CloudinaryService $cloudinaryService;
    private LoggerInterface $logger;

    public function __construct(
        CloudinaryService $cloudinaryService,
        LoggerInterface $logger
    ) {
        $this->cloudinaryService = $cloudinaryService;
        $this->logger = $logger;
    }

    /**
     * Upload d'avatar utilisateur avec transformations optimisées
     * 
     * @param Request $request
     * @param Response $response
     * @return Response
     */
    public function uploadAvatar(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Utilisateur non authentifié'
                ], 401);
            }

            $uploadedFiles = $request->getUploadedFiles();
            
            if (!isset($uploadedFiles['avatar'])) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Aucun fichier avatar fourni'
                ], 400);
            }

            $uploadedFile = $uploadedFiles['avatar'];
            
            if ($uploadedFile->getError() !== UPLOAD_ERR_OK) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Erreur lors du téléchargement du fichier'
                ], 400);
            }

            $this->logger->info('[ImageController] Upload avatar demandé', [
                'user_id' => $userId,
                'file_size' => $uploadedFile->getSize(),
                'mime_type' => $uploadedFile->getClientMediaType()
            ]);

            // Upload via CloudinaryService avec optimisations spécifiques aux avatars
            $result = $this->cloudinaryService->uploadImage(
                $uploadedFile,
                'avatar',
                $userId,
                [
                    'category' => 'profile',
                    'additional_tags' => ['user_' . $userId, 'profile_picture']
                ]
            );

            // Supprimer l'ancien avatar s'il existe
            $this->cleanupOldAvatar($userId, $result['cloudinary_data']['public_id']);

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Avatar téléchargé avec succès',
                'data' => [
                    'avatar_url' => $result['cloudinary_data']['secure_url'],
                    'transformations' => $result['transformations'],
                    'upload_time' => round($result['upload_time'], 2),
                    'file_size' => $result['cloudinary_data']['bytes'],
                    'format' => $result['cloudinary_data']['format']
                ]
            ]);

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur upload avatar', [
                'user_id' => $userId ?? null,
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Échec du téléchargement: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Upload de documents KYC sécurisés
     * 
     * @param Request $request
     * @param Response $response
     * @return Response
     */
    public function uploadKYCDocument(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Utilisateur non authentifié'
                ], 401);
            }

            $uploadedFiles = $request->getUploadedFiles();
            $parsedBody = $request->getParsedBody() ?? [];
            
            if (!isset($uploadedFiles['document'])) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Aucun document fourni'
                ], 400);
            }

            // Validation du type de document KYC
            $documentType = $parsedBody['document_type'] ?? '';
            $allowedTypes = ['passport', 'id_card', 'driver_license', 'proof_of_address'];
            
            if (!in_array($documentType, $allowedTypes)) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Type de document invalide'
                ], 400);
            }

            $uploadedFile = $uploadedFiles['document'];
            
            if ($uploadedFile->getError() !== UPLOAD_ERR_OK) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Erreur lors du téléchargement du document'
                ], 400);
            }

            $this->logger->info('[ImageController] Upload document KYC', [
                'user_id' => $userId,
                'document_type' => $documentType,
                'file_size' => $uploadedFile->getSize()
            ]);

            $result = $this->cloudinaryService->uploadImage(
                $uploadedFile,
                'kyc_document',
                $userId,
                [
                    'category' => $documentType,
                    'additional_tags' => ['kyc', $documentType, 'user_' . $userId],
                    'is_temporary' => false
                ]
            );

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Document KYC téléchargé avec succès',
                'data' => [
                    'document_id' => $result['local_data']['id'],
                    'document_url' => $result['cloudinary_data']['secure_url'],
                    'document_type' => $documentType,
                    'transformations' => $result['transformations'],
                    'upload_time' => round($result['upload_time'], 2)
                ]
            ]);

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur upload KYC', [
                'user_id' => $userId ?? null,
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Échec du téléchargement: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Upload multiple de photos d'annonce de voyage
     * 
     * @param Request $request
     * @param Response $response
     * @return Response
     */
    public function uploadTripPhotos(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Utilisateur non authentifié'
                ], 401);
            }

            $uploadedFiles = $request->getUploadedFiles();
            $parsedBody = $request->getParsedBody() ?? [];
            
            if (!isset($uploadedFiles['photos']) || !is_array($uploadedFiles['photos'])) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Aucune photo fournie'
                ], 400);
            }

            $tripId = $parsedBody['trip_id'] ?? null;
            if (!$tripId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'ID de voyage requis'
                ], 400);
            }

            $photos = $uploadedFiles['photos'];
            
            // Limiter à 5 photos par voyage
            if (count($photos) > 5) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Maximum 5 photos par voyage'
                ], 400);
            }

            $this->logger->info('[ImageController] Upload photos voyage', [
                'user_id' => $userId,
                'trip_id' => $tripId,
                'photo_count' => count($photos)
            ]);

            $result = $this->cloudinaryService->uploadMultipleImages(
                $photos,
                'trip_photo',
                $userId,
                [
                    'related_entity_type' => 'trip',
                    'related_entity_id' => (int)$tripId,
                    'additional_tags' => ['trip_' . $tripId, 'travel', 'user_' . $userId]
                ]
            );

            $successfulUploads = array_filter($result['results'], function($r) {
                return $r['success'] === true;
            });

            $uploadedPhotos = array_map(function($upload) {
                return [
                    'photo_id' => $upload['local_data']['id'],
                    'photo_url' => $upload['cloudinary_data']['secure_url'],
                    'transformations' => $upload['transformations'],
                    'file_size' => $upload['cloudinary_data']['bytes']
                ];
            }, $successfulUploads);

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Photos téléchargées avec succès',
                'data' => [
                    'photos' => $uploadedPhotos,
                    'summary' => $result['summary']
                ]
            ]);

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur upload photos voyage', [
                'user_id' => $userId ?? null,
                'trip_id' => $tripId ?? null,
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Échec du téléchargement: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Upload de photos de colis avec expiration automatique
     * 
     * @param Request $request
     * @param Response $response
     * @return Response
     */
    public function uploadPackagePhotos(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Utilisateur non authentifié'
                ], 401);
            }

            $uploadedFiles = $request->getUploadedFiles();
            $parsedBody = $request->getParsedBody() ?? [];
            
            if (!isset($uploadedFiles['photos']) || !is_array($uploadedFiles['photos'])) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Aucune photo de colis fournie'
                ], 400);
            }

            $packageId = $parsedBody['package_id'] ?? null;
            $photos = $uploadedFiles['photos'];
            
            // Limiter à 3 photos par colis
            if (count($photos) > 3) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Maximum 3 photos par colis'
                ], 400);
            }

            $this->logger->info('[ImageController] Upload photos colis', [
                'user_id' => $userId,
                'package_id' => $packageId,
                'photo_count' => count($photos)
            ]);

            $result = $this->cloudinaryService->uploadMultipleImages(
                $photos,
                'package_photo',
                $userId,
                [
                    'related_entity_type' => 'package',
                    'related_entity_id' => $packageId ? (int)$packageId : null,
                    'additional_tags' => [
                        $packageId ? 'package_' . $packageId : 'temp_package',
                        'shipping',
                        'user_' . $userId
                    ],
                    'is_temporary' => !$packageId // Temporaire si pas encore associé à un colis
                ]
            );

            $successfulUploads = array_filter($result['results'], function($r) {
                return $r['success'] === true;
            });

            $uploadedPhotos = array_map(function($upload) {
                return [
                    'photo_id' => $upload['local_data']['id'],
                    'photo_url' => $upload['cloudinary_data']['secure_url'],
                    'transformations' => $upload['transformations'],
                    'expires_at' => date('Y-m-d H:i:s', strtotime('+30 days')) // Auto-suppression
                ];
            }, $successfulUploads);

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Photos de colis téléchargées avec succès',
                'data' => [
                    'photos' => $uploadedPhotos,
                    'summary' => $result['summary'],
                    'note' => 'Photos supprimées automatiquement après 30 jours si non réclamées'
                ]
            ]);

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur upload photos colis', [
                'user_id' => $userId ?? null,
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Échec du téléchargement: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Upload de preuve de livraison
     * 
     * @param Request $request
     * @param Response $response
     * @return Response
     */
    public function uploadDeliveryProof(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Utilisateur non authentifié'
                ], 401);
            }

            $uploadedFiles = $request->getUploadedFiles();
            $parsedBody = $request->getParsedBody() ?? [];
            
            if (!isset($uploadedFiles['proof'])) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Aucune preuve de livraison fournie'
                ], 400);
            }

            $deliveryId = $parsedBody['delivery_id'] ?? null;
            if (!$deliveryId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'ID de livraison requis'
                ], 400);
            }

            $uploadedFile = $uploadedFiles['proof'];
            
            if ($uploadedFile->getError() !== UPLOAD_ERR_OK) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Erreur lors du téléchargement de la preuve'
                ], 400);
            }

            $this->logger->info('[ImageController] Upload preuve livraison', [
                'user_id' => $userId,
                'delivery_id' => $deliveryId,
                'file_size' => $uploadedFile->getSize()
            ]);

            $result = $this->cloudinaryService->uploadImage(
                $uploadedFile,
                'delivery_proof',
                $userId,
                [
                    'related_entity_type' => 'delivery',
                    'related_entity_id' => (int)$deliveryId,
                    'additional_tags' => ['delivery_' . $deliveryId, 'proof', 'legal', 'user_' . $userId]
                ]
            );

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Preuve de livraison téléchargée avec succès',
                'data' => [
                    'proof_id' => $result['local_data']['id'],
                    'proof_url' => $result['cloudinary_data']['secure_url'],
                    'transformations' => $result['transformations'],
                    'upload_time' => round($result['upload_time'], 2),
                    'delivery_id' => $deliveryId
                ]
            ]);

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur upload preuve livraison', [
                'user_id' => $userId ?? null,
                'delivery_id' => $deliveryId ?? null,
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Échec du téléchargement: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Supprimer une image
     * 
     * @param Request $request
     * @param Response $response
     * @param array $args
     * @return Response
     */
    public function deleteImage(Request $request, Response $response, array $args): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;

            if (!$userId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Utilisateur non authentifié'
                ], 401);
            }

            $publicId = $args['public_id'] ?? '';
            if (!$publicId) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'ID image requis'
                ], 400);
            }

            // Décoder le public_id si nécessaire
            $publicId = urldecode($publicId);

            // Vérifier que l'utilisateur possède cette image
            if (!$this->userOwnsImage($userId, $publicId)) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Non autorisé à supprimer cette image'
                ], 403);
            }

            $this->logger->info('[ImageController] Suppression image demandée', [
                'user_id' => $userId,
                'public_id' => $publicId
            ]);

            $success = $this->cloudinaryService->deleteImage($publicId, true);

            if ($success) {
                return $this->jsonResponse($response, [
                    'success' => true,
                    'message' => 'Image supprimée avec succès'
                ]);
            } else {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Échec de la suppression'
                ], 500);
            }

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur suppression image', [
                'user_id' => $userId ?? null,
                'public_id' => $publicId ?? '',
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la suppression: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Obtenir les statistiques d'usage Cloudinary
     * 
     * @param Request $request
     * @param Response $response
     * @return Response
     */
    public function getUsageStats(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userRole = is_array($user) && isset($user['role']) ? $user['role'] : '';

            // Seuls les admins peuvent voir les stats globales
            if ($userRole !== 'admin') {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Accès non autorisé'
                ], 403);
            }

            $stats = $this->cloudinaryService->getUsageStats();

            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Statistiques récupérées avec succès',
                'data' => $stats
            ]);

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur récupération stats', [
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la récupération: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Déclencher un nettoyage manuel
     * 
     * @param Request $request
     * @param Response $response
     * @return Response
     */
    public function triggerCleanup(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            $userRole = is_array($user) && isset($user['role']) ? $user['role'] : '';

            // Seuls les admins peuvent déclencher un nettoyage
            if ($userRole !== 'admin') {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Accès non autorisé'
                ], 403);
            }

            $parsedBody = $request->getParsedBody() ?? [];
            $ruleType = $parsedBody['rule_type'] ?? '';
            
            if (!$ruleType) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Type de règle de nettoyage requis'
                ], 400);
            }

            $this->logger->info('[ImageController] Nettoyage manuel déclenché', [
                'rule_type' => $ruleType,
                'triggered_by' => $user['id'] ?? 'unknown'
            ]);

            $result = $this->cloudinaryService->cleanupImages($ruleType, [
                'limit' => $parsedBody['limit'] ?? null
            ]);

            return $this->jsonResponse($response, [
                'success' => $result['success'],
                'message' => $result['success'] ? 'Nettoyage terminé avec succès' : 'Échec du nettoyage',
                'data' => $result
            ]);

        } catch (Exception $e) {
            $this->logger->error('[ImageController] Erreur nettoyage manuel', [
                'error' => $e->getMessage()
            ]);

            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors du nettoyage: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Vérifier si un utilisateur possède une image
     * 
     * @param int $userId
     * @param string $publicId
     * @return bool
     */
    private function userOwnsImage(int $userId, string $publicId): bool
    {
        // Cette méthode devrait être implémentée dans le CloudinaryService
        // Pour l'instant, on fait une vérification simple
        return strpos($publicId, "user_{$userId}/") !== false;
    }

    /**
     * Nettoyer l'ancien avatar d'un utilisateur
     * 
     * @param int $userId
     * @param string $newPublicId
     */
    private function cleanupOldAvatar(int $userId, string $newPublicId): void
    {
        try {
            // Logique pour supprimer l'ancien avatar
            // Cette méthode pourrait être déplacée dans CloudinaryService
            $this->logger->info('[ImageController] Nettoyage ancien avatar', [
                'user_id' => $userId,
                'new_public_id' => $newPublicId
            ]);
        } catch (Exception $e) {
            $this->logger->warning('[ImageController] Échec nettoyage ancien avatar', [
                'user_id' => $userId,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Helper pour formater les réponses JSON
     * 
     * @param Response $response
     * @param array $data
     * @param int $status
     * @return Response
     */
    private function jsonResponse(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($status);
    }
}