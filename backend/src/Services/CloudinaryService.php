<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Cloudinary\Cloudinary;
use Cloudinary\Api\Upload\UploadApi;
use Cloudinary\Api\Admin\AdminApi;
use Cloudinary\Configuration\Configuration;
use Cloudinary\Asset\Image as CloudinaryImage;
use Cloudinary\Transformation\Transformation;
use Cloudinary\Transformation\Resize;
use Cloudinary\Transformation\Quality;
use Cloudinary\Transformation\Format;
use Cloudinary\Transformation\Delivery;
use Psr\Http\Message\UploadedFileInterface;
use Psr\Log\LoggerInterface;
use PDO;
use Exception;
use RuntimeException;
use InvalidArgumentException;

/**
 * Service de gestion optimisée des images avec Cloudinary
 * 
 * Implémente une stratégie de compression intelligente et de transformation
 * à la volée pour maximiser l'utilisation des 25GB gratuits de Cloudinary.
 * 
 * @package KiloShare\Services
 * @author KiloShare Team
 * @since 1.0.0
 */
class CloudinaryService
{
    private Cloudinary $cloudinary;
    private PDO $db;
    private LoggerInterface $logger;
    
    // Configuration des transformations par type d'image
    private const IMAGE_CONFIGS = [
        'avatar' => [
            'compression_quality' => 80,
            'max_dimensions' => ['width' => 400, 'height' => 400],
            'formats' => ['jpg', 'png', 'webp'],
            'transformations' => [
                'main' => ['width' => 400, 'height' => 400, 'crop' => 'fill', 'quality' => 80],
                'thumbnail' => ['width' => 150, 'height' => 150, 'crop' => 'fill', 'quality' => 75],
                'mini' => ['width' => 50, 'height' => 50, 'crop' => 'fill', 'quality' => 70]
            ],
            'folder' => 'avatars',
            'is_public' => true,
            'tags' => ['avatar', 'profile']
        ],
        'kyc_document' => [
            'compression_quality' => 60,
            'max_dimensions' => ['width' => 1200, 'height' => 1600],
            'formats' => ['jpg', 'png', 'pdf'],
            'transformations' => [
                'main' => ['width' => 1200, 'quality' => 60, 'crop' => 'limit'],
                'thumbnail' => ['width' => 300, 'height' => 200, 'crop' => 'fill', 'quality' => 50]
            ],
            'folder' => 'kyc',
            'is_public' => false,
            'tags' => ['kyc', 'document', 'private']
        ],
        'trip_photo' => [
            'compression_quality' => 50,
            'max_dimensions' => ['width' => 800, 'height' => 600],
            'formats' => ['jpg', 'webp'],
            'transformations' => [
                'main' => ['width' => 800, 'height' => 600, 'crop' => 'fill', 'quality' => 50],
                'medium' => ['width' => 400, 'height' => 300, 'crop' => 'fill', 'quality' => 45],
                'thumbnail' => ['width' => 200, 'height' => 150, 'crop' => 'fill', 'quality' => 40]
            ],
            'folder' => 'trips',
            'is_public' => true,
            'tags' => ['trip', 'travel', 'public']
        ],
        'package_photo' => [
            'compression_quality' => 50,
            'max_dimensions' => ['width' => 600, 'height' => 600],
            'formats' => ['jpg', 'webp'],
            'transformations' => [
                'main' => ['width' => 600, 'quality' => 50, 'crop' => 'limit'],
                'thumbnail' => ['width' => 200, 'height' => 200, 'crop' => 'fill', 'quality' => 45]
            ],
            'folder' => 'packages',
            'is_public' => true,
            'tags' => ['package', 'shipping'],
            'cleanup_after_days' => 30
        ],
        'delivery_proof' => [
            'compression_quality' => 80,
            'max_dimensions' => ['width' => 1000, 'height' => 1000],
            'formats' => ['jpg', 'png'],
            'transformations' => [
                'main' => ['width' => 1000, 'quality' => 80, 'crop' => 'limit'],
                'thumbnail' => ['width' => 300, 'height' => 300, 'crop' => 'fill', 'quality' => 70]
            ],
            'folder' => 'delivery',
            'is_public' => false,
            'tags' => ['delivery', 'proof', 'legal']
        ]
    ];

    // Limites de quota Cloudinary (25GB)
    private const STORAGE_LIMIT = 26843545600; // 25GB en bytes
    private const BANDWIDTH_LIMIT = 26843545600; // 25GB en bytes

    public function __construct(PDO $db, LoggerInterface $logger)
    {
        $this->db = $db;
        $this->logger = $logger;
        
        // Configurer Cloudinary avec la méthode statique recommandée
        Configuration::instance([
            'cloud' => [
                'cloud_name' => $_ENV['CLOUDINARY_CLOUD_NAME'] ?? '',
                'api_key' => $_ENV['CLOUDINARY_API_KEY'] ?? '',
                'api_secret' => $_ENV['CLOUDINARY_API_SECRET'] ?? '',
            ],
            'url' => [
                'secure' => true
            ]
        ]);

        $this->logger->info('[CloudinaryService] Service initialisé avec succès');
    }

    /**
     * Upload optimisé d'une image selon son type
     *
     * @param UploadedFileInterface $file Fichier à uploader
     * @param string $imageType Type d'image (avatar, kyc_document, etc.)
     * @param int $userId ID de l'utilisateur
     * @param array $options Options supplémentaires
     * @return array Résultat avec métadonnées Cloudinary et local
     * @throws RuntimeException En cas d'erreur d'upload
     */
    public function uploadImage(
        UploadedFileInterface $file,
        string $imageType,
        int $userId,
        array $options = []
    ): array {
        try {
            // Vérifier le type d'image supporté
            if (!isset(self::IMAGE_CONFIGS[$imageType])) {
                throw new InvalidArgumentException("Type d'image non supporté: {$imageType}");
            }

            // Vérifier les quotas avant upload
            $this->checkQuotaBeforeUpload($file);

            $config = self::IMAGE_CONFIGS[$imageType];
            $startTime = microtime(true);

            // Validation du fichier
            $this->validateFile($file, $config);

            // Générer un public_id unique
            $publicId = $this->generatePublicId($imageType, $userId, $options);

            // Préparer les options d'upload Cloudinary
            $uploadOptions = $this->prepareUploadOptions($config, $publicId, $options);

            $this->logger->info("[CloudinaryService] Upload de {$imageType} pour utilisateur {$userId}", [
                'file_size' => $file->getSize(),
                'public_id' => $publicId
            ]);

            // Upload vers Cloudinary
            $uploadApi = new UploadApi();
            
            // Créer un fichier temporaire pour éviter les problèmes de stream
            $tempFile = tempnam(sys_get_temp_dir(), 'cloudinary_');
            $file->moveTo($tempFile);
            
            $result = $uploadApi->upload($tempFile, $uploadOptions);
            
            // Nettoyer le fichier temporaire
            if (file_exists($tempFile)) {
                unlink($tempFile);
            }
            
            // Convertir ApiResponse en array pour compatibilité
            $result = $result->getArrayCopy();

            $uploadTime = microtime(true) - $startTime;

            // Enregistrer les métadonnées en base de données
            $imageRecord = $this->saveImageMetadata($result, $file, $imageType, $userId, $options, $uploadTime);

            // Générer les URLs des transformations - désactivé temporairement
            $transformations = [];

            // Mettre à jour les statistiques d'usage
            $this->updateUsageStats($imageType, $file->getSize(), $uploadTime);

            $this->logger->info("[CloudinaryService] Upload réussi", [
                'public_id' => $result['public_id'],
                'secure_url' => $result['secure_url'] ?? 'MISSING',
                'upload_time' => round($uploadTime, 2) . 's',
                'file_size' => $file->getSize(),
                'cloudinary_result_keys' => array_keys($result)
            ]);

            return [
                'success' => true,
                'cloudinary_data' => $result,
                'local_data' => $imageRecord,
                'transformations' => $transformations,
                'upload_time' => $uploadTime
            ];

        } catch (Exception $e) {
            $this->logger->error("[CloudinaryService] Erreur upload {$imageType}", [
                'user_id' => $userId,
                'error' => $e->getMessage(),
                'file_size' => $file->getSize()
            ]);
            
            throw new RuntimeException("Échec de l'upload: " . $e->getMessage(), 0, $e);
        }
    }

    /**
     * Upload multiple d'images avec progression
     *
     * @param array $files Tableau de UploadedFileInterface
     * @param string $imageType Type d'images
     * @param int $userId ID utilisateur
     * @param array $options Options d'upload
     * @return array Résultats de tous les uploads
     */
    public function uploadMultipleImages(
        array $files,
        string $imageType,
        int $userId,
        array $options = []
    ): array {
        $results = [];
        $successCount = 0;
        $totalSize = 0;

        foreach ($files as $index => $file) {
            try {
                $result = $this->uploadImage($file, $imageType, $userId, array_merge($options, [
                    'batch_index' => $index,
                    'batch_total' => count($files)
                ]));
                
                $results[] = $result;
                $successCount++;
                $totalSize += $file->getSize();
                
            } catch (Exception $e) {
                $results[] = [
                    'success' => false,
                    'error' => $e->getMessage(),
                    'file_index' => $index
                ];
                
                $this->logger->warning("[CloudinaryService] Échec upload batch", [
                    'file_index' => $index,
                    'error' => $e->getMessage()
                ]);
            }
        }

        $this->logger->info("[CloudinaryService] Upload batch terminé", [
            'total_files' => count($files),
            'success_count' => $successCount,
            'total_size' => $totalSize
        ]);

        return [
            'results' => $results,
            'summary' => [
                'total_files' => count($files),
                'successful_uploads' => $successCount,
                'failed_uploads' => count($files) - $successCount,
                'total_size' => $totalSize
            ]
        ];
    }

    /**
     * Supprimer une image de Cloudinary et de la base
     *
     * @param string $publicId Public ID Cloudinary
     * @param bool $permanent Suppression définitive ou soft delete
     * @return bool Succès de la suppression
     */
    public function deleteImage(string $publicId, bool $permanent = false): bool
    {
        try {
            // Récupérer les métadonnées depuis la base
            $stmt = $this->db->prepare("SELECT * FROM image_uploads WHERE cloudinary_public_id = ? AND deleted_at IS NULL");
            $stmt->execute([$publicId]);
            $image = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$image) {
                $this->logger->warning("[CloudinaryService] Image introuvable pour suppression", ['public_id' => $publicId]);
                return false;
            }

            if ($permanent) {
                // Supprimer de Cloudinary
                $adminApi = new AdminApi();
                $result = $adminApi->deleteAssets([$publicId]);

                // Supprimer de la base de données
                $stmt = $this->db->prepare("DELETE FROM image_uploads WHERE cloudinary_public_id = ?");
                $stmt->execute([$publicId]);
                
                $this->logger->info("[CloudinaryService] Image supprimée définitivement", [
                    'public_id' => $publicId,
                    'type' => $image['image_type'],
                    'size' => $image['file_size']
                ]);
            } else {
                // Soft delete
                $stmt = $this->db->prepare("UPDATE image_uploads SET deleted_at = NOW() WHERE cloudinary_public_id = ?");
                $stmt->execute([$publicId]);
                
                $this->logger->info("[CloudinaryService] Image marquée comme supprimée", [
                    'public_id' => $publicId,
                    'type' => $image['image_type']
                ]);
            }

            return true;

        } catch (Exception $e) {
            $this->logger->error("[CloudinaryService] Erreur suppression image", [
                'public_id' => $publicId,
                'error' => $e->getMessage()
            ]);
            return false;
        }
    }

    /**
     * Nettoyer les images selon les règles de rétention
     *
     * @param string $ruleType Type de règle de nettoyage
     * @param array $options Options de nettoyage
     * @return array Rapport de nettoyage
     */
    public function cleanupImages(string $ruleType, array $options = []): array
    {
        $startTime = new \DateTime();
        $processedCount = 0;
        $deletedCount = 0;
        $failedCount = 0;
        $spaceFreed = 0;
        $deletedImages = [];
        $failedImages = [];

        try {
            // Récupérer la règle de nettoyage
            $stmt = $this->db->prepare("SELECT * FROM cloudinary_cleanup_rules WHERE rule_name = ? AND is_active = 1");
            $stmt->execute([$ruleType]);
            $rule = $stmt->fetch(PDO::FETCH_ASSOC);

            if (!$rule) {
                throw new RuntimeException("Règle de nettoyage introuvable: {$ruleType}");
            }

            $conditions = json_decode($rule['conditions'], true);
            
            // Construire la requête de sélection des images à nettoyer
            $sql = "SELECT * FROM image_uploads WHERE deleted_at IS NULL AND " . $conditions['where'];
            if (isset($options['limit'])) {
                $sql .= " LIMIT " . (int)$options['limit'];
            } else {
                $sql .= " LIMIT " . $rule['max_images_per_run'];
            }

            $stmt = $this->db->prepare($sql);
            $stmt->execute();
            $imagesToCleanup = $stmt->fetchAll(PDO::FETCH_ASSOC);

            $this->logger->info("[CloudinaryService] Début nettoyage {$ruleType}", [
                'images_found' => count($imagesToCleanup),
                'rule' => $rule['rule_description']
            ]);

            foreach ($imagesToCleanup as $image) {
                $processedCount++;
                
                try {
                    if ($this->deleteImage($image['cloudinary_public_id'], true)) {
                        $deletedCount++;
                        $spaceFreed += $image['file_size'];
                        $deletedImages[] = [
                            'public_id' => $image['cloudinary_public_id'],
                            'type' => $image['image_type'],
                            'size' => $image['file_size'],
                            'user_id' => $image['user_id']
                        ];
                    } else {
                        $failedCount++;
                        $failedImages[] = [
                            'public_id' => $image['cloudinary_public_id'],
                            'error' => 'Échec suppression'
                        ];
                    }
                } catch (Exception $e) {
                    $failedCount++;
                    $failedImages[] = [
                        'public_id' => $image['cloudinary_public_id'],
                        'error' => $e->getMessage()
                    ];
                }
            }

            $endTime = new \DateTime();
            $duration = $endTime->getTimestamp() - $startTime->getTimestamp();

            // Enregistrer le rapport de nettoyage
            $this->logCleanupOperation($ruleType, $startTime, $endTime, $processedCount, $deletedCount, $failedCount, $spaceFreed, $deletedImages, $failedImages);

            // Mettre à jour les statistiques de la règle
            $stmt = $this->db->prepare("
                UPDATE cloudinary_cleanup_rules 
                SET last_run_at = NOW(), 
                    total_runs = total_runs + 1,
                    total_images_deleted = total_images_deleted + ?,
                    total_space_freed = total_space_freed + ?,
                    next_run_at = CASE run_frequency
                        WHEN 'daily' THEN DATE_ADD(NOW(), INTERVAL 1 DAY)
                        WHEN 'weekly' THEN DATE_ADD(NOW(), INTERVAL 1 WEEK)  
                        WHEN 'monthly' THEN DATE_ADD(NOW(), INTERVAL 1 MONTH)
                    END
                WHERE rule_name = ?
            ");
            $stmt->execute([$deletedCount, $spaceFreed, $ruleType]);

            $this->logger->info("[CloudinaryService] Nettoyage {$ruleType} terminé", [
                'processed' => $processedCount,
                'deleted' => $deletedCount,
                'failed' => $failedCount,
                'space_freed' => $this->formatBytes($spaceFreed),
                'duration' => $duration . 's'
            ]);

            return [
                'success' => true,
                'rule_type' => $ruleType,
                'processed_count' => $processedCount,
                'deleted_count' => $deletedCount,
                'failed_count' => $failedCount,
                'space_freed' => $spaceFreed,
                'duration_seconds' => $duration,
                'deleted_images' => $deletedImages,
                'failed_images' => $failedImages
            ];

        } catch (Exception $e) {
            $this->logger->error("[CloudinaryService] Erreur nettoyage {$ruleType}", [
                'error' => $e->getMessage()
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
                'processed_count' => $processedCount,
                'deleted_count' => $deletedCount,
                'failed_count' => $failedCount
            ];
        }
    }

    /**
     * Obtenir les statistiques d'usage actuelles
     *
     * @return array Statistiques détaillées
     */
    public function getUsageStats(): array
    {
        try {
            // Usage du stockage
            $stmt = $this->db->prepare("
                SELECT 
                    image_type,
                    COUNT(*) as count,
                    SUM(file_size) as total_size,
                    AVG(file_size) as avg_size,
                    AVG(compression_quality) as avg_compression
                FROM image_uploads 
                WHERE deleted_at IS NULL 
                GROUP BY image_type
            ");
            $stmt->execute();
            $typeStats = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // Usage total
            $stmt = $this->db->prepare("
                SELECT 
                    COUNT(*) as total_images,
                    SUM(file_size) as total_storage,
                    SUM(download_count) as total_downloads,
                    AVG(compression_quality) as avg_compression
                FROM image_uploads 
                WHERE deleted_at IS NULL
            ");
            $stmt->execute();
            $totalStats = $stmt->fetch(PDO::FETCH_ASSOC);

            // Statistiques du mois courant
            $stmt = $this->db->prepare("
                SELECT 
                    COALESCE(SUM(uploads_size), 0) as monthly_uploads,
                    COALESCE(SUM(downloads_size), 0) as monthly_downloads,
                    COALESCE(AVG(avg_upload_time), 0) as avg_upload_time
                FROM cloudinary_usage_stats 
                WHERE YEAR(date) = YEAR(NOW()) AND MONTH(date) = MONTH(NOW())
            ");
            $stmt->execute();
            $monthlyStats = $stmt->fetch(PDO::FETCH_ASSOC);

            // Calcul des pourcentages
            $storagePercentage = ($totalStats['total_storage'] / self::STORAGE_LIMIT) * 100;
            $bandwidthPercentage = ($monthlyStats['monthly_downloads'] / self::BANDWIDTH_LIMIT) * 100;

            return [
                'storage' => [
                    'used' => (int)$totalStats['total_storage'],
                    'limit' => self::STORAGE_LIMIT,
                    'percentage' => round($storagePercentage, 2),
                    'formatted_used' => $this->formatBytes((int)$totalStats['total_storage']),
                    'formatted_limit' => $this->formatBytes(self::STORAGE_LIMIT)
                ],
                'bandwidth' => [
                    'used' => (int)$monthlyStats['monthly_downloads'],
                    'limit' => self::BANDWIDTH_LIMIT,
                    'percentage' => round($bandwidthPercentage, 2),
                    'formatted_used' => $this->formatBytes((int)$monthlyStats['monthly_downloads']),
                    'formatted_limit' => $this->formatBytes(self::BANDWIDTH_LIMIT)
                ],
                'images' => [
                    'total_count' => (int)$totalStats['total_images'],
                    'monthly_uploads' => (int)$monthlyStats['monthly_uploads'],
                    'avg_compression' => round((float)$totalStats['avg_compression'], 1),
                    'avg_upload_time' => round((float)$monthlyStats['avg_upload_time'], 2)
                ],
                'by_type' => $typeStats,
                'alerts' => $this->checkQuotaAlerts($storagePercentage, $bandwidthPercentage)
            ];

        } catch (Exception $e) {
            $this->logger->error("[CloudinaryService] Erreur récupération statistiques", [
                'error' => $e->getMessage()
            ]);
            
            throw new RuntimeException("Impossible de récupérer les statistiques: " . $e->getMessage());
        }
    }

    /**
     * Générer les URLs de transformation pour une image
     *
     * @param string $publicId Public ID de l'image
     * @param array $config Configuration du type d'image
     * @return array URLs des différentes transformations
     */
    private function generateTransformationUrls(string $publicId, array $config): array
    {
        $urls = [];
        
        foreach ($config['transformations'] as $name => $transformation) {
            $t = new Transformation();
            
            // Appliquer les transformations
            if (isset($transformation['width'])) {
                $t->resize(Resize::fill()->width($transformation['width']));
            }
            if (isset($transformation['height'])) {
                $t->resize(Resize::fill()->height($transformation['height']));
            }
            if (isset($transformation['quality'])) {
                $t->delivery(Delivery::quality($transformation['quality']));
            }
            
            // Format auto pour WebP quand supporté
            $t->delivery(Delivery::format('auto'));
            
            $urls[$name] = CloudinaryImage::fromPublicId($publicId)->transformation($t)->toUrl();
        }
        
        return $urls;
    }

    /**
     * Valider un fichier selon la configuration du type d'image
     */
    private function validateFile(UploadedFileInterface $file, array $config): void
    {
        // Vérifier la taille
        if ($file->getSize() > 5242880) { // 5MB max
            throw new InvalidArgumentException("Fichier trop volumineux (max 5MB)");
        }

        // Vérifier le type MIME
        $allowedMimes = [];
        foreach ($config['formats'] as $format) {
            switch ($format) {
                case 'jpg':
                    $allowedMimes[] = 'image/jpeg';
                    break;
                case 'png':
                    $allowedMimes[] = 'image/png';
                    break;
                case 'webp':
                    $allowedMimes[] = 'image/webp';
                    break;
                case 'pdf':
                    $allowedMimes[] = 'application/pdf';
                    break;
            }
        }

        if (!in_array($file->getClientMediaType(), $allowedMimes)) {
            throw new InvalidArgumentException("Type de fichier non supporté");
        }
    }

    /**
     * Générer un public_id unique pour Cloudinary
     */
    private function generatePublicId(string $imageType, int $userId, array $options): string
    {
        $config = self::IMAGE_CONFIGS[$imageType];
        $timestamp = time();
        $random = bin2hex(random_bytes(4));
        
        // Structure correcte avec dossiers organisés
        $publicId = "{$config['folder']}/user_{$userId}/{$imageType}_{$timestamp}_{$random}";
        
        // Pour les entités liées (voyages, colis, etc.)
        if (isset($options['related_entity_type'], $options['related_entity_id'])) {
            $publicId = "{$config['folder']}/{$options['related_entity_type']}_{$options['related_entity_id']}/user_{$userId}/{$imageType}_{$timestamp}_{$random}";
        }
        
        return $publicId;
    }

    /**
     * Préparer les options d'upload pour Cloudinary
     */
    private function prepareUploadOptions(array $config, string $publicId, array $options): array
    {
        $uploadOptions = [
            'public_id' => $publicId,
            'resource_type' => 'image',
            'type' => $config['is_public'] ? 'upload' : 'authenticated',
            'tags' => array_merge($config['tags'], $options['additional_tags'] ?? []),
            'quality' => $config['compression_quality'],
            'unique_filename' => false,
            'overwrite' => false
        ];

        // Options spécifiques selon le type - avec des dimensions maximales raisonnables
        if (isset($config['max_dimensions'])) {
            $uploadOptions['width'] = $config['max_dimensions']['width'];
            $uploadOptions['height'] = $config['max_dimensions']['height'];
            $uploadOptions['crop'] = 'limit';
        }

        return $uploadOptions;
    }

    /**
     * Sauvegarder les métadonnées d'image en base
     */
    private function saveImageMetadata($cloudinaryResult, UploadedFileInterface $file, string $imageType, int $userId, array $options, float $uploadTime): array
    {
        $expiresAt = null;
        if (isset(self::IMAGE_CONFIGS[$imageType]['cleanup_after_days'])) {
            $days = self::IMAGE_CONFIGS[$imageType]['cleanup_after_days'];
            $expiresAt = (new \DateTime())->modify("+{$days} days")->format('Y-m-d H:i:s');
        }

        $stmt = $this->db->prepare("
            INSERT INTO image_uploads (
                user_id, cloudinary_public_id, cloudinary_url, cloudinary_secure_url,
                cloudinary_version, cloudinary_signature, original_filename, file_size,
                width, height, format, image_type, image_category, related_entity_type,
                related_entity_id, compression_quality, transformations, is_temporary,
                is_public, expires_at, tags
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");

        $stmt->execute([
            $userId,
            $cloudinaryResult['public_id'],
            $cloudinaryResult['url'],
            $cloudinaryResult['secure_url'],
            $cloudinaryResult['version'],
            $cloudinaryResult['signature'],
            $file->getClientFilename(),
            $cloudinaryResult['bytes'],
            $cloudinaryResult['width'],
            $cloudinaryResult['height'],
            $cloudinaryResult['format'],
            $imageType,
            $options['category'] ?? null,
            $options['related_entity_type'] ?? null,
            $options['related_entity_id'] ?? null,
            self::IMAGE_CONFIGS[$imageType]['compression_quality'],
            json_encode($cloudinaryResult['eager'] ?? []),
            (int)($options['is_temporary'] ?? 0),
            (int)self::IMAGE_CONFIGS[$imageType]['is_public'],
            $expiresAt,
            json_encode(self::IMAGE_CONFIGS[$imageType]['tags'])
        ]);

        return [
            'id' => $this->db->lastInsertId(),
            'uuid' => $this->generateUuid(),
            'upload_time' => $uploadTime
        ];
    }

    /**
     * Vérifier les quotas avant upload
     */
    private function checkQuotaBeforeUpload(UploadedFileInterface $file): void
    {
        $stats = $this->getUsageStats();
        
        if ($stats['storage']['percentage'] >= 95) {
            throw new RuntimeException("Quota de stockage dépassé (95%+). Upload impossible.");
        }
        
        if ($stats['bandwidth']['percentage'] >= 95) {
            throw new RuntimeException("Quota de bande passante dépassé (95%+). Upload impossible.");
        }

        // Vérifier si l'ajout de ce fichier dépasserait les quotas
        $newStoragePercentage = (($stats['storage']['used'] + $file->getSize()) / self::STORAGE_LIMIT) * 100;
        if ($newStoragePercentage >= 98) {
            throw new RuntimeException("Upload refusé: dépasserait le quota de stockage.");
        }
    }

    /**
     * Vérifier et déclencher des alertes de quota
     */
    private function checkQuotaAlerts(float $storagePercentage, float $bandwidthPercentage): array
    {
        $alerts = [];

        if ($storagePercentage >= 95) {
            $alerts[] = ['type' => 'storage_critical', 'percentage' => $storagePercentage];
        } elseif ($storagePercentage >= 85) {
            $alerts[] = ['type' => 'storage_warning', 'percentage' => $storagePercentage];
        }

        if ($bandwidthPercentage >= 95) {
            $alerts[] = ['type' => 'bandwidth_critical', 'percentage' => $bandwidthPercentage];
        } elseif ($bandwidthPercentage >= 85) {
            $alerts[] = ['type' => 'bandwidth_warning', 'percentage' => $bandwidthPercentage];
        }

        return $alerts;
    }

    /**
     * Mettre à jour les statistiques d'usage
     */
    private function updateUsageStats(string $imageType, int $fileSize, float $uploadTime): void
    {
        // Cette méthode est appelée automatiquement par les triggers MySQL
        // mais nous pouvons ajouter des métriques supplémentaires
        
        $stmt = $this->db->prepare("
            INSERT INTO cloudinary_usage_stats (date, avg_upload_time) 
            VALUES (CURDATE(), ?) 
            ON DUPLICATE KEY UPDATE 
                avg_upload_time = (avg_upload_time + VALUES(avg_upload_time)) / 2
        ");
        $stmt->execute([$uploadTime]);
    }

    /**
     * Enregistrer une opération de nettoyage
     */
    private function logCleanupOperation(string $ruleType, \DateTime $startTime, \DateTime $endTime, int $processed, int $deleted, int $failed, int $spaceFreed, array $deletedImages, array $failedImages): void
    {
        $stmt = $this->db->prepare("
            INSERT INTO cloudinary_cleanup_log (
                cleanup_type, cleanup_rule, images_processed, images_deleted, 
                images_failed, space_freed, start_time, end_time, success,
                deleted_images, failed_images, triggered_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'cron')
        ");

        $stmt->execute([
            'scheduled',
            $ruleType,
            $processed,
            $deleted,
            $failed,
            $spaceFreed,
            $startTime->format('Y-m-d H:i:s'),
            $endTime->format('Y-m-d H:i:s'),
            $failed === 0,
            json_encode($deletedImages),
            json_encode($failedImages)
        ]);
    }

    /**
     * Formater les bytes en format lisible
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $power = $bytes > 0 ? floor(log($bytes, 1024)) : 0;
        return number_format($bytes / pow(1024, $power), 2, '.', '') . ' ' . $units[$power];
    }

    /**
     * Générer un UUID v4
     */
    private function generateUuid(): string
    {
        return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }
}