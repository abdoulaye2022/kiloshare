<?php

namespace App\Modules\Trips\Models;

use DateTime;

class TripImage
{
    private ?int $id;
    private int $tripId;
    private string $imagePath;
    private string $imageName;
    private int $fileSize;
    private string $mimeType;
    private int $uploadOrder; // 1 or 2
    private DateTime $createdAt;
    private DateTime $updatedAt;

    public function __construct(
        int $tripId,
        string $imagePath,
        string $imageName,
        int $fileSize,
        string $mimeType,
        int $uploadOrder = 1,
        ?int $id = null,
        ?DateTime $createdAt = null,
        ?DateTime $updatedAt = null
    ) {
        $this->id = $id;
        $this->tripId = $tripId;
        $this->imagePath = $imagePath;
        $this->imageName = $imageName;
        $this->fileSize = $fileSize;
        $this->mimeType = $mimeType;
        $this->uploadOrder = $uploadOrder;
        $this->createdAt = $createdAt ?? new DateTime();
        $this->updatedAt = $updatedAt ?? new DateTime();
    }

    // Getters
    public function getId(): ?int { return $this->id; }
    public function getTripId(): int { return $this->tripId; }
    public function getImagePath(): string { return $this->imagePath; }
    public function getImageName(): string { return $this->imageName; }
    public function getFileSize(): int { return $this->fileSize; }
    public function getMimeType(): string { return $this->mimeType; }
    public function getUploadOrder(): int { return $this->uploadOrder; }
    public function getCreatedAt(): DateTime { return $this->createdAt; }
    public function getUpdatedAt(): DateTime { return $this->updatedAt; }

    // Setters
    public function setId(int $id): void { $this->id = $id; }
    public function setImagePath(string $imagePath): void { $this->imagePath = $imagePath; }
    public function setImageName(string $imageName): void { $this->imageName = $imageName; }
    public function setFileSize(int $fileSize): void { $this->fileSize = $fileSize; }
    public function setMimeType(string $mimeType): void { $this->mimeType = $mimeType; }
    public function setUploadOrder(int $uploadOrder): void { $this->uploadOrder = $uploadOrder; }
    public function setUpdatedAt(DateTime $updatedAt): void { $this->updatedAt = $updatedAt; }

    /**
     * Get full URL for the image
     */
    public function getImageUrl(string $baseUrl = ''): string
    {
        $baseUrl = $baseUrl ?: (isset($_SERVER['REQUEST_SCHEME']) ? 
            $_SERVER['REQUEST_SCHEME'] . '://' . $_SERVER['HTTP_HOST'] : 'http://localhost');
        return rtrim($baseUrl, '/') . '/' . ltrim($this->imagePath, '/');
    }

    /**
     * Get file size in human readable format
     */
    public function getFormattedFileSize(): string
    {
        $bytes = $this->fileSize;
        if ($bytes >= 1048576) {
            return round($bytes / 1048576, 2) . ' MB';
        } elseif ($bytes >= 1024) {
            return round($bytes / 1024, 2) . ' KB';
        } else {
            return $bytes . ' B';
        }
    }

    /**
     * Check if image is valid (file exists and is readable)
     */
    public function isValid(): bool
    {
        $fullPath = $_SERVER['DOCUMENT_ROOT'] . '/' . ltrim($this->imagePath, '/');
        return file_exists($fullPath) && is_readable($fullPath);
    }

    /**
     * Convert to array for JSON serialization
     */
    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'trip_id' => $this->tripId,
            'image_path' => $this->imagePath,
            'image_name' => $this->imageName,
            'image_url' => $this->getImageUrl(),
            'file_size' => $this->fileSize,
            'formatted_file_size' => $this->getFormattedFileSize(),
            'mime_type' => $this->mimeType,
            'upload_order' => $this->uploadOrder,
            'created_at' => $this->createdAt->format('Y-m-d H:i:s'),
            'updated_at' => $this->updatedAt->format('Y-m-d H:i:s'),
        ];
    }

    /**
     * Convert to JSON
     */
    public function toJson(): string
    {
        return json_encode($this->toArray());
    }

    /**
     * Create from database array
     */
    public static function fromArray(array $data): self
    {
        return new self(
            $data['trip_id'],
            $data['image_path'],
            $data['image_name'],
            $data['file_size'],
            $data['mime_type'],
            $data['upload_order'] ?? 1,
            $data['id'] ?? null,
            isset($data['created_at']) ? new DateTime($data['created_at']) : null,
            isset($data['updated_at']) ? new DateTime($data['updated_at']) : null
        );
    }
}