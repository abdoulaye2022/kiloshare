<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Trip;
use KiloShare\Models\User;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;

class TripController
{
    public function getPublicTrips(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $queryParams = $request->getQueryParams();
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $offset = ($page - 1) * $limit;

            $trips = Trip::published()
                ->notExpired()
                ->with(['user', 'images'])
                ->orderByRelevance()
                ->skip($offset)
                ->take($limit)
                ->get();

            $total = Trip::published()->notExpired()->count();

            return Response::success([
                'trips' => $trips->map(function ($trip) {
                    return [
                        'id' => $trip->id,
                        'uuid' => $trip->uuid,
                        'title' => $trip->title,
                        'description' => $trip->description,
                        'departure_city' => $trip->departure_city,
                        'departure_country' => $trip->departure_country,
                        'departure_date' => $trip->departure_date,
                        'arrival_city' => $trip->arrival_city,
                        'arrival_country' => $trip->arrival_country,
                        'arrival_date' => $trip->arrival_date,
                        'transport_type' => $trip->transport_type,
                        'max_weight' => $trip->max_weight,
                        'available_weight' => $trip->available_weight,
                        'price_per_kg' => $trip->price_per_kg,
                        'currency' => $trip->currency,
                        'is_domestic' => $trip->is_domestic,
                        'route' => $trip->route,
                        'user' => [
                            'id' => $trip->user->id,
                            'uuid' => $trip->user->uuid,
                            'first_name' => $trip->user->first_name,
                            'last_name' => $trip->user->last_name,
                            'profile_picture' => $trip->user->profile_picture,
                            'is_verified' => $trip->user->is_verified,
                        ],
                        'images' => $trip->images->map(function ($image) {
                            return [
                                'id' => $image->id,
                                'url' => $image->url,
                                'thumbnail' => $image->thumbnail,
                            ];
                        }),
                    ];
                }),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch public trips: ' . $e->getMessage());
        }
    }

    public function search(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $queryParams = $request->getQueryParams();
            
            $query = Trip::published()->notExpired()->with(['user', 'images']);

            // Filtres de recherche
            if (!empty($queryParams['departure'])) {
                $query->where('departure_city', 'like', '%' . $queryParams['departure'] . '%');
            }

            if (!empty($queryParams['arrival'])) {
                $query->where('arrival_city', 'like', '%' . $queryParams['arrival'] . '%');
            }

            if (!empty($queryParams['transport_type'])) {
                $query->where('transport_type', $queryParams['transport_type']);
            }

            if (!empty($queryParams['departure_date'])) {
                $date = Carbon::parse($queryParams['departure_date']);
                $query->whereDate('departure_date', $date);
            }

            if (!empty($queryParams['min_weight'])) {
                $query->where('max_weight', '>=', (float) $queryParams['min_weight']);
            }

            if (!empty($queryParams['max_price'])) {
                $query->where('price_per_kg', '<=', (float) $queryParams['max_price']);
            }

            // Pagination
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $offset = ($page - 1) * $limit;

            $trips = $query->orderByRelevance()
                          ->skip($offset)
                          ->take($limit)
                          ->get();

            $total = $query->count();

            return Response::success([
                'trips' => $trips->map(function ($trip) {
                    return [
                        'id' => $trip->id,
                        'uuid' => $trip->uuid,
                        'title' => $trip->title,
                        'departure_city' => $trip->departure_city,
                        'arrival_city' => $trip->arrival_city,
                        'departure_date' => $trip->departure_date,
                        'transport_type' => $trip->transport_type,
                        'price_per_kg' => $trip->price_per_kg,
                        'available_weight' => $trip->available_weight,
                        'route' => $trip->route,
                        'user' => [
                            'first_name' => $trip->user->first_name,
                            'is_verified' => $trip->user->is_verified,
                        ],
                    ];
                }),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ],
                'filters' => $queryParams,
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Search failed: ' . $e->getMessage());
        }
    }

    public function create(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        // Validation
        $validator = new Validator();
        $rules = [
            'title' => Validator::required()->stringType()->length(3, 255),
            'description' => Validator::optional(Validator::stringType()),
            'departure_city' => Validator::required()->stringType(),
            'departure_country' => Validator::required()->stringType(),
            'departure_date' => Validator::required()->date(),
            'arrival_city' => Validator::required()->stringType(),
            'arrival_country' => Validator::required()->stringType(),
            'arrival_date' => Validator::required()->date(),
            'transport_type' => Validator::required()->in(['plane', 'train', 'bus', 'car']),
            'max_weight' => Validator::required()->positive(),
            'price_per_kg' => Validator::required()->positive(),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $trip = Trip::create([
                'user_id' => $user->id,
                'title' => $data['title'],
                'description' => $data['description'] ?? '',
                'departure_city' => $data['departure_city'],
                'departure_country' => $data['departure_country'],
                'departure_date' => Carbon::parse($data['departure_date']),
                'arrival_city' => $data['arrival_city'],
                'arrival_country' => $data['arrival_country'],
                'arrival_date' => Carbon::parse($data['arrival_date']),
                'transport_type' => $data['transport_type'],
                'max_weight' => (float) $data['max_weight'],
                'price_per_kg' => (float) $data['price_per_kg'],
                'currency' => $data['currency'] ?? 'EUR',
                'is_domestic' => $data['departure_country'] === $data['arrival_country'],
                'restrictions' => $data['restrictions'] ?? [],
                'special_instructions' => $data['special_instructions'] ?? '',
                'status' => Trip::STATUS_DRAFT,
            ]);

            return Response::created([
                'trip' => [
                    'id' => $trip->id,
                    'uuid' => $trip->uuid,
                    'title' => $trip->title,
                    'status' => $trip->status,
                    'departure_city' => $trip->departure_city,
                    'arrival_city' => $trip->arrival_city,
                    'departure_date' => $trip->departure_date,
                    'created_at' => $trip->created_at,
                ]
            ], 'Trip created successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to create trip: ' . $e->getMessage());
        }
    }

    public function get(ServerRequestInterface $request): ResponseInterface
    {
        $id = $request->getAttribute('id');
        $user = $request->getAttribute('user'); // Peut être null si OptionalAuth

        try {
            $trip = Trip::with(['user', 'images', 'bookings'])
                       ->find($id);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            // Vérifier la visibilité
            if ($trip->status !== Trip::STATUS_PUBLISHED && (!$user || $trip->user_id !== $user->id)) {
                return Response::forbidden('Trip not available');
            }

            // Incrémenter les vues si c'est un visiteur
            if ($user && $trip->user_id !== $user->id) {
                // TODO: Incrémenter les vues
            }

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'uuid' => $trip->uuid,
                    'title' => $trip->title,
                    'description' => $trip->description,
                    'departure_city' => $trip->departure_city,
                    'departure_country' => $trip->departure_country,
                    'departure_date' => $trip->departure_date,
                    'arrival_city' => $trip->arrival_city,
                    'arrival_country' => $trip->arrival_country,
                    'arrival_date' => $trip->arrival_date,
                    'transport_type' => $trip->transport_type,
                    'max_weight' => $trip->max_weight,
                    'available_weight' => $trip->available_weight,
                    'price_per_kg' => $trip->price_per_kg,
                    'total_reward' => $trip->total_reward,
                    'currency' => $trip->currency,
                    'status' => $trip->status,
                    'is_domestic' => $trip->is_domestic,
                    'restrictions' => $trip->restrictions,
                    'special_instructions' => $trip->special_instructions,
                    'route' => $trip->route,
                    'duration' => $trip->duration,
                    'is_expired' => $trip->is_expired,
                    'user' => [
                        'id' => $trip->user->id,
                        'uuid' => $trip->user->uuid,
                        'first_name' => $trip->user->first_name,
                        'last_name' => $trip->user->last_name,
                        'profile_picture' => $trip->user->profile_picture,
                        'is_verified' => $trip->user->is_verified,
                    ],
                    'images' => $trip->images,
                    'bookings_count' => $trip->bookings->count(),
                    'can_book' => $user ? $trip->canBeBookedBy($user) : false,
                    'is_owner' => $user ? $trip->isOwner($user) : false,
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch trip: ' . $e->getMessage());
        }
    }

    public function list(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $queryParams = $request->getQueryParams();

        try {
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $status = $queryParams['status'] ?? null;
            
            $query = Trip::where('user_id', $user->id)
                        ->with(['images', 'bookings']);

            if ($status) {
                $query->where('status', $status);
            }

            $trips = $query->orderBy('created_at', 'desc')
                          ->skip(($page - 1) * $limit)
                          ->take($limit)
                          ->get();

            $total = $query->count();

            return Response::success([
                'trips' => $trips->map(function ($trip) {
                    return [
                        'id' => $trip->id,
                        'uuid' => $trip->uuid,
                        'title' => $trip->title,
                        'status' => $trip->status,
                        'departure_city' => $trip->departure_city,
                        'arrival_city' => $trip->arrival_city,
                        'departure_date' => $trip->departure_date,
                        'price_per_kg' => $trip->price_per_kg,
                        'available_weight' => $trip->available_weight,
                        'bookings_count' => $trip->bookings->count(),
                        'created_at' => $trip->created_at,
                    ];
                }),
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => $total,
                    'total_pages' => ceil($total / $limit),
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch trips: ' . $e->getMessage());
        }
    }

    public function update(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            $trip = Trip::find($id);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if (!$trip->isOwner($user)) {
                return Response::forbidden('You can only edit your own trips');
            }

            // Ne peut modifier que les drafts ou trips pas encore publiés
            if (!in_array($trip->status, [Trip::STATUS_DRAFT, Trip::STATUS_PENDING_APPROVAL])) {
                return Response::error('Cannot modify published trips');
            }

            // Validation des champs à mettre à jour
            $allowedFields = [
                'title', 'description', 'departure_city', 'departure_country',
                'departure_date', 'arrival_city', 'arrival_country', 'arrival_date',
                'transport_type', 'max_weight', 'price_per_kg', 'restrictions',
                'special_instructions'
            ];

            $updateData = array_intersect_key($data, array_flip($allowedFields));

            if (isset($updateData['departure_date'])) {
                $updateData['departure_date'] = Carbon::parse($updateData['departure_date']);
            }

            if (isset($updateData['arrival_date'])) {
                $updateData['arrival_date'] = Carbon::parse($updateData['arrival_date']);
            }

            // Recalculer is_domestic si pays modifiés
            if (isset($updateData['departure_country']) && isset($updateData['arrival_country'])) {
                $updateData['is_domestic'] = $updateData['departure_country'] === $updateData['arrival_country'];
            }

            $trip->update($updateData);

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'uuid' => $trip->uuid,
                    'title' => $trip->title,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip updated successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to update trip: ' . $e->getMessage());
        }
    }

    public function publishTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $trip = Trip::find($id);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if (!$trip->isOwner($user)) {
                return Response::forbidden('You can only publish your own trips');
            }

            if ($trip->status !== Trip::STATUS_DRAFT) {
                return Response::error('Only draft trips can be published');
            }

            $trip->publish();

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'published_at' => $trip->published_at,
                ]
            ], 'Trip published successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to publish trip: ' . $e->getMessage());
        }
    }

    public function pauseTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $trip = Trip::find($id);

            if (!$trip || !$trip->isOwner($user)) {
                return Response::notFound('Trip not found');
            }

            $trip->pause();

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                ]
            ], 'Trip paused successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to pause trip: ' . $e->getMessage());
        }
    }

    public function resumeTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $trip = Trip::find($id);

            if (!$trip || !$trip->isOwner($user)) {
                return Response::notFound('Trip not found');
            }

            $trip->resume();

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                ]
            ], 'Trip resumed successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to resume trip: ' . $e->getMessage());
        }
    }

    public function cancelTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $trip = Trip::find($id);

            if (!$trip || !$trip->isOwner($user)) {
                return Response::notFound('Trip not found');
            }

            $trip->cancel();

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                ]
            ], 'Trip cancelled successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to cancel trip: ' . $e->getMessage());
        }
    }

    public function delete(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $trip = Trip::find($id);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if (!$trip->isOwner($user)) {
                return Response::forbidden('You can only delete your own trips');
            }

            // Ne peut supprimer que les drafts
            if ($trip->status !== Trip::STATUS_DRAFT) {
                return Response::error('Only draft trips can be deleted');
            }

            $trip->delete();

            return Response::success([], 'Trip deleted successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to delete trip: ' . $e->getMessage());
        }
    }

    public function getPriceSuggestion(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $queryParams = $request->getQueryParams();
            
            $departureCity = $queryParams['departure_city'] ?? null;
            $departureCountry = $queryParams['departure_country'] ?? null;
            $arrivalCity = $queryParams['arrival_city'] ?? null;
            $arrivalCountry = $queryParams['arrival_country'] ?? null;
            $currency = $queryParams['currency'] ?? 'EUR';
            
            if (!$departureCity || !$departureCountry || !$arrivalCity || !$arrivalCountry) {
                return Response::badRequest('Missing required parameters: departure_city, departure_country, arrival_city, arrival_country');
            }
            
            // Logique simple de suggestion de prix basée sur des moyennes historiques
            $basePrice = 5.0; // Prix de base par kg
            
            // Facteurs d'ajustement
            $isDomestic = ($departureCountry === $arrivalCountry);
            if (!$isDomestic) {
                $basePrice *= 1.5; // Plus cher pour international
            }
            
            // Facteur distance approximatif (basé sur les villes connues)
            $distanceFactor = $this->estimateDistanceFactor($departureCity, $arrivalCity);
            $basePrice *= $distanceFactor;
            
            // Rechercher des prix similaires dans la base
            $similarTrips = Trip::where('departure_city', 'LIKE', "%{$departureCity}%")
                               ->where('arrival_city', 'LIKE', "%{$arrivalCity}%")
                               ->where('status', Trip::STATUS_PUBLISHED)
                               ->orderBy('created_at', 'desc')
                               ->take(10)
                               ->get();
            
            $averagePrice = $basePrice;
            if ($similarTrips->count() > 0) {
                $averagePrice = $similarTrips->avg('price_per_kg') ?: $basePrice;
            }
            
            $minPrice = $averagePrice * 0.7;
            $maxPrice = $averagePrice * 1.3;
            
            return Response::success([
                'price_suggestion' => [
                    'suggested_price_per_kg' => round($averagePrice, 2),
                    'min_recommended' => round($minPrice, 2),
                    'max_recommended' => round($maxPrice, 2),
                    'currency' => $currency,
                    'based_on_trips' => $similarTrips->count(),
                    'is_domestic' => $isDomestic,
                    'departure_city' => $departureCity,
                    'departure_country' => $departureCountry,
                    'arrival_city' => $arrivalCity,
                    'arrival_country' => $arrivalCountry,
                ]
            ]);
            
        } catch (\Exception $e) {
            return Response::serverError('Failed to get price suggestion: ' . $e->getMessage());
        }
    }
    
    private function estimateDistanceFactor(string $departureCity, string $arrivalCity): float
    {
        // Facteur distance simple basé sur des villes connues
        // Dans un vrai projet, utiliser une API de géolocalisation
        $majorCities = [
            'paris', 'london', 'berlin', 'madrid', 'rome', 'amsterdam', 
            'brussels', 'zurich', 'vienna', 'prague', 'barcelona', 'milan'
        ];
        
        $departure = strtolower($departureCity);
        $arrival = strtolower($arrivalCity);
        
        // Si les deux villes sont des grandes villes européennes
        if (in_array($departure, $majorCities) && in_array($arrival, $majorCities)) {
            return 1.2; // Distance moyenne
        }
        
        // Facteur par défaut
        return 1.0;
    }
}