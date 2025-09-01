<?php

namespace App\Modules\Trips\Models;

class TripReport
{
    private $id;
    private $tripId;
    private $reportedBy;
    private $reportType;
    private $description;
    private $status;
    private $resolution;
    private $resolvedBy;
    private $resolvedAt;
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
        $this->reportedBy = $data['reported_by'] ?? null;
        $this->reportType = $data['report_type'] ?? null;
        $this->description = $data['description'] ?? null;
        $this->status = $data['status'] ?? 'pending';
        $this->resolution = $data['resolution'] ?? null;
        $this->resolvedBy = $data['resolved_by'] ?? null;
        $this->resolvedAt = $data['resolved_at'] ?? null;
        $this->createdAt = $data['created_at'] ?? null;

        return $this;
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'trip_id' => $this->tripId,
            'reported_by' => $this->reportedBy,
            'report_type' => $this->reportType,
            'description' => $this->description,
            'status' => $this->status,
            'resolution' => $this->resolution,
            'resolved_by' => $this->resolvedBy,
            'resolved_at' => $this->resolvedAt,
            'created_at' => $this->createdAt,
        ];
    }

    public function toJson(): array
    {
        $data = $this->toArray();
        
        // Format dates
        if ($data['resolved_at']) {
            $data['resolved_at'] = date('c', strtotime($data['resolved_at']));
        }
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
        
        if (empty($this->reportedBy)) {
            $errors[] = 'Reporter user ID is required';
        }
        
        if (empty($this->reportType)) {
            $errors[] = 'Report type is required';
        }
        
        $validTypes = ['spam', 'fraud', 'inappropriate', 'misleading', 'prohibited_items', 'suspicious_price', 'other'];
        if (!in_array($this->reportType, $validTypes)) {
            $errors[] = 'Invalid report type';
        }
        
        $validStatuses = ['pending', 'reviewing', 'resolved', 'dismissed'];
        if (!in_array($this->status, $validStatuses)) {
            $errors[] = 'Invalid status';
        }
        
        return $errors;
    }

    // Business logic methods
    public function isPending(): bool
    {
        return $this->status === 'pending';
    }
    
    public function isReviewing(): bool
    {
        return $this->status === 'reviewing';
    }
    
    public function isResolved(): bool
    {
        return $this->status === 'resolved';
    }
    
    public function isDismissed(): bool
    {
        return $this->status === 'dismissed';
    }
    
    public function resolve(string $resolution, int $resolvedBy): self
    {
        $this->status = 'resolved';
        $this->resolution = $resolution;
        $this->resolvedBy = $resolvedBy;
        $this->resolvedAt = date('Y-m-d H:i:s');
        return $this;
    }
    
    public function dismiss(string $resolution, int $resolvedBy): self
    {
        $this->status = 'dismissed';
        $this->resolution = $resolution;
        $this->resolvedBy = $resolvedBy;
        $this->resolvedAt = date('Y-m-d H:i:s');
        return $this;
    }
    
    public function startReview(): self
    {
        if ($this->isPending()) {
            $this->status = 'reviewing';
        }
        return $this;
    }

    // Getters and Setters
    public function getId(): ?int { return $this->id; }
    public function setId(?int $id): self { $this->id = $id; return $this; }
    
    public function getTripId(): ?int { return $this->tripId; }
    public function setTripId(?int $tripId): self { $this->tripId = $tripId; return $this; }
    
    public function getReportedBy(): ?int { return $this->reportedBy; }
    public function setReportedBy(?int $reportedBy): self { $this->reportedBy = $reportedBy; return $this; }
    
    public function getReportType(): ?string { return $this->reportType; }
    public function setReportType(?string $reportType): self { $this->reportType = $reportType; return $this; }
    
    public function getDescription(): ?string { return $this->description; }
    public function setDescription(?string $description): self { $this->description = $description; return $this; }
    
    public function getStatus(): string { return $this->status; }
    public function setStatus(string $status): self { $this->status = $status; return $this; }
    
    public function getResolution(): ?string { return $this->resolution; }
    public function setResolution(?string $resolution): self { $this->resolution = $resolution; return $this; }
    
    public function getResolvedBy(): ?int { return $this->resolvedBy; }
    public function setResolvedBy(?int $resolvedBy): self { $this->resolvedBy = $resolvedBy; return $this; }
    
    public function getResolvedAt(): ?string { return $this->resolvedAt; }
    public function setResolvedAt(?string $resolvedAt): self { $this->resolvedAt = $resolvedAt; return $this; }
    
    public function getCreatedAt(): ?string { return $this->createdAt; }
    public function setCreatedAt(?string $createdAt): self { $this->createdAt = $createdAt; return $this; }
}