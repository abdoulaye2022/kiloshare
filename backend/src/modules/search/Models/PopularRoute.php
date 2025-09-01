<?php

namespace App\Modules\Search\Models;

class PopularRoute
{
    private ?int $id;
    private string $departureCity;
    private string $departureCountry;
    private string $arrivalCity;
    private string $arrivalCountry;
    private int $searchCount;
    private string $lastSearched;
    private string $createdAt;

    public function __construct(
        string $departureCity,
        string $arrivalCity,
        string $departureCountry = 'Canada',
        string $arrivalCountry = 'Canada',
        int $searchCount = 1,
        ?int $id = null,
        ?string $lastSearched = null,
        ?string $createdAt = null
    ) {
        $this->departureCity = $departureCity;
        $this->departureCountry = $departureCountry;
        $this->arrivalCity = $arrivalCity;
        $this->arrivalCountry = $arrivalCountry;
        $this->searchCount = $searchCount;
        $this->id = $id;
        $this->lastSearched = $lastSearched ?? date('Y-m-d H:i:s');
        $this->createdAt = $createdAt ?? date('Y-m-d H:i:s');
    }

    public static function fromArray(array $data): self
    {
        return new self(
            $data['departure_city'],
            $data['arrival_city'],
            $data['departure_country'] ?? 'Canada',
            $data['arrival_country'] ?? 'Canada',
            (int) ($data['search_count'] ?? 1),
            isset($data['id']) ? (int) $data['id'] : null,
            $data['last_searched'] ?? null,
            $data['created_at'] ?? null
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'departure_city' => $this->departureCity,
            'departure_country' => $this->departureCountry,
            'arrival_city' => $this->arrivalCity,
            'arrival_country' => $this->arrivalCountry,
            'search_count' => $this->searchCount,
            'last_searched' => $this->lastSearched,
            'created_at' => $this->createdAt,
            'route_display' => $this->getRouteDisplay(),
            'popularity_level' => $this->getPopularityLevel()
        ];
    }

    public function toDbArray(): array
    {
        return [
            'departure_city' => $this->departureCity,
            'departure_country' => $this->departureCountry,
            'arrival_city' => $this->arrivalCity,
            'arrival_country' => $this->arrivalCountry,
            'search_count' => $this->searchCount,
            'last_searched' => $this->lastSearched
        ];
    }

    // Getters
    public function getId(): ?int { return $this->id; }
    public function getDepartureCity(): string { return $this->departureCity; }
    public function getDepartureCountry(): string { return $this->departureCountry; }
    public function getArrivalCity(): string { return $this->arrivalCity; }
    public function getArrivalCountry(): string { return $this->arrivalCountry; }
    public function getSearchCount(): int { return $this->searchCount; }
    public function getLastSearched(): string { return $this->lastSearched; }
    public function getCreatedAt(): string { return $this->createdAt; }

    // Setters
    public function setId(int $id): void { $this->id = $id; }
    public function incrementSearchCount(): void { 
        $this->searchCount++;
        $this->lastSearched = date('Y-m-d H:i:s');
    }

    /**
     * Get formatted route display
     */
    public function getRouteDisplay(): string
    {
        $from = $this->departureCity;
        $to = $this->arrivalCity;
        
        // Add country if different from Canada
        if ($this->departureCountry !== 'Canada') {
            $from .= ', ' . $this->departureCountry;
        }
        if ($this->arrivalCountry !== 'Canada') {
            $to .= ', ' . $this->arrivalCountry;
        }
        
        return $from . ' → ' . $to;
    }

    /**
     * Get popularity level based on search count
     */
    public function getPopularityLevel(): string
    {
        if ($this->searchCount >= 100) return 'très populaire';
        if ($this->searchCount >= 50) return 'populaire';
        if ($this->searchCount >= 20) return 'modéré';
        if ($this->searchCount >= 10) return 'émergent';
        return 'nouveau';
    }

    /**
     * Get popularity score (0-100)
     */
    public function getPopularityScore(): int
    {
        return min(100, $this->searchCount);
    }

    /**
     * Check if this route is considered trending (high recent activity)
     */
    public function isTrending(): bool
    {
        $lastSearchTimestamp = strtotime($this->lastSearched);
        $weekAgo = strtotime('-1 week');
        
        return $lastSearchTimestamp >= $weekAgo && $this->searchCount >= 5;
    }

    /**
     * Get route key for uniqueness
     */
    public function getRouteKey(): string
    {
        return strtolower($this->departureCity . '_' . $this->departureCountry . '_to_' . 
                         $this->arrivalCity . '_' . $this->arrivalCountry);
    }
}