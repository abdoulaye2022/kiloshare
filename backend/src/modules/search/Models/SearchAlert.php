<?php

namespace App\Modules\Search\Models;

class SearchAlert
{
    private ?int $id;
    private int $userId;
    private string $departureCity;
    private string $departureCountry;
    private string $arrivalCity;
    private string $arrivalCountry;
    private ?string $dateRangeStart;
    private ?string $dateRangeEnd;
    private ?float $maxPrice;
    private ?int $maxWeight;
    private ?string $transportType;
    private ?float $minRating;
    private bool $verifiedOnly;
    private bool $active;
    private string $createdAt;
    private string $updatedAt;

    public function __construct(
        int $userId,
        string $departureCity,
        string $arrivalCity,
        string $departureCountry = 'Canada',
        string $arrivalCountry = 'Canada',
        ?string $dateRangeStart = null,
        ?string $dateRangeEnd = null,
        ?float $maxPrice = null,
        ?int $maxWeight = null,
        ?string $transportType = null,
        ?float $minRating = null,
        bool $verifiedOnly = false,
        bool $active = true,
        ?int $id = null,
        ?string $createdAt = null,
        ?string $updatedAt = null
    ) {
        $this->userId = $userId;
        $this->departureCity = $departureCity;
        $this->departureCountry = $departureCountry;
        $this->arrivalCity = $arrivalCity;
        $this->arrivalCountry = $arrivalCountry;
        $this->dateRangeStart = $dateRangeStart;
        $this->dateRangeEnd = $dateRangeEnd;
        $this->maxPrice = $maxPrice;
        $this->maxWeight = $maxWeight;
        $this->transportType = $transportType;
        $this->minRating = $minRating;
        $this->verifiedOnly = $verifiedOnly;
        $this->active = $active;
        $this->id = $id;
        $this->createdAt = $createdAt ?? date('Y-m-d H:i:s');
        $this->updatedAt = $updatedAt ?? date('Y-m-d H:i:s');
    }

    public static function fromArray(array $data): self
    {
        return new self(
            (int) $data['user_id'],
            $data['departure_city'],
            $data['arrival_city'],
            $data['departure_country'] ?? 'Canada',
            $data['arrival_country'] ?? 'Canada',
            $data['date_range_start'] ?? null,
            $data['date_range_end'] ?? null,
            isset($data['max_price']) ? (float) $data['max_price'] : null,
            isset($data['max_weight']) ? (int) $data['max_weight'] : null,
            $data['transport_type'] ?? null,
            isset($data['min_rating']) ? (float) $data['min_rating'] : null,
            (bool) ($data['verified_only'] ?? false),
            (bool) ($data['active'] ?? true),
            isset($data['id']) ? (int) $data['id'] : null,
            $data['created_at'] ?? null,
            $data['updated_at'] ?? null
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->userId,
            'departure_city' => $this->departureCity,
            'departure_country' => $this->departureCountry,
            'arrival_city' => $this->arrivalCity,
            'arrival_country' => $this->arrivalCountry,
            'date_range_start' => $this->dateRangeStart,
            'date_range_end' => $this->dateRangeEnd,
            'max_price' => $this->maxPrice,
            'max_weight' => $this->maxWeight,
            'transport_type' => $this->transportType,
            'min_rating' => $this->minRating,
            'verified_only' => $this->verifiedOnly,
            'active' => $this->active,
            'created_at' => $this->createdAt,
            'updated_at' => $this->updatedAt
        ];
    }

    public function toDbArray(): array
    {
        return [
            'user_id' => $this->userId,
            'departure_city' => $this->departureCity,
            'departure_country' => $this->departureCountry,
            'arrival_city' => $this->arrivalCity,
            'arrival_country' => $this->arrivalCountry,
            'date_range_start' => $this->dateRangeStart,
            'date_range_end' => $this->dateRangeEnd,
            'max_price' => $this->maxPrice,
            'max_weight' => $this->maxWeight,
            'transport_type' => $this->transportType,
            'min_rating' => $this->minRating,
            'verified_only' => $this->verifiedOnly ? 1 : 0,
            'active' => $this->active ? 1 : 0
        ];
    }

    // Getters
    public function getId(): ?int { return $this->id; }
    public function getUserId(): int { return $this->userId; }
    public function getDepartureCity(): string { return $this->departureCity; }
    public function getDepartureCountry(): string { return $this->departureCountry; }
    public function getArrivalCity(): string { return $this->arrivalCity; }
    public function getArrivalCountry(): string { return $this->arrivalCountry; }
    public function getDateRangeStart(): ?string { return $this->dateRangeStart; }
    public function getDateRangeEnd(): ?string { return $this->dateRangeEnd; }
    public function getMaxPrice(): ?float { return $this->maxPrice; }
    public function getMaxWeight(): ?int { return $this->maxWeight; }
    public function getTransportType(): ?string { return $this->transportType; }
    public function getMinRating(): ?float { return $this->minRating; }
    public function isVerifiedOnly(): bool { return $this->verifiedOnly; }
    public function isActive(): bool { return $this->active; }
    public function getCreatedAt(): string { return $this->createdAt; }
    public function getUpdatedAt(): string { return $this->updatedAt; }

    // Setters
    public function setId(int $id): void { $this->id = $id; }
    public function setActive(bool $active): void { 
        $this->active = $active;
        $this->updatedAt = date('Y-m-d H:i:s');
    }

    /**
     * Get a human-readable summary of the alert
     */
    public function getAlertSummary(): string
    {
        $summary = $this->departureCity . ' → ' . $this->arrivalCity;
        
        if ($this->dateRangeStart) {
            $summary .= ' • À partir du ' . date('d/m/Y', strtotime($this->dateRangeStart));
        }
        
        if ($this->maxPrice) {
            $summary .= ' • Max ' . $this->maxPrice . ' CAD/kg';
        }
        
        if ($this->transportType) {
            $types = [
                'plane' => '✈️',
                'car' => '🚗',
                'bus' => '🚌',
                'train' => '🚆'
            ];
            $summary .= ' • ' . ($types[$this->transportType] ?? $this->transportType);
        }
        
        return $summary;
    }

    /**
     * Check if a trip matches this alert criteria
     */
    public function matchesTrip(array $trip): bool
    {
        // Check basic route
        if (strcasecmp($trip['departure_city'] ?? '', $this->departureCity) !== 0 ||
            strcasecmp($trip['arrival_city'] ?? '', $this->arrivalCity) !== 0) {
            return false;
        }
        
        // Check date range
        if ($this->dateRangeStart && !empty($trip['departure_date'])) {
            $tripDate = date('Y-m-d', strtotime($trip['departure_date']));
            if ($tripDate < $this->dateRangeStart) {
                return false;
            }
        }
        
        if ($this->dateRangeEnd && !empty($trip['departure_date'])) {
            $tripDate = date('Y-m-d', strtotime($trip['departure_date']));
            if ($tripDate > $this->dateRangeEnd) {
                return false;
            }
        }
        
        // Check max price
        if ($this->maxPrice && !empty($trip['price_per_kg'])) {
            if ((float) $trip['price_per_kg'] > $this->maxPrice) {
                return false;
            }
        }
        
        // Check max weight
        if ($this->maxWeight && !empty($trip['available_weight_kg'])) {
            if ((int) $trip['available_weight_kg'] < $this->maxWeight) {
                return false;
            }
        }
        
        // Check transport type
        if ($this->transportType && !empty($trip['transport_type'])) {
            if (strcasecmp($trip['transport_type'], $this->transportType) !== 0) {
                return false;
            }
        }
        
        // Check verified only
        if ($this->verifiedOnly && empty($trip['user_verified'])) {
            return false;
        }
        
        return true;
    }
}