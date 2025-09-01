<?php

namespace App\Modules\Trips\Services;

use App\Modules\Trips\Models\TripImage;
use PDO;
use Exception;
use finfo;

class TripImageService
{
    private PDO $db;
    private string $uploadDirectory;
    
    const MAX_FILE_SIZE = 3 * 1024 * 1024; // 3MB in bytes
    const MAX_IMAGES_PER_TRIP = 2;
    const ALLOWED_MIME_TYPES = [
        'image/jpeg',
        'image/jpg', 
        'image/png',
        'image/webp'
    ];
    const ALLOWED_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp'];

    public function __construct(PDO $db, string $uploadDirectory = '')
    {
        $this->db = $db;
        $this->uploadDirectory = $uploadDirectory ?: __DIR__ . '/../../../../storage/images/';
        
        // Create upload directory if it doesn't exist
        if (!is_dir($this->uploadDirectory)) {
            mkdir($this->uploadDirectory, 0755, true);
        }
    }

    /**
     * Upload and save trip images
     */
    public function uploadTripImages(int $tripId, array $uploadedFiles): array
    {
        $results = [];
        $currentCount = $this->getTripImageCount($tripId);
        
        if (count($uploadedFiles) + $currentCount > self::MAX_IMAGES_PER_TRIP) {
            throw new Exception("Maximum " . self::MAX_IMAGES_PER_TRIP . " images allowed per trip");
        }

        foreach ($uploadedFiles as $index => $file) {
            if ($file['error'] !== UPLOAD_ERR_OK) {
                throw new Exception("Upload error for file " . ($index + 1) . ": " . $this->getUploadErrorMessage($file['error']));
            }

            // Validate file
            $this->validateUploadedFile($file);
            
            // Determine upload order
            $uploadOrder = $currentCount + $index + 1;
            
            // Save file and create database record
            $tripImage = $this->saveUploadedFile($tripId, $file, $uploadOrder);
            $results[] = $tripImage->toArray();
        }

        // Update trip image counters
        $this->updateTripImageCounters($tripId);
        
        return $results;
    }

    /**
     * Get all images for a trip
     */
    public function getTripImages(int $tripId): array
    {
        $stmt = $this->db->prepare("
            SELECT * FROM trip_images 
            WHERE trip_id = ? 
            ORDER BY upload_order ASC
        ");
        $stmt->execute([$tripId]);
        
        $images = [];
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            $images[] = TripImage::fromArray($row);
        }
        
        return $images;
    }

    /**
     * Delete trip image
     */
    public function deleteTripImage(int $tripId, int $imageId): bool
    {
        // Get image info first
        $stmt = $this->db->prepare("SELECT * FROM trip_images WHERE id = ? AND trip_id = ?");
        $stmt->execute([$imageId, $tripId]);
        $imageData = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$imageData) {
            throw new Exception("Image not found");
        }

        $tripImage = TripImage::fromArray($imageData);
        
        // Delete file from filesystem
        $fullPath = $_SERVER['DOCUMENT_ROOT'] . '/' . ltrim($tripImage->getImagePath(), '/');
        if (file_exists($fullPath)) {
            unlink($fullPath);
        }

        // Delete from database
        $stmt = $this->db->prepare("DELETE FROM trip_images WHERE id = ?");
        $result = $stmt->execute([$imageId]);
        
        // Update trip counters
        $this->updateTripImageCounters($tripId);
        
        return $result;
    }

    /**
     * Delete all images for a trip
     */
    public function deleteAllTripImages(int $tripId): bool
    {
        $images = $this->getTripImages($tripId);
        
        foreach ($images as $image) {
            $fullPath = $_SERVER['DOCUMENT_ROOT'] . '/' . ltrim($image->getImagePath(), '/');
            if (file_exists($fullPath)) {
                unlink($fullPath);
            }
        }

        $stmt = $this->db->prepare("DELETE FROM trip_images WHERE trip_id = ?");
        $result = $stmt->execute([$tripId]);
        
        // Update trip counters
        $this->updateTripImageCounters($tripId);
        
        return $result;
    }

    /**
     * Validate uploaded file
     */
    private function validateUploadedFile(array $file): void
    {
        // Check file size
        if ($file['size'] > self::MAX_FILE_SIZE) {
            throw new Exception("File size exceeds maximum allowed size of 3MB");
        }

        // Check mime type
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mimeType = $finfo->file($file['tmp_name']);
        
        if (!in_array($mimeType, self::ALLOWED_MIME_TYPES)) {
            throw new Exception("Invalid file type. Only JPG, PNG and WebP images are allowed");
        }

        // Check extension
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        if (!in_array($extension, self::ALLOWED_EXTENSIONS)) {
            throw new Exception("Invalid file extension. Only jpg, png and webp files are allowed");
        }

        // Additional security: check if it's actually an image
        $imageInfo = getimagesize($file['tmp_name']);
        if ($imageInfo === false) {
            throw new Exception("File is not a valid image");
        }
    }

    /**
     * Save uploaded file and create database record
     */
    private function saveUploadedFile(int $tripId, array $file, int $uploadOrder): TripImage
    {
        // Create trip-specific directory
        $tripDir = $this->uploadDirectory . $tripId . '/';
        if (!is_dir($tripDir)) {
            mkdir($tripDir, 0755, true);
        }

        // Generate unique filename
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $filename = $tripId . '_' . $uploadOrder . '_' . time() . '.' . $extension;
        $relativePath = 'storage/images/' . $tripId . '/' . $filename;
        $fullPath = $tripDir . $filename;

        // Move uploaded file
        if (!move_uploaded_file($file['tmp_name'], $fullPath)) {
            throw new Exception("Failed to save uploaded file");
        }

        // Create database record
        $finfo = new finfo(FILEINFO_MIME_TYPE);
        $mimeType = $finfo->file($fullPath);
        
        $tripImage = new TripImage(
            $tripId,
            $relativePath,
            $file['name'],
            $file['size'],
            $mimeType,
            $uploadOrder
        );

        $stmt = $this->db->prepare("
            INSERT INTO trip_images (trip_id, image_path, image_name, file_size, mime_type, upload_order) 
            VALUES (?, ?, ?, ?, ?, ?)
        ");
        
        $stmt->execute([
            $tripImage->getTripId(),
            $tripImage->getImagePath(),
            $tripImage->getImageName(),
            $tripImage->getFileSize(),
            $tripImage->getMimeType(),
            $tripImage->getUploadOrder()
        ]);

        $tripImage->setId($this->db->lastInsertId());
        return $tripImage;
    }

    /**
     * Get current image count for a trip
     */
    private function getTripImageCount(int $tripId): int
    {
        $stmt = $this->db->prepare("SELECT COUNT(*) FROM trip_images WHERE trip_id = ?");
        $stmt->execute([$tripId]);
        return (int) $stmt->fetchColumn();
    }

    /**
     * Update trip image counters
     */
    private function updateTripImageCounters(int $tripId): void
    {
        $count = $this->getTripImageCount($tripId);
        $hasImages = $count > 0;
        
        $stmt = $this->db->prepare("
            UPDATE trips 
            SET has_images = ?, image_count = ? 
            WHERE id = ?
        ");
        $stmt->execute([$hasImages, $count, $tripId]);
    }

    /**
     * Get upload error message
     */
    private function getUploadErrorMessage(int $errorCode): string
    {
        switch ($errorCode) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                return "File too large";
            case UPLOAD_ERR_PARTIAL:
                return "File upload was interrupted";
            case UPLOAD_ERR_NO_FILE:
                return "No file was uploaded";
            case UPLOAD_ERR_NO_TMP_DIR:
                return "Missing temporary folder";
            case UPLOAD_ERR_CANT_WRITE:
                return "Failed to write file to disk";
            case UPLOAD_ERR_EXTENSION:
                return "File upload stopped by extension";
            default:
                return "Unknown upload error";
        }
    }
}