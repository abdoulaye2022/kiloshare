<?php

namespace App\Modules\Trips\Models;

class TransportLimit {
    public const TRANSPORT_TYPES = [
        'flight' => 'Avion',
        'car' => 'Voiture'
    ];

    public const WEIGHT_LIMITS = [
        'flight' => 23.0,    // kg
        'car' => 100.0,      // kg
    ];

    public const BASE_RATES = [
        'flight' => 3.00,    // CAD per kg
        'car' => 1.50,       // CAD per kg
    ];

    public const COMMISSION_RATES = [
        'flight' => 0.15,    // 15%
        'car' => 0.12,       // 12%
    ];

    public const FLEXIBLE_DEPARTURE_ALLOWED = ['car'];
    public const INTERMEDIATE_STOPS_ALLOWED = ['car'];
    public const VEHICLE_INFO_REQUIRED = ['car'];
    public const FLIGHT_INFO_REQUIRED = ['flight'];
    public const TICKET_VALIDATION_SUPPORTED = ['flight', 'train', 'bus'];

    public static function getWeightLimit(string $transportType): float {
        return self::WEIGHT_LIMITS[$transportType] ?? 23.0;
    }

    public static function getBaseRate(string $transportType): float {
        return self::BASE_RATES[$transportType] ?? 2.0;
    }

    public static function getCommissionRate(string $transportType): float {
        return self::COMMISSION_RATES[$transportType] ?? 0.15;
    }

    public static function isFlexibleDepartureAllowed(string $transportType): bool {
        return in_array($transportType, self::FLEXIBLE_DEPARTURE_ALLOWED);
    }

    public static function areIntermediateStopsAllowed(string $transportType): bool {
        return in_array($transportType, self::INTERMEDIATE_STOPS_ALLOWED);
    }

    public static function isVehicleInfoRequired(string $transportType): bool {
        return in_array($transportType, self::VEHICLE_INFO_REQUIRED);
    }

    public static function isFlightInfoRequired(string $transportType): bool {
        return in_array($transportType, self::FLIGHT_INFO_REQUIRED);
    }

    public static function isTicketValidationSupported(string $transportType): bool {
        return in_array($transportType, self::TICKET_VALIDATION_SUPPORTED);
    }

    public static function getTransportLimits(string $transportType): array {
        return [
            'type' => $transportType,
            'name' => self::TRANSPORT_TYPES[$transportType] ?? 'Inconnu',
            'max_weight_kg' => self::getWeightLimit($transportType),
            'base_rate_per_kg' => self::getBaseRate($transportType),
            'commission_rate' => self::getCommissionRate($transportType),
            'features' => [
                'flexible_departure' => self::isFlexibleDepartureAllowed($transportType),
                'intermediate_stops' => self::areIntermediateStopsAllowed($transportType),
                'vehicle_info_required' => self::isVehicleInfoRequired($transportType),
                'flight_info_required' => self::isFlightInfoRequired($transportType),
                'ticket_validation_supported' => self::isTicketValidationSupported($transportType),
            ]
        ];
    }

    public static function getAllTransportLimits(): array {
        $limits = [];
        foreach (self::TRANSPORT_TYPES as $type => $name) {
            $limits[] = self::getTransportLimits($type);
        }
        return $limits;
    }
}