<?php

namespace App\Modules\Trips\Services;

use PDO;

class PriceCalculatorService
{
    private PDO $db;
    private const COMMISSION_RATE = 15.0; // 15% commission
    
    // Base rates par km (en EUR)
    private const BASE_RATE_SHORT_HAUL = 0.015; // < 1000km
    private const BASE_RATE_MEDIUM_HAUL = 0.012; // 1000-3000km  
    private const BASE_RATE_LONG_HAUL = 0.008; // > 3000km
    
    // Currency exchange rates (base EUR)
    private array $exchangeRates = [
        'EUR' => 1.0,
        'CAD' => 1.47,
        'USD' => 1.09
    ];

    public function __construct(PDO $db)
    {
        $this->db = $db;
    }

    /**
     * Calculate suggested price per kg for a route
     */
    public function calculateSuggestedPrice(
        string $departureCity,
        string $departureCountry, 
        string $arrivalCity,
        string $arrivalCountry,
        string $currency = 'EUR'
    ): array {
        // Check cache first
        $cached = $this->getCachedPrice($departureCity, $departureCountry, $arrivalCity, $arrivalCountry);
        if ($cached) {
            return $this->convertCurrency($cached, $currency);
        }
        
        // Calculate distance
        $distance = $this->calculateDistance($departureCity, $departureCountry, $arrivalCity, $arrivalCountry);
        
        // Determine base rate based on distance
        $baseRate = $this->getBaseRateForDistance($distance);
        
        // Calculate base price per kg
        $basePricePerKg = $distance * $baseRate / 1000; // Convert to reasonable price range
        
        // Apply market adjustments
        $basePricePerKg = $this->applyMarketAdjustments($basePricePerKg, $departureCity, $arrivalCity);
        
        // Add commission
        $suggestedPrice = $basePricePerKg * (1 + self::COMMISSION_RATE / 100);
        
        // Round to reasonable precision
        $suggestedPrice = round($suggestedPrice, 2);
        
        $result = [
            'distance_km' => $distance,
            'base_price_per_kg' => $basePricePerKg,
            'commission_rate' => self::COMMISSION_RATE,
            'suggested_price_per_kg' => $suggestedPrice,
            'currency' => 'EUR',
            'exchange_rates' => $this->exchangeRates
        ];
        
        // Cache the result
        $this->cachePrice($departureCity, $departureCountry, $arrivalCity, $arrivalCountry, $result);
        
        return $this->convertCurrency($result, $currency);
    }

    /**
     * Calculate commission for a booking
     */
    public function calculateCommission(float $totalAmount, ?float $commissionRate = null): float
    {
        $rate = $commissionRate ?? self::COMMISSION_RATE;
        return round($totalAmount * ($rate / 100), 2);
    }

    /**
     * Get price breakdown for display
     */
    public function getPriceBreakdown(float $pricePerKg, float $weightKg, string $currency = 'EUR'): array
    {
        $subtotal = $pricePerKg * $weightKg;
        $commission = $this->calculateCommission($subtotal);
        $carrierEarnings = $subtotal - $commission;
        
        return [
            'price_per_kg' => $pricePerKg,
            'weight_kg' => $weightKg,
            'subtotal' => round($subtotal, 2),
            'commission' => $commission,
            'commission_rate' => self::COMMISSION_RATE,
            'carrier_earnings' => round($carrierEarnings, 2),
            'currency' => $currency
        ];
    }

    /**
     * Calculate distance between two cities (simplified)
     */
    private function calculateDistance(string $departureCity, string $departureCountry, string $arrivalCity, string $arrivalCountry): int
    {
        // Simplified distance calculation based on city pairs
        // In production, this would use actual geographic coordinates
        $routes = [
            // Intra-Europe
            'Paris_France_London_UK' => 344,
            'Paris_France_Barcelona_Spain' => 831,
            'Paris_France_Rome_Italy' => 1105,
            'London_UK_Barcelona_Spain' => 1137,
            'London_UK_Rome_Italy' => 1434,
            'Barcelona_Spain_Rome_Italy' => 857,
            
            // Europe-North America
            'Paris_France_Montreal_Canada' => 5511,
            'Paris_France_Toronto_Canada' => 6196,
            'Paris_France_New York_USA' => 5837,
            'London_UK_Montreal_Canada' => 5226,
            'London_UK_Toronto_Canada' => 5719,
            'London_UK_New York_USA' => 5585,
            
            // Europe-Africa
            'Paris_France_Dakar_Senegal' => 4128,
            'Paris_France_Casablanca_Morocco' => 1759,
            'London_UK_Dakar_Senegal' => 4400,
            'London_UK_Casablanca_Morocco' => 1814,
            
            // Default estimates
            'default_short' => 500,
            'default_medium' => 1500,
            'default_long' => 5000
        ];
        
        $routeKey = $departureCity . '_' . $departureCountry . '_' . $arrivalCity . '_' . $arrivalCountry;
        $reverseRouteKey = $arrivalCity . '_' . $arrivalCountry . '_' . $departureCity . '_' . $departureCountry;
        
        if (isset($routes[$routeKey])) {
            return $routes[$routeKey];
        }
        
        if (isset($routes[$reverseRouteKey])) {
            return $routes[$reverseRouteKey];
        }
        
        // Estimate based on countries
        if ($departureCountry === $arrivalCountry) {
            return $routes['default_short'];
        }
        
        $europeanCountries = ['France', 'UK', 'Spain', 'Italy', 'Germany', 'Netherlands', 'Belgium', 'Switzerland'];
        $northAmericanCountries = ['Canada', 'USA'];
        $africanCountries = ['Senegal', 'Morocco', 'Algeria', 'Tunisia'];
        
        $depInEurope = in_array($departureCountry, $europeanCountries);
        $arrInEurope = in_array($arrivalCountry, $europeanCountries);
        $depInNorthAmerica = in_array($departureCountry, $northAmericanCountries);
        $arrInNorthAmerica = in_array($arrivalCountry, $northAmericanCountries);
        $depInAfrica = in_array($departureCountry, $africanCountries);
        $arrInAfrica = in_array($arrivalCountry, $africanCountries);
        
        // Same continent
        if (($depInEurope && $arrInEurope) || ($depInNorthAmerica && $arrInNorthAmerica) || ($depInAfrica && $arrInAfrica)) {
            return $routes['default_medium'];
        }
        
        // Different continents
        return $routes['default_long'];
    }

    /**
     * Get base rate based on distance
     */
    private function getBaseRateForDistance(int $distance): float
    {
        if ($distance < 1000) {
            return self::BASE_RATE_SHORT_HAUL;
        } elseif ($distance < 3000) {
            return self::BASE_RATE_MEDIUM_HAUL;
        } else {
            return self::BASE_RATE_LONG_HAUL;
        }
    }

    /**
     * Apply market adjustments based on popular routes
     */
    private function applyMarketAdjustments(float $basePrice, string $departureCity, string $arrivalCity): float
    {
        // Popular routes get slight price increase
        $popularRoutes = [
            'Paris_London' => 1.1,
            'Paris_Barcelona' => 1.05,
            'London_Barcelona' => 1.05,
            'Paris_Montreal' => 1.15,
            'Paris_New York' => 1.15,
            'London_Toronto' => 1.1
        ];
        
        $routeKey = $departureCity . '_' . $arrivalCity;
        $reverseRouteKey = $arrivalCity . '_' . $departureCity;
        
        $multiplier = $popularRoutes[$routeKey] ?? $popularRoutes[$reverseRouteKey] ?? 1.0;
        
        return $basePrice * $multiplier;
    }

    /**
     * Convert price to different currency
     */
    private function convertCurrency(array $priceData, string $targetCurrency): array
    {
        if ($targetCurrency === 'EUR' || $targetCurrency === $priceData['currency']) {
            return $priceData;
        }
        
        $rate = $this->exchangeRates[$targetCurrency] ?? 1.0;
        
        $priceData['base_price_per_kg'] = round($priceData['base_price_per_kg'] * $rate, 2);
        $priceData['suggested_price_per_kg'] = round($priceData['suggested_price_per_kg'] * $rate, 2);
        $priceData['currency'] = $targetCurrency;
        
        return $priceData;
    }

    /**
     * Get cached price calculation
     */
    private function getCachedPrice(string $departureCity, string $departureCountry, string $arrivalCity, string $arrivalCountry): ?array
    {
        try {
            $stmt = $this->db->prepare("
                SELECT * FROM trip_price_calculations 
                WHERE departure_city = ? AND departure_country = ? 
                  AND arrival_city = ? AND arrival_country = ?
                  AND expires_at > NOW()
                ORDER BY calculated_at DESC 
                LIMIT 1
            ");
            
            $stmt->execute([$departureCity, $departureCountry, $arrivalCity, $arrivalCountry]);
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($result) {
                return [
                    'distance_km' => (int) $result['distance_km'],
                    'base_price_per_kg' => (float) $result['base_price_per_kg'],
                    'commission_rate' => (float) $result['commission_rate'],
                    'suggested_price_per_kg' => (float) $result['suggested_price_per_kg'],
                    'currency' => $result['base_currency'],
                    'exchange_rates' => json_decode($result['exchange_rates'], true) ?? $this->exchangeRates
                ];
            }
        } catch (\Exception $e) {
            // Log error but don't fail
            error_log("Price cache lookup failed: " . $e->getMessage());
        }
        
        return null;
    }

    /**
     * Cache price calculation
     */
    private function cachePrice(string $departureCity, string $departureCountry, string $arrivalCity, string $arrivalCountry, array $priceData): void
    {
        try {
            $stmt = $this->db->prepare("
                INSERT INTO trip_price_calculations (
                    departure_city, departure_country, arrival_city, arrival_country,
                    distance_km, base_price_per_kg, commission_rate, suggested_price_per_kg,
                    base_currency, exchange_rates, expires_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR))
            ");
            
            $stmt->execute([
                $departureCity,
                $departureCountry,
                $arrivalCity,
                $arrivalCountry,
                $priceData['distance_km'],
                $priceData['base_price_per_kg'],
                $priceData['commission_rate'],
                $priceData['suggested_price_per_kg'],
                $priceData['currency'],
                json_encode($priceData['exchange_rates'])
            ]);
        } catch (\Exception $e) {
            // Log error but don't fail
            error_log("Price cache save failed: " . $e->getMessage());
        }
    }

    /**
     * Update exchange rates (called by cron job)
     */
    public function updateExchangeRates(): bool
    {
        // In production, this would fetch from an external API
        // For now, we'll use static rates
        
        try {
            // Simulate fetching from external API
            $newRates = [
                'EUR' => 1.0,
                'CAD' => 1.47 + (rand(-5, 5) / 100), // Slight variation
                'USD' => 1.09 + (rand(-3, 3) / 100)
            ];
            
            $this->exchangeRates = $newRates;
            
            // Clear expired cache entries
            $this->db->exec("DELETE FROM trip_price_calculations WHERE expires_at < NOW()");
            
            return true;
        } catch (\Exception $e) {
            error_log("Exchange rate update failed: " . $e->getMessage());
            return false;
        }
    }
}