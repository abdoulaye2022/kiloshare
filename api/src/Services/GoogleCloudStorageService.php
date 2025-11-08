<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Google\Cloud\Storage\StorageClient;
use Exception;

class GoogleCloudStorageService
{
    private StorageClient $storage;
    private string $bucketName;
    private $bucket;

    public function __construct()
    {
        $keyFilePath = $_ENV['GCS_KEY_FILE'] ?? '';
        $projectId = $_ENV['GCS_PROJECT_ID'] ?? '';

        // Sélectionner le bucket selon l'environnement
        $environment = $_ENV['ENVIRONMENT'] ?? $_ENV['APP_ENV'] ?? 'development';
        if ($environment === 'production') {
            $this->bucketName = $_ENV['GCS_BUCKET_NAME_PROD'] ?? 'kiloshare-prod';
        } else {
            $this->bucketName = $_ENV['GCS_BUCKET_NAME_DEV'] ?? 'kiloshare-dev';
        }

        if (empty($keyFilePath) || !file_exists($keyFilePath)) {
            throw new Exception('GCS key file not found or not configured');
        }

        $this->storage = new StorageClient([
            'keyFilePath' => $keyFilePath,
            'projectId' => $projectId
        ]);

        $this->bucket = $this->storage->bucket($this->bucketName);
    }

    /**
     * Upload an image to Google Cloud Storage
     */
    public function uploadImage(string $filePath, string $destination, array $options = []): array
    {
        try {
            $file = fopen($filePath, 'r');

            $object = $this->bucket->upload($file, [
                'name' => $destination,
                'metadata' => $options['metadata'] ?? []
                // Pas de predefinedAcl car on utilise le contrôle d'accès uniforme
                // Les permissions sont gérées au niveau du bucket avec IAM
            ]);

            return [
                'success' => true,
                'url' => $this->getPublicUrl($destination),
                'path' => $destination,
                'bucket' => $this->bucketName
            ];
        } catch (Exception $e) {
            error_log("GCS Upload Error: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Upload from base64
     */
    public function uploadBase64(string $base64Data, string $destination, array $options = []): array
    {
        try {
            // Remove data:image/jpeg;base64, prefix if present
            if (strpos($base64Data, 'base64,') !== false) {
                $base64Data = explode('base64,', $base64Data)[1];
            }

            $imageData = base64_decode($base64Data);

            $object = $this->bucket->upload($imageData, [
                'name' => $destination,
                'metadata' => $options['metadata'] ?? [],
                'predefinedAcl' => 'publicRead'
            ]);

            return [
                'success' => true,
                'url' => $this->getPublicUrl($destination),
                'path' => $destination,
                'bucket' => $this->bucketName
            ];
        } catch (Exception $e) {
            error_log("GCS Base64 Upload Error: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Delete an image from GCS
     */
    public function deleteImage(string $path): bool
    {
        try {
            $object = $this->bucket->object($path);
            $object->delete();
            return true;
        } catch (Exception $e) {
            error_log("GCS Delete Error: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Delete multiple images
     */
    public function deleteImages(array $paths): array
    {
        $results = [];
        foreach ($paths as $path) {
            $results[$path] = $this->deleteImage($path);
        }
        return $results;
    }

    /**
     * Get public URL for an image
     */
    public function getPublicUrl(string $path): string
    {
        return sprintf(
            'https://storage.googleapis.com/%s/%s',
            $this->bucketName,
            $path
        );
    }

    /**
     * Check if image exists
     */
    public function imageExists(string $path): bool
    {
        try {
            $object = $this->bucket->object($path);
            return $object->exists();
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * Get image info
     */
    public function getImageInfo(string $path): ?array
    {
        try {
            $object = $this->bucket->object($path);
            if (!$object->exists()) {
                return null;
            }

            $info = $object->info();
            return [
                'name' => $info['name'],
                'size' => $info['size'],
                'contentType' => $info['contentType'] ?? null,
                'timeCreated' => $info['timeCreated'] ?? null,
                'updated' => $info['updated'] ?? null,
                'url' => $this->getPublicUrl($path)
            ];
        } catch (Exception $e) {
            error_log("GCS Get Info Error: " . $e->getMessage());
            return null;
        }
    }

    /**
     * List images by prefix
     */
    public function listImages(string $prefix = '', int $limit = 100): array
    {
        try {
            $options = [
                'prefix' => $prefix,
                'maxResults' => $limit
            ];

            $objects = $this->bucket->objects($options);
            $images = [];

            foreach ($objects as $object) {
                $images[] = [
                    'name' => $object->name(),
                    'url' => $this->getPublicUrl($object->name()),
                    'size' => $object->info()['size'] ?? 0
                ];
            }

            return $images;
        } catch (Exception $e) {
            error_log("GCS List Error: " . $e->getMessage());
            return [];
        }
    }

    /**
     * Get bucket usage stats
     */
    public function getBucketStats(): array
    {
        try {
            $objects = $this->bucket->objects();
            $totalSize = 0;
            $count = 0;

            foreach ($objects as $object) {
                $info = $object->info();
                $totalSize += $info['size'] ?? 0;
                $count++;
            }

            return [
                'total_images' => $count,
                'total_size_bytes' => $totalSize,
                'total_size_mb' => round($totalSize / (1024 * 1024), 2),
                'bucket_name' => $this->bucketName
            ];
        } catch (Exception $e) {
            error_log("GCS Stats Error: " . $e->getMessage());
            return [
                'total_images' => 0,
                'total_size_bytes' => 0,
                'total_size_mb' => 0,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Generate a signed URL for private access (if needed in the future)
     */
    public function getSignedUrl(string $path, int $expirationMinutes = 60): string
    {
        try {
            $object = $this->bucket->object($path);
            $expiration = new \DateTime("+{$expirationMinutes} minutes");

            return $object->signedUrl($expiration);
        } catch (Exception $e) {
            error_log("GCS Signed URL Error: " . $e->getMessage());
            return '';
        }
    }
}
