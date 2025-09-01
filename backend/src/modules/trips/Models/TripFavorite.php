<?php

namespace App\Modules\Trips\Models;

class TripFavorite
{
    private $id;
    private $tripId;
    private $userId;
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
        $this->tripId = $data['trip_id'] ?? null;
        $this->userId = $data['user_id'] ?? null;
        $this->createdAt = $data['created_at'] ?? null;

        return $this;
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'trip_id' => $this->tripId,
            'user_id' => $this->userId,
            'created_at' => $this->createdAt,
        ];
    }

    public function toJson(): array
    {
        $data = $this->toArray();
        
        // Format date
        if ($data['created_at']) {
            $data['created_at'] = date('c', strtotime($data['created_at']));
        }
        
        return $data;
    }

    public function validate(): array
    {
        $errors = [];
        
        if (empty($this->tripId)) {
            $errors[] = 'Trip ID is required';
        }
        
        if (empty($this->userId)) {
            $errors[] = 'User ID is required';
        }
        
        return $errors;
    }

    // Getters and Setters
    public function getId(): ?int { return $this->id; }
    public function setId(?int $id): self { $this->id = $id; return $this; }
    
    public function getTripId(): ?int { return $this->tripId; }
    public function setTripId(?int $tripId): self { $this->tripId = $tripId; return $this; }
    
    public function getUserId(): ?int { return $this->userId; }
    public function setUserId(?int $userId): self { $this->userId = $userId; return $this; }
    
    public function getCreatedAt(): ?string { return $this->createdAt; }
    public function setCreatedAt(?string $createdAt): self { $this->createdAt = $createdAt; return $this; }
}