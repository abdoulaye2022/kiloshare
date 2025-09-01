<?php

namespace App\Modules\Trips\Services;

use App\Modules\Trips\Models\TransportLimit;

class MultiTransportPricingService {
    private array $distanceCache = [];
    
    // Distances approximatives entre villes majeures du Canada Atlantique (km)
    private const CITY_DISTANCES = [
        'Halifax-Moncton' => 270,
        'Halifax-Saint John' => 350,
        'Halifax-Fredericton' => 420,
        'Halifax-Charlottetown' => 280,
        'Halifax-Sydney' => 400,
        'Halifax-St. John\'s' => 1100, // via ferry
        'Moncton-Saint John' => 150,
        'Moncton-Fredericton' => 180,
        'Moncton-Charlottetown' => 95,
        'Saint John-Fredericton' => 110,
        'Montreal-Halifax' => 1300,
        'Montreal-Moncton' => 1050,
        'Toronto-Halifax' => 1800,
        'Toronto-Moncton' => 1550,
        'Quebec-Halifax' => 950,
        'Quebec-Moncton' => 700,
    ];

    public function calculateDistance(string $fromCity, string $toCity): int {
        $key = $fromCity . '-' . $toCity;
        $reverseKey = $toCity . '-' . $fromCity;
        
        // Check cache first
        if (isset($this->distanceCache[$key])) {
            return $this->distanceCache[$key];
        }
        
        // Check predefined distances
        if (isset(self::CITY_DISTANCES[$key])) {
            $distance = self::CITY_DISTANCES[$key];
        } elseif (isset(self::CITY_DISTANCES[$reverseKey])) {
            $distance = self::CITY_DISTANCES[$reverseKey];
        } else {
            // Default estimation for unknown routes
            $distance = $this->estimateDistance($fromCity, $toCity);
        }
        
        // Cache the result
        $this->distanceCache[$key] = $distance;
        $this->distanceCache[$reverseKey] = $distance;
        
        return $distance;
    }

    private function estimateDistance(string $fromCity, string $toCity): int {
        // Simple estimation logic - in real app, use geocoding API
        $longDistanceCities = ['Toronto', 'Montreal', 'Quebec', 'Ottawa'];
        $atlanticCities = ['Halifax', 'Moncton', 'Saint John', 'Fredericton', 'Sydney', 'Charlottetown'];
        
        $fromIsLongDistance = in_array($fromCity, $longDistanceCities);
        $toIsLongDistance = in_array($toCity, $longDistanceCities);
        $fromIsAtlantic = in_array($fromCity, $atlanticCities);
        $toIsAtlantic = in_array($toCity, $atlanticCities);
        
        if ($fromIsLongDistance && $toIsAtlantic) {
            return 1200; // Average long distance
        } elseif ($fromIsAtlantic && $toIsLongDistance) {
            return 1200;
        } elseif ($fromIsAtlantic && $toIsAtlantic) {
            return 300; // Average Atlantic Canada distance
        } else {
            return 500; // Default medium distance
        }
    }

    public function calculateSuggestedPrice(
        string $transportType,
        string $fromCity,
        string $toCity,
        float $weightKg,
        string $currency = 'CAD'
    ): array {
        $distance = $this->calculateDistance($fromCity, $toCity);
        $baseRate = TransportLimit::getBaseRate($transportType);
        $weightLimit = TransportLimit::getWeightLimit($transportType);
        $commissionRate = TransportLimit::getCommissionRate($transportType);
        
        // Apply weight validation
        if ($weightKg > $weightLimit) {
            throw new \InvalidArgumentException(
                "Le poids de {$weightKg}kg dépasse la limite de {$weightLimit}kg pour le transport " . 
                TransportLimit::TRANSPORT_TYPES[$transportType]
            );
        }
        
        // Base price per kg
        $pricePerKg = $baseRate;
        
        // Distance adjustments
        if ($distance > 1000) {
            $pricePerKg *= 1.3; // Long distance premium
        } elseif ($distance < 200) {
            $pricePerKg *= 0.8; // Short distance discount
        }
        
        // Transport-specific adjustments
        switch ($transportType) {
            case 'car':
                if ($distance > 500) {
                    $pricePerKg *= 0.8; // Car long distance discount
                }
                break;
            case 'flight':
                if ($distance < 300) {
                    $pricePerKg *= 1.2; // Short flight premium
                }
                break;
        }
        
        // Round to reasonable price
        $pricePerKg = round($pricePerKg, 2);
        
        // Calculate totals
        $totalPrice = $pricePerKg * $weightKg;
        $commission = $totalPrice * $commissionRate;
        $netEarnings = $totalPrice - $commission;
        
        // Convert currency if needed
        $exchangeRate = $this->getExchangeRate($currency);
        
        return [
            'suggested_price_per_kg' => round($pricePerKg * $exchangeRate, 2),
            'total_price' => round($totalPrice * $exchangeRate, 2),
            'commission' => round($commission * $exchangeRate, 2),
            'net_earnings' => round($netEarnings * $exchangeRate, 2),
            'currency' => $currency,
            'transport_type' => $transportType,
            'distance_km' => $distance,
            'weight_kg' => $weightKg,
            'base_rate' => $baseRate,
            'commission_rate' => $commissionRate,
            'explanation' => $this->generatePriceExplanation(
                $transportType, 
                $distance, 
                $baseRate, 
                $pricePerKg
            )
        ];
    }

    private function generatePriceExplanation(
        string $transportType, 
        int $distance, 
        float $baseRate, 
        float $finalRate
    ): string {
        $transportName = TransportLimit::TRANSPORT_TYPES[$transportType];
        $explanation = "Tarif de base {$transportName}: {$baseRate} CAD/kg";
        
        if ($distance > 1000) {
            $explanation .= " • Majoration longue distance (+30%)";
        } elseif ($distance < 200) {
            $explanation .= " • Réduction courte distance (-20%)";
        }
        
        switch ($transportType) {
            case 'car':
                if ($distance > 500) {
                    $explanation .= " • Réduction voiture longue distance (-20%)";
                }
                break;
            case 'flight':
                if ($distance < 300) {
                    $explanation .= " • Majoration vol court (+20%)";
                }
                break;
        }
        
        return $explanation;
    }

    private function getExchangeRate(string $currency): float {
        // Simplified exchange rates - in production, use real API
        $rates = [
            'CAD' => 1.0,
            'USD' => 0.74,
            'EUR' => 0.68
        ];
        
        return $rates[$currency] ?? 1.0;
    }

    public function getTransportRecommendation(
        string $fromCity, 
        string $toCity, 
        float $weightKg
    ): array {
        $distance = $this->calculateDistance($fromCity, $toCity);
        $recommendations = [];
        
        foreach (TransportLimit::TRANSPORT_TYPES as $type => $name) {
            if ($weightKg <= TransportLimit::getWeightLimit($type)) {
                $pricing = $this->calculateSuggestedPrice($type, $fromCity, $toCity, $weightKg);
                
                $recommendations[] = [
                    'transport_type' => $type,
                    'name' => $name,
                    'price_per_kg' => $pricing['suggested_price_per_kg'],
                    'total_price' => $pricing['total_price'],
                    'net_earnings' => $pricing['net_earnings'],
                    'suitability_score' => $this->calculateSuitabilityScore($type, $distance, $weightKg),
                    'pros' => $this->getTransportPros($type, $distance),
                    'cons' => $this->getTransportCons($type, $distance)
                ];
            }
        }
        
        // Sort by suitability score
        usort($recommendations, function($a, $b) {
            return $b['suitability_score'] <=> $a['suitability_score'];
        });
        
        return $recommendations;
    }

    private function calculateSuitabilityScore(string $type, int $distance, float $weight): int {
        $score = 50; // Base score
        
        switch ($type) {
            case 'flight':
                if ($distance > 800) $score += 30;
                if ($distance < 300) $score -= 20;
                if ($weight > 15) $score -= 10;
                break;
            case 'car':
                if ($distance > 200 && $distance < 1000) $score += 25;
                if ($weight > 30) $score += 20;
                $score += 15; // Flexibility bonus
                break;
        }
        
        return max(0, min(100, $score));
    }

    private function getTransportPros(string $type, int $distance): array {
        $pros = [];
        
        switch ($type) {
            case 'flight':
                $pros[] = 'Rapide';
                $pros[] = 'Sécurisé';
                if ($distance > 800) $pros[] = 'Idéal longue distance';
                break;
            case 'car':
                $pros[] = 'Flexible';
                $pros[] = 'Grande capacité';
                $pros[] = 'Arrêts multiples possibles';
                $pros[] = 'Porte à porte';
                break;
        }
        
        return $pros;
    }

    private function getTransportCons(string $type, int $distance): array {
        $cons = [];
        
        switch ($type) {
            case 'flight':
                $cons[] = 'Limites de poids strictes';
                $cons[] = 'Horaires fixes';
                if ($distance < 300) $cons[] = 'Peu économique courte distance';
                break;
            case 'car':
                $cons[] = 'Dépendant du trafic';
                $cons[] = 'Émissions CO2';
                break;
        }
        
        return $cons;
    }
}