<?php

namespace App\Modules\Trips\Models;

class TripActionLog
{
    private $id;
    private $tripId;
    private $userId;
    private $action;
    private $oldStatus;
    private $newStatus;
    private $changedFields;
    private $reason;
    private $metadata;
    private $ipAddress;
    private $userAgent;
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
        $this->action = $data['action'] ?? null;
        $this->oldStatus = $data['old_status'] ?? null;
        $this->newStatus = $data['new_status'] ?? null;
        $this->changedFields = $data['changed_fields'] ?? null;
        $this->reason = $data['reason'] ?? null;
        $this->metadata = $data['metadata'] ?? null;
        $this->ipAddress = $data['ip_address'] ?? null;
        $this->userAgent = $data['user_agent'] ?? null;
        $this->createdAt = $data['created_at'] ?? null;

        return $this;
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'trip_id' => $this->tripId,
            'user_id' => $this->userId,
            'action' => $this->action,
            'old_status' => $this->oldStatus,
            'new_status' => $this->newStatus,
            'changed_fields' => $this->changedFields,
            'reason' => $this->reason,
            'metadata' => $this->metadata,
            'ip_address' => $this->ipAddress,
            'user_agent' => $this->userAgent,
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
        
        // Parse JSON fields
        if ($data['changed_fields']) {
            $data['changed_fields'] = json_decode($data['changed_fields'], true);
        }
        if ($data['metadata']) {
            $data['metadata'] = json_decode($data['metadata'], true);
        }
        
        return $data;
    }

    // Getters and Setters
    public function getId(): ?int { return $this->id; }
    public function setId(?int $id): self { $this->id = $id; return $this; }
    
    public function getTripId(): ?int { return $this->tripId; }
    public function setTripId(?int $tripId): self { $this->tripId = $tripId; return $this; }
    
    public function getUserId(): ?int { return $this->userId; }
    public function setUserId(?int $userId): self { $this->userId = $userId; return $this; }
    
    public function getAction(): ?string { return $this->action; }
    public function setAction(?string $action): self { $this->action = $action; return $this; }
    
    public function getOldStatus(): ?string { return $this->oldStatus; }
    public function setOldStatus(?string $oldStatus): self { $this->oldStatus = $oldStatus; return $this; }
    
    public function getNewStatus(): ?string { return $this->newStatus; }
    public function setNewStatus(?string $newStatus): self { $this->newStatus = $newStatus; return $this; }
    
    public function getChangedFields(): ?string { return $this->changedFields; }
    public function setChangedFields(?string $changedFields): self { $this->changedFields = $changedFields; return $this; }
    
    public function getReason(): ?string { return $this->reason; }
    public function setReason(?string $reason): self { $this->reason = $reason; return $this; }
    
    public function getMetadata(): ?string { return $this->metadata; }
    public function setMetadata(?string $metadata): self { $this->metadata = $metadata; return $this; }
    
    public function getIpAddress(): ?string { return $this->ipAddress; }
    public function setIpAddress(?string $ipAddress): self { $this->ipAddress = $ipAddress; return $this; }
    
    public function getUserAgent(): ?string { return $this->userAgent; }
    public function setUserAgent(?string $userAgent): self { $this->userAgent = $userAgent; return $this; }
    
    public function getCreatedAt(): ?string { return $this->createdAt; }
    public function setCreatedAt(?string $createdAt): self { $this->createdAt = $createdAt; return $this; }
}