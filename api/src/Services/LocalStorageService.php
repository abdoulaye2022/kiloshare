<?php

declare(strict_types=1);

namespace KiloShare\Services;

use Exception;

/**
 * Service de stockage local pour le développement
 * Simule le comportement de Google Cloud Storage en sauvegardant localement
 */
class LocalStorageService
{
    private string $basePath;
    private string $baseUrl;

    public function __construct()
    {
        $this->basePath = __DIR__ . '/../../storage/uploads';
        $this->baseUrl = $_ENV['API_BASE_URL'] ?? 'http://127.0.0.1:8080';

        // Créer le dossier de stockage s'il n'existe pas
        if (!file_exists($this->basePath)) {
            mkdir($this->basePath, 0755, true);
        }
    }

    /**
     * Upload an image to local storage
     */
    public function uploadImage(string $filePath, string $destination, array $options = []): array
    {
        try {
            // Créer les sous-dossiers nécessaires
            $fullDestination = $this->basePath . '/' . $destination;
            $directory = dirname($fullDestination);

            if (!file_exists($directory)) {
                mkdir($directory, 0755, true);
            }

            // Copier le fichier
            if (!copy($filePath, $fullDestination)) {
                throw new Exception('Failed to copy file to local storage');
            }

            return [
                'success' => true,
                'url' => $this->getPublicUrl($destination),
                'path' => $destination,
            ];
        } catch (Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Delete an image from local storage
     */
    public function deleteImage(string $path): array
    {
        try {
            $fullPath = $this->basePath . '/' . $path;

            if (file_exists($fullPath)) {
                unlink($fullPath);
            }

            return ['success' => true];
        } catch (Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get public URL for an image
     */
    public function getPublicUrl(string $path): string
    {
        return $this->baseUrl . '/storage/uploads/' . $path;
    }

    /**
     * List all images in a directory
     */
    public function listImages(string $prefix = ''): array
    {
        $fullPath = $this->basePath . '/' . $prefix;
        $images = [];

        if (file_exists($fullPath) && is_dir($fullPath)) {
            $files = new \RecursiveIteratorIterator(
                new \RecursiveDirectoryIterator($fullPath),
                \RecursiveIteratorIterator::SELF_FIRST
            );

            foreach ($files as $file) {
                if ($file->isFile()) {
                    $relativePath = str_replace($this->basePath . '/', '', $file->getPathname());
                    $images[] = [
                        'path' => $relativePath,
                        'url' => $this->getPublicUrl($relativePath),
                        'size' => $file->getSize(),
                        'modified' => $file->getMTime(),
                    ];
                }
            }
        }

        return $images;
    }

    /**
     * Get storage statistics
     */
    public function getStats(): array
    {
        $totalSize = 0;
        $fileCount = 0;

        if (file_exists($this->basePath)) {
            $files = new \RecursiveIteratorIterator(
                new \RecursiveDirectoryIterator($this->basePath),
                \RecursiveIteratorIterator::SELF_FIRST
            );

            foreach ($files as $file) {
                if ($file->isFile()) {
                    $totalSize += $file->getSize();
                    $fileCount++;
                }
            }
        }

        return [
            'total_files' => $fileCount,
            'total_size_bytes' => $totalSize,
            'total_size_mb' => round($totalSize / 1024 / 1024, 2),
        ];
    }
}
