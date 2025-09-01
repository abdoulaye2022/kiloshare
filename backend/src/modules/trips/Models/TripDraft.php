<?php

namespace App\Modules\Trips\Models;

class TripDraft
{
    private $id;
    private $userId;
    private $tripId;
    private $draftData;
    private $draftName;
    private $version;
    private $autoSaved;
    private $lastModified;
    private $createdAt;

    public function __construct(array $data = [])
    {
        if (!empty($data)) {
            $this->fromArray($data);
        }
    }

    public function fromArray(array $data): self
    {
        $this->id = $data['id'] ?? null;
        $this->userId = $data['user_id'] ?? null;
        $this->tripId = $data['trip_id'] ?? null;
        $this->draftData = $data['draft_data'] ?? null;
        $this->draftName = $data['draft_name'] ?? null;
        $this->version = $data['version'] ?? 1;
        $this->autoSaved = $data['auto_saved'] ?? true;
        $this->lastModified = $data['last_modified'] ?? null;
        $this->createdAt = $data['created_at'] ?? null;

        return $this;
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->userId,
            'trip_id' => $this->tripId,
            'draft_data' => $this->draftData,
            'draft_name' => $this->draftName,
            'version' => $this->version,
            'auto_saved' => $this->autoSaved,
            'last_modified' => $this->lastModified,
            'created_at' => $this->createdAt,
        ];
    }

    public function toJson(): array
    {
        $data = $this->toArray();
        
        // Format dates
        if ($data['last_modified']) {
            $data['last_modified'] = date('c', strtotime($data['last_modified']));
        }
        if ($data['created_at']) {
            $data['created_at'] = date('c', strtotime($data['created_at']));
        }
        
        // Parse JSON draft_data
        if ($data['draft_data']) {
            $data['draft_data'] = json_decode($data['draft_data'], true);
        }
        
        // Convert types
        $data['version'] = (int) $data['version'];
        $data['auto_saved'] = (bool) $data['auto_saved'];
        
        return $data;
    }

    public function validate(): array
    {
        $errors = [];
        
        if (empty($this->userId)) {
            $errors[] = 'User ID is required';
        }
        
        if (empty($this->draftData)) {
            $errors[] = 'Draft data is required';
        }
        
        return $errors;
    }

    // Business logic
    public function isAutoSave(): bool
    {
        return $this->autoSaved === true;
    }
    
    public function getDraftDataAsArray(): ?array
    {
        if (!$this->draftData) return null;
        return json_decode($this->draftData, true);
    }
    
    public function setDraftDataFromArray(array $data): self
    {
        $this->draftData = json_encode($data);
        return $this;
    }

    // Getters and Setters
    public function getId(): ?int { return $this->id; }
    public function setId(?int $id): self { $this->id = $id; return $this; }
    
    public function getUserId(): ?int { return $this->userId; }
    public function setUserId(?int $userId): self { $this->userId = $userId; return $this; }
    
    public function getTripId(): ?int { return $this->tripId; }
    public function setTripId(?int $tripId): self { $this->tripId = $tripId; return $this; }
    
    public function getDraftData(): ?string { return $this->draftData; }
    public function setDraftData(?string $draftData): self { $this->draftData = $draftData; return $this; }
    
    public function getDraftName(): ?string { return $this->draftName; }
    public function setDraftName(?string $draftName): self { $this->draftName = $draftName; return $this; }
    
    public function getVersion(): int { return $this->version; }
    public function setVersion(int $version): self { $this->version = $version; return $this; }
    
    public function isAutoSaved(): bool { return $this->autoSaved; }
    public function setAutoSaved(bool $autoSaved): self { $this->autoSaved = $autoSaved; return $this; }
    
    public function getLastModified(): ?string { return $this->lastModified; }
    public function setLastModified(?string $lastModified): self { $this->lastModified = $lastModified; return $this; }
    
    public function getCreatedAt(): ?string { return $this->createdAt; }
    public function setCreatedAt(?string $createdAt): self { $this->createdAt = $createdAt; return $this; }
}