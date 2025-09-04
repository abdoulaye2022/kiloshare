<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Cloudinary\Cloudinary;
use Cloudinary\Api\Upload\UploadApi;
use Cloudinary\Api\Admin\AdminApi;
use Cloudinary\Transformation\Scale;
use Exception;

class CloudinaryService
{
    private Cloudinary $cloudinary;
    private UploadApi $uploadApi;
    private AdminApi $adminApi;

    public function __construct()
    {
        $settings = require __DIR__ . '/../../config/settings.php';
        $cloudinaryConfig = $settings['cloudinary'];

        $this->cloudinary = new Cloudinary([
            'cloud' => [
                'cloud_name' => $cloudinaryConfig['cloud_name'],
                'api_key' => $cloudinaryConfig['api_key'],
                'api_secret' => $cloudinaryConfig['api_secret'],
            ],
            'url' => [
                'secure' => true,
            ]
        ]);

        $this->uploadApi = $this->cloudinary->uploadApi();
        $this->adminApi = $this->cloudinary->adminApi();
    }

    /**
     * Upload d'avatar utilisateur
     */
    public function uploadAvatar(string $filePath, int $userId): array
    {
        try {
            $publicId = "avatars/user_{$userId}";
            
            $result = $this->uploadApi->upload($filePath, [
                'public_id' => $publicId,
                'folder' => 'kiloshare/avatars',
                'transformation' => [
                    'width' => 400,
                    'height' => 400,
                    'crop' => 'fill',
                    'gravity' => 'face',
                    'quality' => 'auto:good',
                    'format' => 'jpg'
                ],
                'overwrite' => true,
                'invalidate' => true,
            ]);

            return [
                'public_id' => $result['public_id'],
                'url' => $result['secure_url'],
                'thumbnail' => $this->cloudinary->image($result['public_id'])
                    ->resize(Scale::scale(150))
                    ->toUrl(),
                'file_size' => $result['bytes'],
                'format' => $result['format'],
            ];
        } catch (Exception $e) {
            throw new Exception("Avatar upload failed: " . $e->getMessage());
        }
    }

    /**
     * Upload d'images de voyage
     */
    public function uploadTripImage(string $filePath, int $tripId, int $imageIndex = 0): array
    {
        try {
            $publicId = "trips/trip_{$tripId}_img_{$imageIndex}_" . time();
            
            $result = $this->uploadApi->upload($filePath, [
                'public_id' => $publicId,
                'folder' => 'kiloshare/trips',
                'transformation' => [
                    'width' => 1200,
                    'height' => 800,
                    'crop' => 'limit',
                    'quality' => 'auto:good',
                    'format' => 'jpg'
                ],
                'eager' => [
                    [
                        'width' => 400,
                        'height' => 300,
                        'crop' => 'fill',
                        'quality' => 'auto:good'
                    ],
                    [
                        'width' => 150,
                        'height' => 150,
                        'crop' => 'thumb',
                        'gravity' => 'center'
                    ]
                ]
            ]);

            return [
                'public_id' => $result['public_id'],
                'url' => $result['secure_url'],
                'thumbnail' => $result['eager'][1]['secure_url'] ?? $this->generateThumbnailUrl($result['public_id']),
                'medium' => $result['eager'][0]['secure_url'] ?? $this->generateMediumUrl($result['public_id']),
                'file_size' => $result['bytes'],
                'width' => $result['width'],
                'height' => $result['height'],
                'format' => $result['format'],
            ];
        } catch (Exception $e) {
            throw new Exception("Trip image upload failed: " . $e->getMessage());
        }
    }

    /**
     * Upload de documents KYC
     */
    public function uploadKYCDocument(string $filePath, int $userId, string $documentType): array
    {
        try {
            $publicId = "kyc/user_{$userId}_{$documentType}_" . time();
            
            $result = $this->uploadApi->upload($filePath, [
                'public_id' => $publicId,
                'folder' => 'kiloshare/kyc',
                'transformation' => [
                    'width' => 1600,
                    'height' => 1200,
                    'crop' => 'limit',
                    'quality' => 'auto:best',
                    'format' => 'jpg'
                ],
                'tags' => ['kyc', $documentType, "user_{$userId}"]
            ]);

            return [
                'public_id' => $result['public_id'],
                'url' => $result['secure_url'],
                'file_size' => $result['bytes'],
                'width' => $result['width'],
                'height' => $result['height'],
                'format' => $result['format'],
            ];
        } catch (Exception $e) {
            throw new Exception("KYC document upload failed: " . $e->getMessage());
        }
    }

    /**
     * Upload de photos de colis
     */
    public function uploadPackagePhoto(string $filePath, ?int $packageId = null, int $photoIndex = 0): array
    {
        try {
            $publicId = $packageId 
                ? "packages/package_{$packageId}_img_{$photoIndex}_" . time()
                : "packages/temp_img_{$photoIndex}_" . time();
            
            $result = $this->uploadApi->upload($filePath, [
                'public_id' => $publicId,
                'folder' => 'kiloshare/packages',
                'transformation' => [
                    'width' => 800,
                    'height' => 800,
                    'crop' => 'limit',
                    'quality' => 'auto:good',
                    'format' => 'jpg'
                ],
                'eager' => [
                    [
                        'width' => 200,
                        'height' => 200,
                        'crop' => 'fill',
                        'gravity' => 'center'
                    ]
                ]
            ]);

            return [
                'public_id' => $result['public_id'],
                'url' => $result['secure_url'],
                'thumbnail' => $result['eager'][0]['secure_url'] ?? $this->generateThumbnailUrl($result['public_id']),
                'file_size' => $result['bytes'],
                'width' => $result['width'],
                'height' => $result['height'],
                'format' => $result['format'],
            ];
        } catch (Exception $e) {
            throw new Exception("Package photo upload failed: " . $e->getMessage());
        }
    }

    /**
     * Upload de preuve de livraison
     */
    public function uploadDeliveryProof(string $filePath, int $deliveryId): array
    {
        try {
            $publicId = "delivery/proof_{$deliveryId}_" . time();
            
            $result = $this->uploadApi->upload($filePath, [
                'public_id' => $publicId,
                'folder' => 'kiloshare/delivery',
                'transformation' => [
                    'width' => 1200,
                    'height' => 1200,
                    'crop' => 'limit',
                    'quality' => 'auto:good',
                    'format' => 'jpg'
                ],
                'tags' => ['delivery_proof', "delivery_{$deliveryId}"]
            ]);

            return [
                'public_id' => $result['public_id'],
                'url' => $result['secure_url'],
                'thumbnail' => $this->generateThumbnailUrl($result['public_id']),
                'file_size' => $result['bytes'],
                'width' => $result['width'],
                'height' => $result['height'],
                'format' => $result['format'],
            ];
        } catch (Exception $e) {
            throw new Exception("Delivery proof upload failed: " . $e->getMessage());
        }
    }

    /**
     * Supprimer une image
     */
    public function deleteImage(string $publicId): bool
    {
        try {
            $result = $this->uploadApi->destroy($publicId);
            return $result['result'] === 'ok';
        } catch (Exception $e) {
            error_log("Cloudinary delete failed: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Obtenir les statistiques d'usage
     */
    public function getUsageStats(): array
    {
        try {
            $usage = $this->adminApi->usage();
            
            return [
                'storage' => [
                    'used' => $usage['storage']['used_bytes'] ?? 0,
                    'limit' => $usage['storage']['limit'] ?? 0,
                    'percentage' => $usage['storage']['used_percent'] ?? 0,
                    'formatted_used' => $this->formatBytes($usage['storage']['used_bytes'] ?? 0),
                    'formatted_limit' => $this->formatBytes($usage['storage']['limit'] ?? 0),
                ],
                'bandwidth' => [
                    'used' => $usage['bandwidth']['used_bytes'] ?? 0,
                    'limit' => $usage['bandwidth']['limit'] ?? 0,
                    'percentage' => $usage['bandwidth']['used_percent'] ?? 0,
                    'formatted_used' => $this->formatBytes($usage['bandwidth']['used_bytes'] ?? 0),
                    'formatted_limit' => $this->formatBytes($usage['bandwidth']['limit'] ?? 0),
                ],
                'transformations' => [
                    'used' => $usage['transformations']['used'] ?? 0,
                    'limit' => $usage['transformations']['limit'] ?? 0,
                ],
                'requests' => [
                    'used' => $usage['requests']['used'] ?? 0,
                    'limit' => $usage['requests']['limit'] ?? 0,
                ]
            ];
        } catch (Exception $e) {
            throw new Exception("Failed to get usage stats: " . $e->getMessage());
        }
    }

    /**
     * Générer URL de thumbnail
     */
    private function generateThumbnailUrl(string $publicId): string
    {
        return $this->cloudinary->image($publicId)
            ->resize(Scale::scale(150))
            ->toUrl();
    }

    /**
     * Générer URL de taille moyenne
     */
    private function generateMediumUrl(string $publicId): string
    {
        return $this->cloudinary->image($publicId)
            ->resize(Scale::scale(400))
            ->toUrl();
    }

    /**
     * Formater les bytes en format lisible
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $bytes = max($bytes, 0);
        $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
        $pow = min($pow, count($units) - 1);
        
        $bytes /= pow(1024, $pow);
        
        return round($bytes, 2) . ' ' . $units[$pow];
    }
}