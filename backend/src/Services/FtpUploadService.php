<?php

namespace App\Services;

use Psr\Http\Message\UploadedFileInterface;
use Exception;

class FtpUploadService
{
    private string $uploadPath;
    private int $maxFileSize;
    private array $allowedExtensions;
    private array $allowedMimeTypes;

    public function __construct()
    {
        $this->uploadPath = $_ENV['UPLOAD_PATH'] ?? 'uploads/';
        $this->maxFileSize = (int) ($_ENV['MAX_FILE_SIZE'] ?? 10485760); // 10MB par défaut
        $this->allowedExtensions = explode(',', $_ENV['ALLOWED_EXTENSIONS'] ?? 'jpg,jpeg,png,gif,pdf');
        $this->allowedMimeTypes = [
            'image/jpeg',
            'image/jpg', 
            'image/png',
            'image/gif',
            'application/pdf',
            'image/webp'
        ];
    }

    public function uploadFile(UploadedFileInterface $uploadedFile, string $folder = ''): array
    {
        try {
            // Valider le fichier
            $validation = $this->validateFile($uploadedFile);
            if (!$validation['valid']) {
                return [
                    'success' => false,
                    'message' => $validation['message']
                ];
            }

            // Générer un nom de fichier unique
            $extension = $this->getFileExtension($uploadedFile);
            $fileName = $this->generateUniqueFileName($extension);
            
            // Construire le chemin de destination
            $destinationPath = $this->buildDestinationPath($folder);
            $filePath = $destinationPath . '/' . $fileName;
            $fullPath = $this->uploadPath . $filePath;

            // Créer le répertoire s'il n'existe pas
            $this->ensureDirectoryExists(dirname($fullPath));

            // Déplacer le fichier
            $uploadedFile->moveTo($fullPath);

            // Vérifier que le fichier a été créé
            if (!file_exists($fullPath)) {
                throw new Exception('Échec du téléchargement du fichier');
            }

            // Générer l'URL publique du fichier
            $fileUrl = $this->generateFileUrl($filePath);

            return [
                'success' => true,
                'message' => 'Fichier téléchargé avec succès',
                'file_path' => $filePath,
                'file_name' => $fileName,
                'file_url' => $fileUrl,
                'file_size' => $uploadedFile->getSize(),
                'mime_type' => $uploadedFile->getClientMediaType()
            ];

        } catch (Exception $e) {
            return [
                'success' => false,
                'message' => 'Erreur lors du téléchargement: ' . $e->getMessage()
            ];
        }
    }

    public function deleteFile(string $filePath): bool
    {
        try {
            $fullPath = $this->uploadPath . $filePath;
            
            if (file_exists($fullPath)) {
                return unlink($fullPath);
            }
            
            return true; // Le fichier n'existe pas déjà
        } catch (Exception $e) {
            return false;
        }
    }

    public function getFileUrl(string $filePath): string
    {
        return $this->generateFileUrl($filePath);
    }

    private function validateFile(UploadedFileInterface $uploadedFile): array
    {
        // Vérifier les erreurs d'upload
        if ($uploadedFile->getError() !== UPLOAD_ERR_OK) {
            return [
                'valid' => false,
                'message' => $this->getUploadErrorMessage($uploadedFile->getError())
            ];
        }

        // Vérifier la taille du fichier
        if ($uploadedFile->getSize() > $this->maxFileSize) {
            $maxSizeMB = round($this->maxFileSize / 1048576, 2);
            return [
                'valid' => false,
                'message' => "Le fichier est trop volumineux. Taille maximale autorisée: {$maxSizeMB}MB"
            ];
        }

        // Vérifier le type MIME
        $mimeType = $uploadedFile->getClientMediaType();
        if (!in_array($mimeType, $this->allowedMimeTypes)) {
            return [
                'valid' => false,
                'message' => 'Type de fichier non autorisé'
            ];
        }

        // Vérifier l'extension
        $extension = $this->getFileExtension($uploadedFile);
        if (!in_array(strtolower($extension), $this->allowedExtensions)) {
            $allowedStr = implode(', ', $this->allowedExtensions);
            return [
                'valid' => false,
                'message' => "Extension de fichier non autorisée. Extensions autorisées: {$allowedStr}"
            ];
        }

        return ['valid' => true];
    }

    private function getFileExtension(UploadedFileInterface $uploadedFile): string
    {
        $fileName = $uploadedFile->getClientFilename();
        return strtolower(pathinfo($fileName, PATHINFO_EXTENSION));
    }

    private function generateUniqueFileName(string $extension): string
    {
        $timestamp = time();
        $random = mt_rand(1000, 9999);
        return "file_{$timestamp}_{$random}.{$extension}";
    }

    private function buildDestinationPath(string $folder = ''): string
    {
        $datePath = date('Y/m/d');
        
        if ($folder) {
            return "{$folder}/{$datePath}";
        }
        
        return $datePath;
    }

    private function ensureDirectoryExists(string $directory): void
    {
        if (!is_dir($directory)) {
            if (!mkdir($directory, 0755, true)) {
                throw new Exception("Impossible de créer le répertoire: {$directory}");
            }
        }
    }

    private function generateFileUrl(string $filePath): string
    {
        $baseUrl = rtrim($_ENV['APP_URL'] ?? 'http://localhost:8080', '/');
        return "{$baseUrl}/uploads/{$filePath}";
    }

    private function getUploadErrorMessage(int $error): string
    {
        switch ($error) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                return 'Le fichier téléchargé dépasse la taille maximale autorisée';
            case UPLOAD_ERR_PARTIAL:
                return 'Le fichier n\'a été que partiellement téléchargé';
            case UPLOAD_ERR_NO_FILE:
                return 'Aucun fichier n\'a été téléchargé';
            case UPLOAD_ERR_NO_TMP_DIR:
                return 'Dossier temporaire manquant';
            case UPLOAD_ERR_CANT_WRITE:
                return 'Échec de l\'écriture du fichier sur le disque';
            case UPLOAD_ERR_EXTENSION:
                return 'Une extension PHP a arrêté le téléchargement du fichier';
            default:
                return 'Erreur de téléchargement inconnue';
        }
    }

    public function getUploadStats(): array
    {
        try {
            $totalFiles = 0;
            $totalSize = 0;
            
            $this->countFilesRecursive($this->uploadPath, $totalFiles, $totalSize);
            
            return [
                'total_files' => $totalFiles,
                'total_size' => $totalSize,
                'total_size_mb' => round($totalSize / 1048576, 2),
                'upload_path' => $this->uploadPath,
                'max_file_size_mb' => round($this->maxFileSize / 1048576, 2),
                'allowed_extensions' => $this->allowedExtensions
            ];
        } catch (Exception $e) {
            return [
                'error' => 'Erreur lors du calcul des statistiques: ' . $e->getMessage()
            ];
        }
    }

    private function countFilesRecursive(string $directory, int &$fileCount, int &$totalSize): void
    {
        if (!is_dir($directory)) {
            return;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($directory, \RecursiveDirectoryIterator::SKIP_DOTS)
        );

        foreach ($iterator as $file) {
            if ($file->isFile()) {
                $fileCount++;
                $totalSize += $file->getSize();
            }
        }
    }

    public function cleanupOldFiles(int $daysOld = 30): array
    {
        try {
            $deletedFiles = 0;
            $freedSpace = 0;
            $cutoffTime = time() - ($daysOld * 24 * 60 * 60);

            $this->cleanupFilesRecursive($this->uploadPath, $cutoffTime, $deletedFiles, $freedSpace);

            return [
                'success' => true,
                'deleted_files' => $deletedFiles,
                'freed_space_mb' => round($freedSpace / 1048576, 2),
                'cutoff_days' => $daysOld
            ];
        } catch (Exception $e) {
            return [
                'success' => false,
                'message' => 'Erreur lors du nettoyage: ' . $e->getMessage()
            ];
        }
    }

    private function cleanupFilesRecursive(string $directory, int $cutoffTime, int &$deletedFiles, int &$freedSpace): void
    {
        if (!is_dir($directory)) {
            return;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($directory, \RecursiveDirectoryIterator::SKIP_DOTS)
        );

        foreach ($iterator as $file) {
            if ($file->isFile() && $file->getMTime() < $cutoffTime) {
                $fileSize = $file->getSize();
                if (unlink($file->getPathname())) {
                    $deletedFiles++;
                    $freedSpace += $fileSize;
                }
            }
        }
    }
}