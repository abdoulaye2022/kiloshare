<?php

namespace App\Modules\Trips\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Modules\Trips\Models\TransportLimit;
use App\Modules\Trips\Services\MultiTransportPricingService;
use App\Modules\Trips\Services\TripService;
use Psr\Log\LoggerInterface;

class MultiTransportTripController {
    private MultiTransportPricingService $pricingService;
    private TripService $tripService;
    private LoggerInterface $logger;

    public function __construct(
        MultiTransportPricingService $pricingService,
        TripService $tripService,
        LoggerInterface $logger
    ) {
        $this->pricingService = $pricingService;
        $this->tripService = $tripService;
        $this->logger = $logger;
    }

    /**
     * GET /api/trips/transport-limits/{type}
     */
    public function getTransportLimits(Request $request, Response $response, array $args): Response {
        try {
            $transportType = $args['type'] ?? null;
            
            if ($transportType) {
                if (!array_key_exists($transportType, TransportLimit::TRANSPORT_TYPES)) {
                    return $this->jsonResponse($response, [
                        'success' => false,
                        'message' => 'Type de transport invalide'
                    ], 400);
                }
                
                $limits = TransportLimit::getTransportLimits($transportType);
            } else {
                $limits = TransportLimit::getAllTransportLimits();
            }
            
            return $this->jsonResponse($response, [
                'success' => true,
                'data' => ['limits' => $limits]
            ]);
            
        } catch (\Exception $e) {
            $this->logger->error('Erreur lors de la récupération des limites de transport', [
                'error' => $e->getMessage(),
                'transport_type' => $transportType ?? 'all'
            ]);
            
            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la récupération des limites de transport'
            ], 500);
        }
    }

    /**
     * POST /api/trips/price-suggestion-multi
     */
    public function getPriceSuggestionMulti(Request $request, Response $response): Response {
        try {
            $data = json_decode($request->getBody()->getContents(), true);
            
            $required = ['transport_type', 'departure_city', 'arrival_city', 'weight_kg'];
            foreach ($required as $field) {
                if (!isset($data[$field]) || empty($data[$field])) {
                    return $this->jsonResponse($response, [
                        'success' => false,
                        'message' => "Le champ '$field' est requis"
                    ], 400);
                }
            }
            
            $transportType = $data['transport_type'];
            $departureCity = $data['departure_city'];
            $arrivalCity = $data['arrival_city'];
            $weightKg = floatval($data['weight_kg']);
            $currency = $data['currency'] ?? 'CAD';
            
            // Validate transport type
            if (!array_key_exists($transportType, TransportLimit::TRANSPORT_TYPES)) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Type de transport invalide'
                ], 400);
            }
            
            // Validate weight limit
            $maxWeight = TransportLimit::getWeightLimit($transportType);
            if ($weightKg > $maxWeight) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => "Le poids de {$weightKg}kg dépasse la limite de {$maxWeight}kg pour " . 
                               TransportLimit::TRANSPORT_TYPES[$transportType]
                ], 400);
            }
            
            $suggestion = $this->pricingService->calculateSuggestedPrice(
                $transportType,
                $departureCity,
                $arrivalCity,
                $weightKg,
                $currency
            );
            
            return $this->jsonResponse($response, [
                'success' => true,
                'data' => ['price_suggestion' => $suggestion]
            ]);
            
        } catch (\InvalidArgumentException $e) {
            return $this->jsonResponse($response, [
                'success' => false,
                'message' => $e->getMessage()
            ], 400);
            
        } catch (\Exception $e) {
            $this->logger->error('Erreur lors du calcul du prix suggéré multi-transport', [
                'error' => $e->getMessage(),
                'data' => $data ?? []
            ]);
            
            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors du calcul du prix suggéré'
            ], 500);
        }
    }

    /**
     * POST /api/trips/transport-recommendations
     */
    public function getTransportRecommendations(Request $request, Response $response): Response {
        try {
            $data = json_decode($request->getBody()->getContents(), true);
            
            $required = ['departure_city', 'arrival_city', 'weight_kg'];
            foreach ($required as $field) {
                if (!isset($data[$field]) || empty($data[$field])) {
                    return $this->jsonResponse($response, [
                        'success' => false,
                        'message' => "Le champ '$field' est requis"
                    ], 400);
                }
            }
            
            $departureCity = $data['departure_city'];
            $arrivalCity = $data['arrival_city'];
            $weightKg = floatval($data['weight_kg']);
            
            $recommendations = $this->pricingService->getTransportRecommendation(
                $departureCity,
                $arrivalCity,
                $weightKg
            );
            
            return $this->jsonResponse($response, [
                'success' => true,
                'data' => ['recommendations' => $recommendations]
            ]);
            
        } catch (\Exception $e) {
            $this->logger->error('Erreur lors de la génération des recommandations de transport', [
                'error' => $e->getMessage(),
                'data' => $data ?? []
            ]);
            
            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la génération des recommandations'
            ], 500);
        }
    }

    /**
     * POST /api/trips/{id}/validate-vehicle
     */
    public function validateVehicle(Request $request, Response $response, array $args): Response {
        try {
            $tripId = $args['id'];
            $data = json_decode($request->getBody()->getContents(), true);
            
            $required = ['make', 'model', 'license_plate'];
            foreach ($required as $field) {
                if (!isset($data[$field]) || empty($data[$field])) {
                    return $this->jsonResponse($response, [
                        'success' => false,
                        'message' => "Le champ '$field' est requis pour la validation du véhicule"
                    ], 400);
                }
            }
            
            // Get trip to verify it's a car transport
            $trip = $this->tripService->getTripById($tripId);
            if (!$trip || $trip['transport_type'] !== 'car') {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Validation véhicule disponible uniquement pour les voyages en voiture'
                ], 400);
            }
            
            // Update trip with vehicle info
            $updateData = [
                'vehicle_make' => $data['make'],
                'vehicle_model' => $data['model'],
                'license_plate' => $data['license_plate'],
                'vehicle_year' => $data['year'] ?? null,
                'vehicle_color' => $data['color'] ?? null,
                'vehicle_verified' => true,
                'vehicle_verification_date' => date('Y-m-d H:i:s')
            ];
            
            $updatedTrip = $this->tripService->updateTrip($tripId, $updateData);
            
            return $this->jsonResponse($response, [
                'success' => true,
                'message' => 'Véhicule validé avec succès',
                'data' => ['trip' => $updatedTrip]
            ]);
            
        } catch (\Exception $e) {
            $this->logger->error('Erreur lors de la validation du véhicule', [
                'error' => $e->getMessage(),
                'trip_id' => $tripId ?? null,
                'data' => $data ?? []
            ]);
            
            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la validation du véhicule'
            ], 500);
        }
    }

    /**
     * GET /api/trips/list-by-transport/{type}
     */
    public function listTripsByTransport(Request $request, Response $response, array $args): Response {
        try {
            $transportType = $args['type'] ?? null;
            $queryParams = $request->getQueryParams();
            
            if ($transportType && !array_key_exists($transportType, TransportLimit::TRANSPORT_TYPES)) {
                return $this->jsonResponse($response, [
                    'success' => false,
                    'message' => 'Type de transport invalide'
                ], 400);
            }
            
            $filters = [
                'transport_type' => $transportType,
                'status' => $queryParams['status'] ?? null,
                'page' => intval($queryParams['page'] ?? 1),
                'limit' => intval($queryParams['limit'] ?? 20)
            ];
            
            $trips = $this->tripService->searchTrips($filters);
            
            return $this->jsonResponse($response, [
                'success' => true,
                'data' => ['trips' => $trips]
            ]);
            
        } catch (\Exception $e) {
            $this->logger->error('Erreur lors de la récupération des voyages par transport', [
                'error' => $e->getMessage(),
                'transport_type' => $transportType ?? 'all',
                'filters' => $filters ?? []
            ]);
            
            return $this->jsonResponse($response, [
                'success' => false,
                'message' => 'Erreur lors de la récupération des voyages'
            ], 500);
        }
    }

    private function jsonResponse(Response $response, array $data, int $status = 200): Response {
        $response->getBody()->write(json_encode($data));
        return $response->withHeader('Content-Type', 'application/json')->withStatus($status);
    }
}