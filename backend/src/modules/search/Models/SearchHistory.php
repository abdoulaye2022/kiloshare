<?php

namespace App\Modules\Search\Models;

class SearchHistory
{
    private ?int $id;
    private int $userId;
    private array $searchParams;
    private string $searchedAt;

    public function __construct(
        int $userId,
        array $searchParams,
        ?int $id = null,
        ?string $searchedAt = null
    ) {
        $this->userId = $userId;
        $this->searchParams = $searchParams;
        $this->id = $id;
        $this->searchedAt = $searchedAt ?? date('Y-m-d H:i:s');
    }

    public static function fromArray(array $data): self
    {
        return new self(
            (int) $data['user_id'],
            json_decode($data['search_params_json'], true) ?? [],
            isset($data['id']) ? (int) $data['id'] : null,
            $data['searched_at'] ?? null
        );
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->userId,
            'search_params' => $this->searchParams,
            'searched_at' => $this->searchedAt
        ];
    }

    public function toDbArray(): array
    {
        return [
            'user_id' => $this->userId,
            'search_params_json' => json_encode($this->searchParams),
            'searched_at' => $this->searchedAt
        ];
    }

    // Getters
    public function getId(): ?int { return $this->id; }
    public function getUserId(): int { return $this->userId; }
    public function getSearchParams(): array { return $this->searchParams; }
    public function getSearchedAt(): string { return $this->searchedAt; }

    // Setters
    public function setId(int $id): void { $this->id = $id; }

    /**
     * Get a human-readable summary of the search
     */
    public function getSearchSummary(): string
    {
        $params = $this->searchParams;
        
        $summary = [];
        
        if (!empty($params['departure_city']) && !empty($params['arrival_city'])) {
            $summary[] = $params['departure_city'] . ' → ' . $params['arrival_city'];
        }
        
        if (!empty($params['departure_date'])) {
            $summary[] = 'Départ: ' . date('d/m/Y', strtotime($params['departure_date']));
        }
        
        if (!empty($params['max_price'])) {
            $summary[] = 'Max: ' . $params['max_price'] . ' ' . ($params['currency'] ?? 'CAD');
        }
        
        if (!empty($params['transport_type'])) {
            $types = [
                'plane' => '✈️',
                'car' => '🚗',
                'bus' => '🚌',
                'train' => '🚆'
            ];
            $summary[] = $types[$params['transport_type']] ?? $params['transport_type'];
        }
        
        return implode(' • ', $summary);
    }

    /**
     * Check if this search matches another search (for duplicate detection)
     */
    public function isSimilarTo(SearchHistory $other): bool
    {
        $params1 = $this->searchParams;
        $params2 = $other->getSearchParams();
        
        // Check key parameters for similarity
        return (
            ($params1['departure_city'] ?? '') === ($params2['departure_city'] ?? '') &&
            ($params1['arrival_city'] ?? '') === ($params2['arrival_city'] ?? '') &&
            ($params1['departure_date'] ?? '') === ($params2['departure_date'] ?? '') &&
            ($params1['transport_type'] ?? '') === ($params2['transport_type'] ?? '')
        );
    }
}