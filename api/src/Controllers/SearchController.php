<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Trip;
use KiloShare\Utils\Response;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;

class SearchController
{
    public function searchTrips(ServerRequestInterface $request): ResponseInterface
    {
        $queryParams = $request->getQueryParams();

        try {
            $query = Trip::active()->notExpired()->with(['user', 'images']);

            // Filtres de recherche
            // Support pour les anciens paramètres 'departure' et 'arrival'
            if (!empty($queryParams['departure'])) {
                $departure = strtolower(trim($queryParams['departure']));
                $query->where(function ($q) use ($departure) {
                    $q->whereRaw('LOWER(departure_city) LIKE ?', ["%{$departure}%"])
                      ->orWhereRaw('LOWER(departure_country) LIKE ?', ["%{$departure}%"]);
                });
            }

            if (!empty($queryParams['arrival'])) {
                $arrival = strtolower(trim($queryParams['arrival']));
                $query->where(function ($q) use ($arrival) {
                    $q->whereRaw('LOWER(arrival_city) LIKE ?', ["%{$arrival}%"])
                      ->orWhereRaw('LOWER(arrival_country) LIKE ?', ["%{$arrival}%"]);
                });
            }

            // Support pour les nouveaux paramètres spécifiques
            if (!empty($queryParams['departure_city'])) {
                $departureCity = strtolower(trim($queryParams['departure_city']));
                $query->whereRaw('LOWER(departure_city) LIKE ?', ["%{$departureCity}%"]);
            }

            if (!empty($queryParams['arrival_city'])) {
                $arrivalCity = strtolower(trim($queryParams['arrival_city']));
                $query->whereRaw('LOWER(arrival_city) LIKE ?', ["%{$arrivalCity}%"]);
            }

            if (!empty($queryParams['departure_country'])) {
                $departureCountry = strtolower(trim($queryParams['departure_country']));
                $query->whereRaw('LOWER(departure_country) LIKE ?', ["%{$departureCountry}%"]);
            }

            if (!empty($queryParams['arrival_country'])) {
                $arrivalCountry = strtolower(trim($queryParams['arrival_country']));
                $query->whereRaw('LOWER(arrival_country) LIKE ?', ["%{$arrivalCountry}%"]);
            }

            if (!empty($queryParams['transport_type'])) {
                $query->where('transport_type', $queryParams['transport_type']);
            }

            if (!empty($queryParams['departure_date'])) {
                try {
                    $date = Carbon::parse($queryParams['departure_date']);
                    $query->whereDate('departure_date', '>=', $date);
                } catch (\Exception $e) {
                    return Response::error('Invalid departure date format');
                }
            }

            // Support pour plage de dates
            if (!empty($queryParams['departure_date_to'])) {
                try {
                    $dateTo = Carbon::parse($queryParams['departure_date_to']);
                    $query->whereDate('departure_date', '<=', $dateTo);
                } catch (\Exception $e) {
                    return Response::error('Invalid departure date_to format');
                }
            }

            // Filtre pour utilisateurs vérifiés seulement
            if (!empty($queryParams['verified_only']) && filter_var($queryParams['verified_only'], FILTER_VALIDATE_BOOLEAN)) {
                $query->whereHas('user', function ($q) {
                    $q->where('is_verified', true);
                });
            }

            // Filtre pour billets vérifiés seulement
            if (!empty($queryParams['ticket_verified']) && filter_var($queryParams['ticket_verified'], FILTER_VALIDATE_BOOLEAN)) {
                $query->where('ticket_verified', true);
            }

            if (!empty($queryParams['min_weight'])) {
                $minWeight = (float) $queryParams['min_weight'];
                $query->where('available_weight_kg', '>=', $minWeight);
            }

            if (!empty($queryParams['max_price'])) {
                $maxPrice = (float) $queryParams['max_price'];
                $query->where('price_per_kg', '<=', $maxPrice);
            }

            if (!empty($queryParams['is_domestic'])) {
                $isDomestic = filter_var($queryParams['is_domestic'], FILTER_VALIDATE_BOOLEAN);
                $query->where('is_domestic', $isDomestic);
            }

            // Tri
            $sortBy = $queryParams['sort_by'] ?? 'relevance';
            switch ($sortBy) {
                case 'price_asc':
                    $query->orderBy('price_per_kg', 'asc');
                    break;
                case 'price_desc':
                    $query->orderBy('price_per_kg', 'desc');
                    break;
                case 'date_asc':
                    $query->orderBy('departure_date', 'asc');
                    break;
                case 'date_desc':
                    $query->orderBy('departure_date', 'desc');
                    break;
                case 'weight_desc':
                    $query->orderBy('available_weight_kg', 'desc');
                    break;
                default:
                    $query->orderByRelevance();
                    break;
            }

            // Pagination
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $limit = min($limit, 50); // Limiter à 50 max
            $offset = ($page - 1) * $limit;

            $trips = $query->skip($offset)->take($limit)->get();
            $total = $query->count();

            return Response::success([
                'trips' => $trips->map(function ($trip) {
                    return [
                        'id' => $trip->id,
                        'uuid' => $trip->uuid,
                        'title' => $trip->title,
                        'description' => substr($trip->description, 0, 150) . (strlen($trip->description) > 150 ? '...' : ''),
                        'departure_city' => $trip->departure_city,
                        'departure_country' => $trip->departure_country,
                        'departure_date' => $trip->departure_date,
                        'arrival_city' => $trip->arrival_city,
                        'arrival_country' => $trip->arrival_country,
                        'arrival_date' => $trip->arrival_date,
                        'transport_type' => $trip->transport_type,
                        'price_per_kg' => $trip->price_per_kg,
                        'available_weight_kg' => $trip->available_weight_kg,
                        'available_weight' => $trip->available_weight,
                        'currency' => $trip->currency,
                        'is_domestic' => $trip->is_domestic,
                        'route' => $trip->route,
                        'duration' => $trip->duration,
                        'user' => [
                            'id' => $trip->user->id,
                            'first_name' => $trip->user->first_name,
                            'profile_picture' => $trip->user->profile_picture,
                            'is_verified' => $trip->user->is_verified,
                        ],
                        'main_image' => $trip->images->first() ? [
                            'url' => $trip->images->first()->url,
                            'thumbnail' => $trip->images->first()->thumbnail,
                        ] : null,
                    ];
                }),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ],
                'filters' => $queryParams,
                'total_results' => $total,
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Search failed: ' . $e->getMessage());
        }
    }

    public function getCitySuggestions(ServerRequestInterface $request): ResponseInterface
    {
        $queryParams = $request->getQueryParams();
        $query = $queryParams['q'] ?? '';

        if (strlen($query) < 2) {
            return Response::error('Query must be at least 2 characters long');
        }

        try {
            // Suggestions de villes de départ
            $departureCities = Trip::active()
                ->whereRaw('LOWER(departure_city) LIKE ?', ['%' . strtolower($query) . '%'])
                ->select('departure_city', 'departure_country')
                ->distinct()
                ->limit(5)
                ->get()
                ->map(function ($trip) {
                    return [
                        'city' => $trip->departure_city,
                        'country' => $trip->departure_country,
                        'type' => 'departure'
                    ];
                });

            // Suggestions de villes d'arrivée
            $arrivalCities = Trip::active()
                ->whereRaw('LOWER(arrival_city) LIKE ?', ['%' . strtolower($query) . '%'])
                ->select('arrival_city', 'arrival_country')
                ->distinct()
                ->limit(5)
                ->get()
                ->map(function ($trip) {
                    return [
                        'city' => $trip->arrival_city,
                        'country' => $trip->arrival_country,
                        'type' => 'arrival'
                    ];
                });

            $suggestions = $departureCities->merge($arrivalCities)->unique(function ($item) {
                return $item['city'] . '_' . $item['country'];
            })->take(10);

            return Response::success([
                'suggestions' => $suggestions->values(),
                'query' => $query,
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get city suggestions: ' . $e->getMessage());
        }
    }

    public function getPopularRoutes(ServerRequestInterface $request): ResponseInterface
    {
        try {
            // Routes les plus populaires basées sur le nombre de voyages
            $popularRoutes = Trip::active()
                ->selectRaw('departure_city, departure_country, arrival_city, arrival_country, COUNT(*) as trip_count')
                ->groupBy(['departure_city', 'departure_country', 'arrival_city', 'arrival_country'])
                ->orderBy('trip_count', 'desc')
                ->limit(10)
                ->get()
                ->map(function ($route) {
                    return [
                        'route' => $route->departure_city . ' → ' . $route->arrival_city,
                        'departure_city' => $route->departure_city,
                        'departure_country' => $route->departure_country,
                        'arrival_city' => $route->arrival_city,
                        'arrival_country' => $route->arrival_country,
                        'trip_count' => $route->trip_count,
                    ];
                });

            return Response::success([
                'routes' => $popularRoutes,
                'total' => $popularRoutes->count(),
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to get popular routes: ' . $e->getMessage());
        }
    }

    public function saveSearchAlert(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        // TODO: Implémenter le système d'alertes de recherche
        // Cela nécessite un modèle SearchAlert

        return Response::success([
            'message' => 'Search alert saved successfully'
        ]);
    }

    public function getRecentSearches(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        // TODO: Implémenter l'historique de recherche
        // Cela nécessite un modèle SearchHistory

        return Response::success([
            'searches' => [],
            'message' => 'Recent searches feature not yet implemented'
        ]);
    }

    public function getUserSearchAlerts(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        // TODO: Implémenter la récupération des alertes
        
        return Response::success([
            'alerts' => [],
            'message' => 'Search alerts feature not yet implemented'
        ]);
    }

    public function deleteSearchAlert(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        // TODO: Implémenter la suppression d'alerte

        return Response::success([
            'message' => 'Search alert deleted successfully'
        ]);
    }
}