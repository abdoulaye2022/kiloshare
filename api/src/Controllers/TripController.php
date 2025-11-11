<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Trip;
use KiloShare\Models\User;
use KiloShare\Models\TripImage;
use KiloShare\Models\Booking;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use KiloShare\Services\GoogleCloudStorageService;
use KiloShare\Services\CancellationService;
use KiloShare\Services\SmartNotificationService;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;
use Illuminate\Support\Str;

class TripController
{
    public function getPublicTrips(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $queryParams = $request->getQueryParams();
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $offset = ($page - 1) * $limit;

            $trips = Trip::active()
                ->notExpired()
                ->with(['user', 'images'])
                ->orderBy('created_at', 'desc')
                ->skip($offset)
                ->take($limit)
                ->get();

            $total = Trip::active()->notExpired()->count();

            return Response::success([
                'trips' => $trips->map(function ($trip) {
                    // Utiliser les accesseurs du modèle
                    $totalBookedWeight = $trip->booked_weight;
                    $totalCapacityKg = ($trip->available_weight_kg ?? 0);
                    
                    return [
                        'id' => $trip->id,
                        'uuid' => $trip->uuid,
                        'title' => $trip->title,
                        'description' => $trip->description,
                        'status' => $trip->status,
                        'departure_city' => $trip->departure_city,
                        'departure_country' => $trip->departure_country,
                        'departure_date' => $trip->departure_date,
                        'arrival_city' => $trip->arrival_city,
                        'arrival_country' => $trip->arrival_country,
                        'arrival_date' => $trip->arrival_date,
                        'transport_type' => $trip->transport_type,
                        'available_weight_kg' => $trip->available_weight_kg,
                        'available_weight' => $trip->available_weight,
                        'price_per_kg' => $trip->price_per_kg,
                        'currency' => $trip->currency,
                        'is_domestic' => $trip->is_domestic,
                        'route' => $trip->route,
                        // Nouvelles informations sur la capacité
                        'total_capacity_kg' => (float) $totalCapacityKg,
                        'booked_weight_kg' => (float) $totalBookedWeight,
                        'booking_rate' => $totalCapacityKg > 0 ? round(($totalBookedWeight / $totalCapacityKg) * 100, 1) : 0,
                        'user' => [
                            'id' => $trip->user->id,
                            'uuid' => $trip->user->uuid,
                            'first_name' => $trip->user->first_name,
                            'last_name' => $trip->user->last_name,
                            'profile_picture' => $trip->user->profile_picture,
                            'profile_picture_url' => $trip->user->profile_picture_url,
                            'is_verified' => $trip->user->is_verified,
                        ],
                        'images' => $trip->images->map(function ($image) {
                            return [
                                'id' => $image->id,
                                'url' => $image->image_url,
                                'thumbnail' => $image->thumbnail_url,
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
            
            $query = Trip::active()->notExpired()->with(['user', 'images']);

            // Filtres de recherche avec normalisation pour les accents et casse
            if (!empty($queryParams['departure'])) {
                $searchTerm = $queryParams['departure'];
                $normalizedTerm = $this->normalizeCityName($searchTerm);
                error_log("TripController::search - Departure search: '$searchTerm' normalized to: '$normalizedTerm'");
                
                $query->where(function ($q) use ($searchTerm, $normalizedTerm) {
                    $q->whereRaw('LOWER(departure_city) LIKE LOWER(?)', ['%' . $searchTerm . '%'])
                      ->orWhereRaw('LOWER(departure_city) LIKE LOWER(?)', ['%' . $normalizedTerm . '%']);
                });
            }

            if (!empty($queryParams['arrival'])) {
                $searchTerm = $queryParams['arrival'];
                $normalizedTerm = $this->normalizeCityName($searchTerm);
                error_log("TripController::search - Arrival search: '$searchTerm' normalized to: '$normalizedTerm'");
                
                $query->where(function ($q) use ($searchTerm, $normalizedTerm) {
                    $q->whereRaw('LOWER(arrival_city) LIKE LOWER(?)', ['%' . $searchTerm . '%'])
                      ->orWhereRaw('LOWER(arrival_city) LIKE LOWER(?)', ['%' . $normalizedTerm . '%']);
                });
            }

            if (!empty($queryParams['transport_type'])) {
                $query->where('transport_type', $queryParams['transport_type']);
            }

            if (!empty($queryParams['departure_date'])) {
                $date = Carbon::parse($queryParams['departure_date']);
                $query->whereDate('departure_date', $date);
            }

            if (!empty($queryParams['min_weight'])) {
                $query->where('available_weight_kg', '>=', (float) $queryParams['min_weight']);
            }

            if (!empty($queryParams['max_price'])) {
                $query->where('price_per_kg', '<=', (float) $queryParams['max_price']);
            }

            // Pagination
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $offset = ($page - 1) * $limit;

            // Debug - lister toutes les villes de départ pour voir ce qu'on a
            if (!empty($queryParams['debug_cities'])) {
                $allCities = Trip::active()
                    ->select('departure_city', 'arrival_city')
                    ->distinct()
                    ->get()
                    ->flatMap(function($trip) {
                        return [$trip->departure_city, $trip->arrival_city];
                    })
                    ->unique()
                    ->sort()
                    ->values();
                
                error_log("TripController::search - Available cities: " . implode(', ', $allCities->toArray()));
            }

            $trips = $query->orderByRelevance()
                          ->skip($offset)
                          ->take($limit)
                          ->get();

            $total = $query->count();
            
            error_log("TripController::search - Found $total trips matching criteria");

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

        // Debug logging
        error_log("=== TRIP CREATE DEBUG ===");
        error_log("User ID: " . ($user ? $user->id : 'NULL'));
        error_log("Raw request body: " . $request->getBody()->getContents());
        $request->getBody()->rewind(); // Reset stream
        $data = json_decode($request->getBody()->getContents(), true);
        error_log("Parsed data: " . json_encode($data, JSON_PRETTY_PRINT));
        error_log("Data keys: " . implode(', ', array_keys($data ?? [])));

        // Debug dates
        error_log("DEBUG: departure_date value = " . ($data['departure_date'] ?? 'NULL'));
        error_log("DEBUG: arrival_date value = " . ($data['arrival_date'] ?? 'NULL'));
        error_log("DEBUG: departure_date type = " . gettype($data['departure_date'] ?? null));
        error_log("DEBUG: arrival_date type = " . gettype($data['arrival_date'] ?? null));

        // Test regex manually
        $dateRegex = '/^\d{4}-\d{2}-\d{2}(\s\d{2}:\d{2}:\d{2})?$/';
        if (isset($data['departure_date'])) {
            $depMatch = preg_match($dateRegex, $data['departure_date']);
            error_log("DEBUG: departure_date regex match = " . ($depMatch ? 'YES' : 'NO'));
        }
        if (isset($data['arrival_date'])) {
            $arrMatch = preg_match($dateRegex, $data['arrival_date']);
            error_log("DEBUG: arrival_date regex match = " . ($arrMatch ? 'YES' : 'NO'));
        }

        // Validation
        $validator = new Validator();
        $rules = [
            'transport_type' => Validator::required()->stringType(),
            'departure_city' => Validator::required()->stringType(),
            'departure_country' => Validator::required()->stringType(),
            'departure_date' => Validator::required()->stringType()->regex('/^\d{4}-\d{2}-\d{2}(\s\d{2}:\d{2}:\d{2})?$/'),
            'arrival_city' => Validator::required()->stringType(),
            'arrival_country' => Validator::required()->stringType(),
            'arrival_date' => Validator::required()->stringType()->regex('/^\d{4}-\d{2}-\d{2}(\s\d{2}:\d{2}:\d{2})?$/'),
            'available_weight_kg' => Validator::required()->positive(),
            'price_per_kg' => Validator::required()->positive(),
            'currency' => Validator::required()->stringType(),
            'description' => Validator::optional(Validator::stringType()),
            'special_notes' => Validator::optional(Validator::stringType()),
            'flight_number' => Validator::optional(Validator::stringType()),
            'airline' => Validator::optional(Validator::stringType()),
            'images' => Validator::optional(Validator::array()),
        ];

        if (!$validator->validate($data, $rules)) {
            error_log("Validation FAILED:");
            error_log("Validation errors: " . json_encode($validator->getErrors(), JSON_PRETTY_PRINT));
            return Response::validationError($validator->getErrors());
        }
        
        try {
            // Vérifier si l'utilisateur a un compte Stripe actif
            $hasStripeAccount = $user->hasActiveStripeAccount();
            $needsStripeSetup = !$hasStripeAccount;

            // Générer un titre automatique si non fourni
            $title = $data['title'] ?? "{$data['departure_city']} → {$data['arrival_city']}";

            // Mapper transport type de Flutter vers DB
            $transportTypeMap = [
                'flight' => 'plane',
                'train' => 'train',
                'bus' => 'bus',
                'car' => 'car'
            ];
            $transportType = $transportTypeMap[$data['transport_type']] ?? 'plane';

            // Définir le statut : DRAFT si pas de Stripe, sinon DRAFT également (publication manuelle)
            $tripStatus = Trip::STATUS_DRAFT;

            $trip = Trip::create([
                'user_id' => $user->id,
                'title' => $title,
                'description' => $data['description'] ?? '',
                'departure_city' => $data['departure_city'],
                'departure_country' => $data['departure_country'],
                'departure_date' => Carbon::parse($data['departure_date']),
                'arrival_city' => $data['arrival_city'],
                'arrival_country' => $data['arrival_country'],
                'arrival_date' => Carbon::parse($data['arrival_date']),
                'transport_type' => $transportType,
                'available_weight_kg' => (float) $data['available_weight_kg'],
                'price_per_kg' => (float) $data['price_per_kg'],
                'currency' => $data['currency'],
                'is_domestic' => $data['departure_country'] === $data['arrival_country'],
                'special_notes' => $data['special_notes'] ?? '',
                'status' => $tripStatus,
            ]);

            // Gérer les images si présentes (URLs GCS)
            $images = [];
            if (!empty($data['images']) && is_array($data['images'])) {
                error_log("TripController: Processing " . count($data['images']) . " images");
                error_log("TripController: Images data: " . json_encode($data['images']));
                try {
                    $images = $this->handleTripImageUrls($data['images'], $trip);
                    error_log("TripController: Successfully processed " . count($images) . " images");
                } catch (\Exception $e) {
                    error_log("Image processing failed during trip creation: " . $e->getMessage());
                    error_log("Stack trace: " . $e->getTraceAsString());
                    // Continuer même si le traitement d'images échoue
                }
            } else {
                error_log("TripController: No images to process. Images data: " . json_encode($data['images'] ?? null));
            }

            // Préparer la réponse avec warnings si nécessaire
            $responseData = [
                'trip' => [
                    'id' => $trip->id,
                    'uuid' => $trip->uuid,
                    'title' => $trip->title,
                    'status' => $trip->status,
                    'departure_city' => $trip->departure_city,
                    'arrival_city' => $trip->arrival_city,
                    'departure_date' => $trip->departure_date,
                    'created_at' => $trip->created_at,
                    'images' => $images,
                ]
            ];

            // Ajouter un warning si Stripe n'est pas configuré
            if ($needsStripeSetup) {
                $responseData['warning'] = [
                    'code' => 'stripe_account_required',
                    'message' => 'Votre voyage a été créé en brouillon. Configurez votre compte Stripe pour le publier et recevoir des paiements.',
                    'action_required' => 'setup_stripe',
                    'stripe_setup_url' => $this->getStripeOnboardingUrl($user)
                ];
            }

            $message = $needsStripeSetup
                ? 'Voyage créé en brouillon. Configuration Stripe requise pour publication.'
                : 'Voyage créé avec succès';

            return Response::created($responseData, $message);

        } catch (\Exception $e) {
            error_log("TRIP CREATION ERROR: " . $e->getMessage());
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
            $isPubliclyVisible = in_array($trip->status, [
                Trip::STATUS_PUBLISHED,
                Trip::STATUS_ACTIVE,
                Trip::STATUS_IN_PROGRESS
            ]);
            
            if (!$isPubliclyVisible && (!$user || $trip->user_id !== $user->id)) {
                return Response::forbidden('Trip not available');
            }

            // Incrémenter les vues si c'est un visiteur
            if ($user && $trip->user_id !== $user->id) {
                // TODO: Incrémenter les vues
            }
            
            // Debug restrictions
            error_log("TripController::get - Trip restrictions raw: " . json_encode($trip->restrictions));
            error_log("TripController::get - Trip restrictions type: " . gettype($trip->restrictions));

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
                    'available_weight_kg' => $trip->available_weight_kg,
                    'available_weight' => $trip->available_weight,
                    'price_per_kg' => $trip->price_per_kg,
                    'total_reward' => $trip->total_reward,
                    'currency' => $trip->currency,
                    'status' => $trip->status,
                    'is_domestic' => $trip->is_domestic,
                    'restrictions' => $trip->restrictions,
                    'special_notes' => $trip->special_notes,
                    'route' => $trip->route,
                    'duration' => $trip->duration,
                    'is_expired' => $trip->is_expired,
                    'user' => [
                        'id' => $trip->user->id,
                        'uuid' => $trip->user->uuid,
                        'first_name' => $trip->user->first_name,
                        'last_name' => $trip->user->last_name,
                        'profile_picture' => $trip->user->profile_picture,
                        'profile_picture_url' => $trip->user->profile_picture_url,
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
                        'available_weight_kg' => $trip->available_weight_kg,
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
                'transport_type', 'available_weight_kg', 'price_per_kg', 'restrictions',
                'special_notes'
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

            // Vérifier que l'utilisateur a un compte Stripe actif avant de publier
            if (!$user->canPublishTrips()) {
                return Response::error(
                    'Vous devez configurer votre compte Stripe avant de publier un voyage. Cela permet de recevoir des paiements de manière sécurisée.',
                    [
                        'code' => 'stripe_account_required',
                        'action_required' => 'setup_stripe',
                        'stripe_setup_url' => $this->getStripeOnboardingUrl($user)
                    ],
                    403
                );
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

    /**
     * Vérifie si un voyageur peut annuler son voyage
     */
    public function checkTripCancellation(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::find($id);
            if (!$trip) {
                return Response::notFound('Voyage non trouvé');
            }

            $cancellationService = new CancellationService();
            $result = $cancellationService->canTravelerCancelTrip($user, $trip);

            return Response::success([
                'can_cancel' => $result['allowed'],
                'reason' => $result['reason'] ?? null,
                'has_bookings' => $result['has_bookings'] ?? false,
                'requires_reason' => $result['has_bookings'] ?? false
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Erreur lors de la vérification: ' . $e->getMessage());
        }
    }

    /**
     * Annule un voyage avec les politiques strictes
     */
    public function cancelTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::find($id);
            if (!$trip) {
                return Response::notFound('Voyage non trouvé');
            }

            // Récupérer les données de la requête
            $body = $request->getParsedBody();
            $reason = $body['cancellation_reason'] ?? null;

            $cancellationService = new CancellationService();
            $result = $cancellationService->cancelTripByTraveler($trip, $reason);

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'cancelled_at' => $trip->cancelled_at
                ],
                'message' => $result['message'],
                'refunds_processed' => $result['refunds_processed']
            ]);

        } catch (\Exception $e) {
            return Response::error($e->getMessage(), [], 400);
        }
    }

    /**
     * Récupère l'historique des annulations d'un utilisateur
     */
    public function getCancellationHistory(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        
        try {
            $cancellationService = new CancellationService();
            $summary = $cancellationService->getUserCancellationSummary($user->id);

            // Récupérer les rapports d'annulation publics
            $publicReports = \Illuminate\Database\Capsule\Manager::table('trip_cancellation_reports')
                ->join('trips', 'trip_cancellation_reports.trip_id', '=', 'trips.id')
                ->where('trip_cancellation_reports.user_id', $user->id)
                ->where('trip_cancellation_reports.is_public', true)
                ->where(function ($query) {
                    $query->whereNull('trip_cancellation_reports.expires_at')
                          ->orWhere('trip_cancellation_reports.expires_at', '>', now());
                })
                ->select([
                    'trip_cancellation_reports.*',
                    'trips.title as trip_title',
                    'trips.departure_city',
                    'trips.arrival_city'
                ])
                ->orderBy('trip_cancellation_reports.created_at', 'desc')
                ->get();

            return Response::success([
                'summary' => $summary,
                'public_reports' => $publicReports,
                'next_cancellation_allowed' => $summary['can_cancel_with_booking'] ? 
                    'Immédiatement' : 
                    Carbon::parse($summary['last_cancellation_date'])->addDays(90)->format('d/m/Y')
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Erreur lors de la récupération de l\'historique: ' . $e->getMessage());
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
            $currency = $queryParams['currency'] ?? 'CAD';
            
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

    /**
     * Normalise les noms de villes pour la recherche (enlève les accents et normalise)
     */
    private function normalizeCityName(string $cityName): string
    {
        // Convertir en minuscules et nettoyer
        $normalized = strtolower(trim($cityName));
        
        // Enlever les accents et caractères spéciaux
        $normalized = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $normalized);
        
        // Nettoyer les caractères non-alphabétiques restants
        $normalized = preg_replace('/[^a-z\s-]/', '', $normalized);
        
        // Mapping de villes courantes avec leurs variantes (bidirectionnel)
        $cityMappings = [
            // Canada
            'montreal' => ['montréal', 'montréal'],
            'montréal' => ['montreal', 'montreal'],
            'montral' => ['montréal', 'montreal'], // variante sans accent mal écrite
            'québec' => ['quebec', 'quebec city'],
            'quebec' => ['québec', 'quebec city'],
            'toronto' => ['toronto'],
            'vancouver' => ['vancouver'],
            'ottawa' => ['ottawa'],
            'calgary' => ['calgary'],
            
            // France
            'paris' => ['paris'],
            'lyon' => ['lyon'],
            'marseille' => ['marseille'],
            'nice' => ['nice'],
            'toulouse' => ['toulouse'],
            'strasbourg' => ['strasbourg'],
            'nantes' => ['nantes'],
            'bordeaux' => ['bordeaux'],
            'lille' => ['lille'],
            
            // Autres pays francophones
            'genève' => ['geneve', 'geneva'],
            'geneve' => ['genève', 'geneva'],
            'geneva' => ['genève', 'geneve'],
            'bruxelles' => ['brussels', 'brussel'],
            'brussels' => ['bruxelles', 'brussel'],
            'brussel' => ['bruxelles', 'brussels'],
            'zurich' => ['zürich', 'zurich'],
            'zürich' => ['zurich'],
            
            // Maroc
            'casablanca' => ['casablanca', 'casa'],
            'casa' => ['casablanca'],
            'rabat' => ['rabat'],
            'marrakech' => ['marrakech', 'marrakesh'],
            'marrakesh' => ['marrakech'],
            'fès' => ['fes', 'fez'],
            'fes' => ['fès', 'fez'],
            'fez' => ['fès', 'fes'],
        ];
        
        // Rechercher des correspondances exactes
        if (isset($cityMappings[$normalized])) {
            return $cityMappings[$normalized][0]; // Retourner la première alternative
        }
        
        // Rechercher des correspondances partielles
        foreach ($cityMappings as $key => $alternatives) {
            if (strpos($normalized, $key) !== false || strpos($key, $normalized) !== false) {
                return $key;
            }
            foreach ($alternatives as $alt) {
                if (strpos($normalized, strtolower($alt)) !== false || strpos(strtolower($alt), $normalized) !== false) {
                    return $alt;
                }
            }
        }
        
        return $normalized;
    }

    /**
     * Gérer l'upload d'images pour un trip
     */
    private function handleTripImageUpload($uploadedFiles, Trip $trip): array
    {
        $images = is_array($uploadedFiles) ? $uploadedFiles : [$uploadedFiles];
        $uploadedImages = [];

        // Utiliser le stockage local si GCS n'est pas configuré
        try {
            $storageService = new GoogleCloudStorageService();
        } catch (\Exception $e) {
            error_log("GCS not available, using local storage: " . $e->getMessage());
            $storageService = new \KiloShare\Services\LocalStorageService();
        }

        $currentImageCount = $trip->images()->count();

        foreach ($images as $index => $uploadedFile) {
            if ($uploadedFile->getError() !== UPLOAD_ERR_OK) {
                continue;
            }

            // Vérifier le type MIME
            $mimeType = $uploadedFile->getClientMediaType();
            if (!in_array($mimeType, ['image/jpeg', 'image/png', 'image/jpg'])) {
                continue;
            }

            // Limite de 5 images par trip
            if ($currentImageCount + count($uploadedImages) >= 5) {
                break;
            }

            // Générer un nom unique et déplacer temporairement
            $filename = 'trip_' . $trip->id . '_' . $index . '_' . time() . '.jpg';
            $tempPath = sys_get_temp_dir() . '/' . $filename;
            $uploadedFile->moveTo($tempPath);

            try {
                // Upload vers le service de stockage (GCS ou Local)
                $destination = 'trips/' . $trip->id . '/' . $filename;
                $uploadResult = $storageService->uploadImage($tempPath, $destination, [
                    'metadata' => [
                        'trip_id' => $trip->id,
                        'index' => $index
                    ]
                ]);

                if (!$uploadResult['success']) {
                    throw new \Exception($uploadResult['error']);
                }

                // Créer l'enregistrement en base
                // Stocker uniquement le CHEMIN, l'URL sera générée à la volée
                $tripImage = TripImage::create([
                    'trip_id' => $trip->id,
                    'image_path' => $uploadResult['path'],
                    'url' => $uploadResult['path'], // Stocker le chemin (rétrocompatibilité avec le schema)
                    'thumbnail' => $uploadResult['path'], // Idem pour thumbnail
                    'image_name' => $filename,
                    'is_primary' => ($currentImageCount + count($uploadedImages)) === 0,
                    'order' => $currentImageCount + count($uploadedImages) + 1,
                    'file_size' => filesize($tempPath),
                    'width' => null,
                    'height' => null,
                    'mime_type' => $mimeType,
                ]);

                $uploadedImages[] = [
                    'id' => $tripImage->id,
                    'url' => $tripImage->url,
                    'thumbnail' => $tripImage->thumbnail,
                    'is_primary' => $tripImage->is_primary,
                    'order' => $tripImage->order,
                ];

            } catch (\Exception $e) {
                error_log("Image upload failed for trip: " . $e->getMessage());
                continue;
            } finally {
                // Nettoyer le fichier temporaire
                if (file_exists($tempPath)) {
                    unlink($tempPath);
                }
            }
        }

        return $uploadedImages;
    }

    /**
     * Traiter les URLs d'images GCS pour un trip
     */
    private function handleTripImageUrls(array $imageUrls, Trip $trip): array
    {
        $processedImages = [];
        $currentImageCount = $trip->images()->count();
        
        error_log("handleTripImageUrls: Starting with " . count($imageUrls) . " images, trip has " . $currentImageCount . " existing images");

        foreach ($imageUrls as $index => $imageData) {
            error_log("handleTripImageUrls: Processing image $index: " . json_encode($imageData));
            
            // Limite de 5 images par trip
            if ($currentImageCount + count($processedImages) >= 5) {
                error_log("handleTripImageUrls: Reached image limit, breaking");
                break;
            }

            // Valider que l'URL est bien fournie
            if (empty($imageData['url'])) {
                error_log("handleTripImageUrls: Image $index has no URL, skipping");
                continue;
            }

            try {
                // Créer l'enregistrement en base avec les données GCS
                $tripImage = TripImage::create([
                    'trip_id' => $trip->id,
                    'image_path' => $imageData['path'] ?? '',
                    'url' => $imageData['url'],
                    'thumbnail' => $imageData['thumbnail'] ?? null,
                    'image_name' => basename(parse_url($imageData['url'], PHP_URL_PATH)),
                    'is_primary' => ($currentImageCount + count($processedImages)) === 0,
                    'order' => $currentImageCount + count($processedImages) + 1,
                    'file_size' => $imageData['file_size'] ?? null,
                    'width' => $imageData['width'] ?? null,
                    'height' => $imageData['height'] ?? null,
                    'mime_type' => $imageData['format'] ? "image/{$imageData['format']}" : 'image/jpeg',
                ]);

                $processedImages[] = [
                    'id' => $tripImage->id,
                    'url' => $tripImage->url,
                    'thumbnail' => $tripImage->thumbnail,
                    'is_primary' => $tripImage->is_primary,
                    'order' => $tripImage->order,
                ];

            } catch (\Exception $e) {
                error_log("Failed to save trip image: " . $e->getMessage());
                continue;
            }
        }

        return $processedImages;
    }

    public function addTripImage(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = (int) $request->getAttribute('id');
        
        error_log("=== ADD TRIP IMAGE DEBUG ===");
        error_log("Trip ID: " . $tripId);
        error_log("User ID: " . ($user ? $user->id : 'NULL'));

        try {
            $trip = Trip::find($tripId);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if (!$trip->isOwner($user)) {
                return Response::forbidden('You can only add images to your own trips');
            }

            // Vérifier le nombre d'images existantes (max 5)
            $currentImageCount = $trip->images()->count();
            if ($currentImageCount >= 5) {
                return Response::error('Maximum 5 images allowed per trip');
            }

            $uploadedFiles = $request->getUploadedFiles();
            error_log("Uploaded files: " . json_encode(array_keys($uploadedFiles)));
            
            if (empty($uploadedFiles['images'])) {
                error_log("ERROR: No images in uploaded files");
                return Response::badRequest('No images uploaded');
            }

            $uploadedImages = $this->handleTripImageUpload($uploadedFiles['images'], $trip);

            if (empty($uploadedImages)) {
                return Response::error('No valid images were uploaded');
            }

            return Response::success([
                'images' => $uploadedImages
            ], 'Images uploaded successfully');

        } catch (\Exception $e) {
            error_log("ERROR in addTripImage: " . $e->getMessage());
            error_log("Stack trace: " . $e->getTraceAsString());
            return Response::serverError('Failed to upload images: ' . $e->getMessage());
        }
    }


    public function removeTripImage(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = (int) $request->getAttribute('id');
        $imageId = (int) $request->getAttribute('imageId');

        try {
            $trip = Trip::find($tripId);
            if (!$trip || !$trip->isOwner($user)) {
                return Response::notFound('Trip not found');
            }

            $image = TripImage::where('trip_id', $tripId)->find($imageId);
            if (!$image) {
                return Response::notFound('Image not found');
            }

            // Supprimer l'image de Google Cloud Storage
            $gcsService = new GoogleCloudStorageService();
            try {
                $gcsService->deleteImage($image->image_path);
            } catch (\Exception $e) {
                error_log("Failed to delete image from GCS: " . $e->getMessage());
                // Continuer quand même pour supprimer l'enregistrement local
            }

            $image->delete();

            return Response::success([], 'Image removed successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to remove image: ' . $e->getMessage());
        }
    }

    public function getTripImages(ServerRequestInterface $request): ResponseInterface
    {
        $tripId = (int) $request->getAttribute('id');
        $user = $request->getAttribute('user'); // Peut être null pour les requêtes publiques

        try {
            $trip = Trip::find($tripId);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            // Permettre l'accès aux images quel que soit le statut du voyage
            // Cela permet de voir les images même pour les brouillons

            $images = TripImage::where('trip_id', $tripId)
                ->orderBy('order', 'asc')
                ->orderBy('created_at', 'asc')
                ->get();

            return Response::success([
                'images' => $images->map(function ($image) {
                    return [
                        'id' => $image->id,
                        'url' => $image->image_url,
                        'thumbnail' => $image->thumbnail_url,
                        'alt_text' => $image->alt_text,
                        'is_primary' => $image->is_primary,
                        'order' => $image->order
                    ];
                })
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch trip images: ' . $e->getMessage());
        }
    }

    public function getPublicTripDetails(ServerRequestInterface $request): ResponseInterface
    {
        $tripId = (int) $request->getAttribute('id');
        
        error_log("TripController::getPublicTripDetails - Requested trip ID: $tripId");
        
        try {
            // Vérifier d'abord que l'ID est valide
            if ($tripId <= 0) {
                error_log("TripController::getPublicTripDetails - Invalid trip ID: $tripId");
                return Response::error('Invalid trip ID', [], 400);
            }
            
            $trip = Trip::with(['user', 'images', 'bookings'])
                       ->find($tripId);
                       
            if (!$trip) {
                error_log("TripController::getPublicTripDetails - Trip not found for ID: $tripId");
                return Response::notFound('Trip not found');
            }

            // Vérifier les permissions d'accès pour les voyages "in_progress"
            if ($trip->status === Trip::STATUS_IN_PROGRESS) {
                $user = $request->getAttribute('user'); // Peut être null si non authentifié
                $canAccess = false;

                if ($user) {
                    // Le propriétaire peut toujours voir son voyage
                    if ($trip->user_id == $user->id) {
                        $canAccess = true;
                    } else {
                        // Vérifier si l'utilisateur a une réservation payée pour ce voyage
                        $hasBooking = $trip->bookings()
                            ->where('user_id', $user->id)
                            ->whereIn('status', ['accepted', 'paid', 'in_transit', 'delivered', 'completed'])
                            ->exists();
                        
                        if ($hasBooking) {
                            $canAccess = true;
                        }
                    }
                }

                if (!$canAccess) {
                    error_log("TripController::getPublicTripDetails - Access denied for in_progress trip: $tripId");
                    return Response::notFound('Trip not found');
                }
            }

            // Incrémenter le compteur de vues
            try {
                $trip->increment('view_count');
                error_log("TripController::getPublicTripDetails - View count incremented for trip: $tripId");
            } catch (\Exception $viewError) {
                error_log("TripController::getPublicTripDetails - View count increment error: " . $viewError->getMessage());
            }

            error_log("TripController::getPublicTripDetails - Trip found: " . $trip->title);

            // Préparer les images de manière sécurisée
            $imageUrls = [];
            try {
                if ($trip->images && method_exists($trip->images, 'toArray')) {
                    $imagesArray = $trip->images->toArray();
                    foreach ($imagesArray as $image) {
                        if (isset($image['url']) && !empty($image['url'])) {
                            $imageUrls[] = (string) $image['url'];
                        }
                    }
                }
                error_log("TripController::getPublicTripDetails - Images processed: " . count($imageUrls));
            } catch (\Exception $imageError) {
                error_log("TripController::getPublicTripDetails - Image processing error: " . $imageError->getMessage());
                $imageUrls = [];
            }

            // Vérifier que l'utilisateur existe
            $userName = 'Utilisateur inconnu';
            $userEmail = '';
            try {
                if ($trip->user) {
                    $firstName = $trip->user->first_name ?? '';
                    $lastName = $trip->user->last_name ?? '';
                    $userName = trim($firstName . ' ' . $lastName);
                    $userEmail = $trip->user->email ?? '';
                    if (empty($userName)) {
                        $userName = 'Utilisateur inconnu';
                    }
                }
                error_log("TripController::getPublicTripDetails - User processed: $userName");
            } catch (\Exception $userError) {
                error_log("TripController::getPublicTripDetails - User processing error: " . $userError->getMessage());
                $userName = 'Utilisateur inconnu';
                $userEmail = '';
            }

            // Formater les dates de manière sécurisée
            $departureDate = null;
            $arrivalDate = null;
            try {
                if ($trip->departure_date) {
                    if (is_string($trip->departure_date)) {
                        $departureDate = $trip->departure_date;
                    } elseif (method_exists($trip->departure_date, 'format')) {
                        $departureDate = $trip->departure_date->format('Y-m-d H:i:s');
                    } else {
                        $departureDate = (string) $trip->departure_date;
                    }
                }
                if ($trip->arrival_date) {
                    if (is_string($trip->arrival_date)) {
                        $arrivalDate = $trip->arrival_date;
                    } elseif (method_exists($trip->arrival_date, 'format')) {
                        $arrivalDate = $trip->arrival_date->format('Y-m-d H:i:s');
                    } else {
                        $arrivalDate = (string) $trip->arrival_date;
                    }
                }
                error_log("TripController::getPublicTripDetails - Dates processed: $departureDate -> $arrivalDate");
            } catch (\Exception $dateError) {
                error_log("TripController::getPublicTripDetails - Date formatting error: " . $dateError->getMessage());
                $departureDate = null;
                $arrivalDate = null;
            }

            // Préparer les restrictions de manière sécurisée
            $restrictions = null;
            try {
                if ($trip->restrictions) {
                    if (is_string($trip->restrictions)) {
                        $restrictions = json_decode($trip->restrictions, true);
                    } else {
                        $restrictions = $trip->restrictions;
                    }
                }
            } catch (\Exception $restrictionsError) {
                error_log("TripController::getPublicTripDetails - Restrictions processing error: " . $restrictionsError->getMessage());
                $restrictions = null;
            }

            // Préparer les données utilisateur pour Flutter
            $userData = null;
            if ($trip->user) {
                $userData = [
                    'first_name' => $trip->user->first_name ?? '',
                    'last_name' => $trip->user->last_name ?? '',
                    'email' => $trip->user->email ?? '',
                    'profile_picture' => $trip->user->profile_picture ?? null,
                    'profile_picture_url' => $trip->user->profile_picture_url ?? null,
                    'is_verified' => (bool) ($trip->user->is_verified ?? false)
                ];
            }

            // Calculer l'espace déjà réservé
            // Utiliser les accesseurs du modèle
            $totalBookedWeight = $trip->booked_weight;
            $totalCapacityKg = ($trip->available_weight_kg ?? 0);

            $tripData = [
                'id' => (int) $trip->id,
                'uuid' => (string) ($trip->uuid ?? ''),
                'user_id' => (int) ($trip->user_id ?? 0),
                'title' => (string) ($trip->title ?? ''),
                'description' => (string) ($trip->description ?? ''),
                'departure_city' => (string) ($trip->departure_city ?? ''),
                'departure_country' => (string) ($trip->departure_country ?? ''),
                'arrival_city' => (string) ($trip->arrival_city ?? ''),
                'arrival_country' => (string) ($trip->arrival_country ?? ''),
                'departure_date' => $departureDate,
                'arrival_date' => $arrivalDate,
                'available_weight_kg' => (float) ($trip->available_weight_kg ?? 0),
                'price_per_kg' => (float) ($trip->price_per_kg ?? 0),
                'currency' => (string) ($trip->currency ?? 'EUR'),
                'status' => (string) ($trip->status ?? 'draft'),
                'transport_type' => (string) ($trip->transport_type ?? 'flight'),
                'remaining_weight' => (float) $trip->remaining_weight,
                // Nouvelles informations sur la capacité
                'total_capacity_kg' => (float) $totalCapacityKg,
                'booked_weight_kg' => (float) $totalBookedWeight,
                'booking_rate' => $totalCapacityKg > 0 ? round(($totalBookedWeight / $totalCapacityKg) * 100, 1) : 0,
                'images' => $imageUrls,
                'image_urls' => $imageUrls,
                'restrictions' => $restrictions,
                'special_notes' => $trip->special_notes ?? null,
                'is_domestic' => (bool) ($trip->is_domestic ?? false),
                'total_reward' => (float) ($trip->total_reward ?? 0),
                'view_count' => (int) ($trip->view_count ?? 0),
                // Structure utilisateur compatible Flutter
                'user' => $userData,
                // Backwards compatibility
                'user_name' => $userName,
                'user_email' => $userEmail
            ];

            error_log("TripController::getPublicTripDetails - Trip data prepared successfully for ID: $tripId");

            return Response::success(['trip' => $tripData]);
            
        } catch (\Exception $e) {
            error_log("TripController::getPublicTripDetails CRITICAL Error for ID $tripId: " . $e->getMessage());
            error_log("TripController::getPublicTripDetails CRITICAL Stack: " . $e->getTraceAsString());
            
            // Retourner une réponse JSON structurée même en cas d'erreur
            return Response::serverError('Failed to fetch trip details');
        }
    }

    public function getUserTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::with(['user', 'images', 'bookings'])
                       ->where('user_id', $user->id)
                       ->find($id);
            
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            // Debug restrictions for edit mode
            error_log("TripController::getUserTrip - Trip restrictions raw: " . json_encode($trip->restrictions));
            error_log("TripController::getUserTrip - Trip special_notes: " . json_encode($trip->special_notes));
            error_log("TripController::getUserTrip - Trip images count: " . $trip->images->count());
            error_log("TripController::getUserTrip - Trip images: " . json_encode($trip->images->toArray()));
            
            // Calculer l'espace déjà réservé
            // Utiliser les accesseurs du modèle
            $totalBookedWeight = $trip->booked_weight;
            $totalCapacityKg = ($trip->available_weight_kg ?? 0);
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'uuid' => $trip->uuid,
                    'user_id' => $trip->user_id,
                    'title' => $trip->title,
                    'description' => $trip->description,
                    'departure_city' => $trip->departure_city,
                    'departure_country' => $trip->departure_country,
                    'departure_date' => $trip->departure_date,
                    'arrival_city' => $trip->arrival_city,
                    'arrival_country' => $trip->arrival_country,
                    'arrival_date' => $trip->arrival_date,
                    'transport_type' => $trip->transport_type,
                    'available_weight_kg' => $trip->available_weight_kg,
                    'available_weight' => $trip->available_weight,
                    'price_per_kg' => $trip->price_per_kg,
                    'total_reward' => $trip->total_reward,
                    'currency' => $trip->currency,
                    'status' => $trip->status,
                    'is_domestic' => $trip->is_domestic,
                    'restrictions' => $trip->restrictions,
                    'special_notes' => $trip->special_notes,
                    'route' => $trip->route,
                    'duration' => $trip->duration,
                    'is_expired' => $trip->is_expired,
                    'user' => [
                        'id' => $trip->user->id,
                        'uuid' => $trip->user->uuid,
                        'first_name' => $trip->user->first_name,
                        'last_name' => $trip->user->last_name,
                        'profile_picture' => $trip->user->profile_picture,
                        'profile_picture_url' => $trip->user->profile_picture_url,
                        'is_verified' => $trip->user->is_verified,
                    ],
                    'images' => $trip->images->map(function ($image) {
                        return [
                            'id' => $image->id,
                            'url' => $image->image_url, // Utilise l'accesseur qui génère l'URL complète
                            'thumbnail' => $image->thumbnail_url, // Utilise l'accesseur
                            'alt_text' => $image->alt_text,
                            'is_primary' => $image->is_primary,
                            'order' => $image->order
                        ];
                    })->toArray(),
                    // URLs simples pour compatibilité Flutter
                    'image_urls' => $trip->images->pluck('image_url')->toArray(),
                    // Nouvelles informations sur la capacité
                    'total_capacity_kg' => (float) $totalCapacityKg,
                    'booked_weight_kg' => (float) $totalBookedWeight,
                    'booking_rate' => $totalCapacityKg > 0 ? round(($totalBookedWeight / $totalCapacityKg) * 100, 1) : 0,
                    'bookings_count' => $trip->bookings->count(),
                    'can_book' => false, // User's own trip, cannot book
                    'is_owner' => true,
                    'view_count' => (int) ($trip->view_count ?? 0),
                    'booking_count' => $trip->bookings->count(),
                ]
            ]);
        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch trip: ' . $e->getMessage());
        }
    }

    // === STATUS TRANSITION ACTIONS ===

    public function submitForReview(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            // Vérifier que l'utilisateur a un compte Stripe actif avant de soumettre pour approbation
            if (!$user->canPublishTrips()) {
                return Response::error(
                    'Vous devez configurer votre compte Stripe avant de soumettre un voyage pour publication. Cela permet de recevoir des paiements de manière sécurisée.',
                    [
                        'code' => 'stripe_account_required',
                        'action_required' => 'setup_stripe',
                        'stripe_setup_url' => $this->getStripeOnboardingUrl($user)
                    ],
                    403
                );
            }

            $trip->submitForReview();

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip submitted for review successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to submit for review: ' . $e->getMessage());
        }
    }

    public function approveTripAction(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        // Only admins can approve trips
        if ($user->role !== 'admin') {
            return Response::forbidden('Only administrators can approve trips');
        }

        try {
            $trip = Trip::find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            // Vérifier que le propriétaire du voyage a un compte Stripe actif
            $tripOwner = $trip->user;
            if (!$tripOwner->canPublishTrips()) {
                return Response::error(
                    'Le propriétaire de ce voyage doit configurer son compte Stripe avant que le voyage puisse être approuvé.',
                    [
                        'code' => 'stripe_account_required',
                        'trip_owner_id' => $tripOwner->id,
                        'trip_owner_email' => $tripOwner->email,
                    ],
                    403
                );
            }

            $trip->approve();

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'published_at' => $trip->published_at,
                    'expires_at' => $trip->expires_at,
                ]
            ], 'Trip approved successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to approve trip: ' . $e->getMessage());
        }
    }

    public function rejectTripAction(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);
        
        // Only admins can reject trips
        if ($user->role !== 'admin') {
            return Response::forbidden('Only administrators can reject trips');
        }
        
        try {
            $trip = Trip::find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            $reason = $data['reason'] ?? null;
            $trip->reject($reason);
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'rejection_reason' => $trip->rejection_reason,
                ]
            ], 'Trip rejected successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to reject trip: ' . $e->getMessage());
        }
    }

    public function backToDraft(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            $trip->backToDraft();
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip moved back to draft successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to move trip back to draft: ' . $e->getMessage());
        }
    }

    public function markAsBooked(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            $trip->markAsBooked();
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip marked as booked successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to mark trip as booked: ' . $e->getMessage());
        }
    }

    public function startJourney(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            $trip->startJourney();
            
            // Notifier tous les utilisateurs qui ont des réservations confirmées pour ce voyage
            $this->notifyBookedUsers($trip);
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip journey started successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to start journey: ' . $e->getMessage());
        }
    }

    public function completeDelivery(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            $trip->completeDelivery();
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip delivery completed successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to complete delivery: ' . $e->getMessage());
        }
    }

    public function reactivateTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            $trip->reactivate();
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip reactivated successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to reactivate trip: ' . $e->getMessage());
        }
    }

    public function markAsExpiredAction(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            $trip->markAsExpired();
            
            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'updated_at' => $trip->updated_at,
                ]
            ], 'Trip marked as expired successfully');
        } catch (\Exception $e) {
            return Response::error('Failed to mark trip as expired: ' . $e->getMessage());
        }
    }

    public function getAvailableActions(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $trip = Trip::where('user_id', $user->id)->find($id);
            if (!$trip) {
                return Response::notFound('Trip not found');
            }
            
            return Response::success([
                'actions' => $trip->getAvailableActions(),
                'status' => $trip->status,
            ]);
        } catch (\Exception $e) {
            return Response::error('Failed to get available actions: ' . $e->getMessage());
        }
    }

    /**
     * Notifier tous les utilisateurs qui ont des réservations confirmées pour ce voyage
     */
    private function notifyBookedUsers(Trip $trip): void
    {
        try {
            // Récupérer tous les utilisateurs avec des réservations confirmées pour ce voyage
            $bookedUsers = $trip->bookings()
                ->whereIn('status', ['accepted', 'paid', 'in_transit', 'delivered'])
                ->with('user')
                ->get()
                ->pluck('user')
                ->unique('id');

            foreach ($bookedUsers as $user) {
                if ($user && $user->id) {
                    // Envoyer notification via le service intelligent
                    $notificationService = new SmartNotificationService();
                    $notificationService->send(
                        $user->id,
                        'journey_started',
                        [
                            'trip_id' => $trip->id,
                            'trip_title' => $trip->title ?? "Voyage {$trip->departure_city} → {$trip->arrival_city}",
                            'departure_city' => $trip->departure_city,
                            'arrival_city' => $trip->arrival_city,
                            'departure_date' => $trip->departure_date,
                            'carrier_name' => $trip->user->first_name . ' ' . $trip->user->last_name,
                        ],
                        [
                            'channels' => ['push', 'in_app', 'email'], // Notification importante
                            'priority' => 'high'
                        ]
                    );
                    
                    error_log("Journey started notification sent to user {$user->id} for trip {$trip->id}");
                }
            }
        } catch (\Exception $e) {
            error_log("Error notifying booked users for trip {$trip->id}: " . $e->getMessage());
        }
    }

    /**
     * Dupliquer un voyage existant
     */
    public function duplicateTrip(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $tripId = (int) $request->getAttribute('id');

        try {
            // Récupérer le voyage original
            $originalTrip = Trip::with(['images'])->where('user_id', $user->id)->find($tripId);

            if (!$originalTrip) {
                return Response::notFound('Trip not found');
            }

            // Créer un nouveau voyage avec les données de l'original
            $newTrip = new Trip();
            $newTrip->user_id = $user->id;
            $newTrip->title = $originalTrip->title . ' (Copie)';
            $newTrip->description = $originalTrip->description;
            $newTrip->departure_city = $originalTrip->departure_city;
            $newTrip->departure_country = $originalTrip->departure_country;
            $newTrip->arrival_city = $originalTrip->arrival_city;
            $newTrip->arrival_country = $originalTrip->arrival_country;
            $newTrip->departure_date = $originalTrip->departure_date;
            $newTrip->arrival_date = $originalTrip->arrival_date;
            $newTrip->available_weight_kg = $originalTrip->available_weight_kg;
            $newTrip->price_per_kg = $originalTrip->price_per_kg;
            $newTrip->currency = $originalTrip->currency;
            $newTrip->transport_type = $originalTrip->transport_type;
            $newTrip->restrictions = $originalTrip->restrictions;
            $newTrip->special_notes = $originalTrip->special_notes;
            $newTrip->is_domestic = $originalTrip->is_domestic;
            $newTrip->status = 'draft'; // Nouveau voyage en brouillon
            $newTrip->uuid = Str::uuid();

            $newTrip->save();

            // Copier les images si elles existent
            if ($originalTrip->images && $originalTrip->images->count() > 0) {
                foreach ($originalTrip->images as $originalImage) {
                    $newImage = new TripImage();
                    $newImage->trip_id = $newTrip->id;
                    $newImage->image_path = $originalImage->image_path ?? $originalImage->url;
                    $newImage->url = $originalImage->url;
                    $newImage->thumbnail = $originalImage->thumbnail;
                    $newImage->alt_text = $originalImage->alt_text;
                    $newImage->is_primary = $originalImage->is_primary;
                    $newImage->order = $originalImage->order;
                    $newImage->image_name = $originalImage->image_name ?? 'duplicated_image';
                    $newImage->mime_type = $originalImage->mime_type ?? 'image/jpeg';
                    $newImage->save();
                }
            }

            // Recharger le voyage avec ses relations pour la réponse complète
            $newTripWithRelations = Trip::with(['user', 'images'])->find($newTrip->id);

            // Préparer les images de manière sécurisée
            $imageUrls = [];
            if ($newTripWithRelations->images) {
                foreach ($newTripWithRelations->images as $image) {
                    if (!empty($image->url)) {
                        $imageUrls[] = $image->url;
                    }
                }
            }

            return Response::created([
                'trip' => [
                    'id' => $newTripWithRelations->id,
                    'uuid' => $newTripWithRelations->uuid,
                    'user_id' => $newTripWithRelations->user_id,
                    'title' => $newTripWithRelations->title,
                    'description' => $newTripWithRelations->description ?? '',
                    'departure_city' => $newTripWithRelations->departure_city ?? '',
                    'departure_country' => $newTripWithRelations->departure_country ?? '',
                    'arrival_city' => $newTripWithRelations->arrival_city ?? '',
                    'arrival_country' => $newTripWithRelations->arrival_country ?? '',
                    'departure_date' => $newTripWithRelations->departure_date,
                    'arrival_date' => $newTripWithRelations->arrival_date,
                    'available_weight_kg' => (float) ($newTripWithRelations->available_weight_kg ?? 0),
                    'price_per_kg' => (float) ($newTripWithRelations->price_per_kg ?? 0),
                    'currency' => $newTripWithRelations->currency ?? 'EUR',
                    'status' => $newTripWithRelations->status,
                    'transport_type' => $newTripWithRelations->transport_type ?? 'flight',
                    'restrictions' => $newTripWithRelations->restrictions,
                    'special_notes' => $newTripWithRelations->special_notes ?? '',
                    'is_domestic' => (bool) ($newTripWithRelations->is_domestic ?? false),
                    'total_reward' => (float) ($newTripWithRelations->total_reward ?? 0),
                    'view_count' => (int) ($newTripWithRelations->view_count ?? 0),
                    'images' => $imageUrls,
                    'image_urls' => $imageUrls,
                    'user' => $newTripWithRelations->user ? [
                        'first_name' => $newTripWithRelations->user->first_name ?? '',
                        'last_name' => $newTripWithRelations->user->last_name ?? '',
                        'email' => $newTripWithRelations->user->email ?? '',
                        'profile_picture' => $newTripWithRelations->user->profile_picture ?? null,
                        'profile_picture_url' => $newTripWithRelations->user->profile_picture_url ?? null,
                        'is_verified' => (bool) ($newTripWithRelations->user->is_verified ?? false)
                    ] : null,
                    'created_at' => $newTripWithRelations->created_at,
                    'updated_at' => $newTripWithRelations->updated_at
                ]
            ], 'Trip duplicated successfully');

        } catch (\Exception $e) {
            error_log("TripController::duplicateTrip Error: " . $e->getMessage());
            return Response::error('Failed to duplicate trip', [], 500);
        }
    }

    /**
     * Obtenir l'URL d'onboarding Stripe pour l'utilisateur
     */
    private function getStripeOnboardingUrl(User $user): ?string
    {
        // Vérifier si l'utilisateur a déjà un compte Stripe en cours
        $stripeAccount = $user->getStripeAccount();

        if ($stripeAccount && !empty($stripeAccount->onboarding_url)) {
            return $stripeAccount->onboarding_url;
        }

        // Construire l'URL frontend pour la page Stripe setup
        $frontendUrl = $_ENV['FRONTEND_URL_PROD'] ?? 'https://kiloshare.com';
        if (($_ENV['APP_ENV'] ?? 'production') === 'development') {
            $frontendUrl = $_ENV['FRONTEND_URL_DEV'] ?? 'http://localhost:3000';
        }

        return "{$frontendUrl}/settings/stripe-setup";
    }

    /**
     * Marquer un voyage comme "en cours" (démarre le voyage)
     * POST /trips/{id}/start
     */
    public function startTrip(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $tripId = (int) $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');

            $trip = Trip::with(['bookings'])->find($tripId);

            if (!$trip) {
                return Response::notFound('Voyage non trouvé');
            }

            // Vérifier que c'est le propriétaire du voyage
            if ($trip->user_id !== $currentUser->id) {
                return Response::forbidden('Seul le propriétaire peut démarrer le voyage');
            }

            // Vérifier que le voyage est publié
            if (!in_array($trip->status, [Trip::STATUS_PUBLISHED, Trip::STATUS_ACTIVE, Trip::STATUS_BOOKED])) {
                return Response::error('Le voyage doit être publié pour être démarré', [], 400);
            }

            // Vérifier qu'il y a au moins une réservation confirmée
            $confirmedBookings = $trip->bookings()
                ->whereIn('status', [
                    Booking::STATUS_ACCEPTED,
                    Booking::STATUS_PAYMENT_AUTHORIZED,
                    Booking::STATUS_PAYMENT_CONFIRMED
                ])
                ->count();

            if ($confirmedBookings === 0) {
                return Response::error('Aucune réservation confirmée pour ce voyage', [], 400);
            }

            // Marquer le voyage comme "en cours"
            $trip->status = Trip::STATUS_IN_PROGRESS;
            $trip->save();

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'confirmed_bookings' => $confirmedBookings
                ],
                'message' => 'Voyage démarré avec succès'
            ]);

        } catch (\Exception $e) {
            error_log("TripController::startTrip Error: " . $e->getMessage());
            return Response::serverError('Erreur lors du démarrage du voyage: ' . $e->getMessage());
        }
    }

    /**
     * Compléter un voyage (vérifier que tous les codes de livraison sont validés)
     * POST /trips/{id}/complete
     */
    public function completeTrip(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $tripId = (int) $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');

            $trip = Trip::with(['bookings.deliveryCode'])->find($tripId);

            if (!$trip) {
                return Response::notFound('Voyage non trouvé');
            }

            // Vérifier que c'est le propriétaire du voyage
            if ($trip->user_id !== $currentUser->id) {
                return Response::forbidden('Seul le propriétaire peut compléter le voyage');
            }

            // Vérifier que le voyage est "en cours"
            if ($trip->status !== Trip::STATUS_IN_PROGRESS) {
                return Response::error('Le voyage doit être en cours pour être complété', [], 400);
            }

            // Récupérer toutes les réservations confirmées (y compris celles déjà complétées)
            $confirmedBookings = $trip->bookings()
                ->whereIn('status', [
                    Booking::STATUS_ACCEPTED,
                    Booking::STATUS_PAYMENT_AUTHORIZED,
                    Booking::STATUS_PAYMENT_CONFIRMED,
                    Booking::STATUS_COMPLETED  // Inclure les réservations déjà livrées
                ])
                ->get();

            if ($confirmedBookings->isEmpty()) {
                return Response::error('Aucune réservation à livrer', [], 400);
            }

            // Vérifier que TOUS les codes de livraison ont été validés
            $missingDeliveries = [];
            foreach ($confirmedBookings as $booking) {
                // Chercher un code de livraison validé pour cette réservation
                $validatedCode = \KiloShare\Models\DeliveryCode::where('booking_id', $booking->id)
                    ->where('status', \KiloShare\Models\DeliveryCode::STATUS_USED)
                    ->first();

                if (!$validatedCode) {
                    $missingDeliveries[] = [
                        'booking_id' => $booking->id,
                        'package_description' => $booking->package_description,
                        'sender_name' => $booking->sender ? $booking->sender->first_name . ' ' . $booking->sender->last_name : 'N/A'
                    ];
                }
            }

            // Si des livraisons manquent, refuser la complétion
            if (!empty($missingDeliveries)) {
                return Response::error(
                    'Impossible de compléter le voyage: certaines livraisons n\'ont pas été confirmées',
                    [
                        'missing_deliveries' => $missingDeliveries,
                        'missing_count' => count($missingDeliveries),
                        'total_bookings' => $confirmedBookings->count()
                    ],
                    400
                );
            }

            // Marquer toutes les réservations comme "livrées"
            foreach ($confirmedBookings as $booking) {
                if ($booking->status !== Booking::STATUS_COMPLETED) {
                    $booking->status = Booking::STATUS_COMPLETED;
                    $booking->save();
                }
            }

            // Marquer le voyage comme "complété"
            $trip->status = Trip::STATUS_COMPLETED;
            $trip->save();

            // TODO: Déclencher la capture des paiements ici si nécessaire
            // Le paiement devrait être capturé automatiquement lors de la validation du code

            return Response::success([
                'trip' => [
                    'id' => $trip->id,
                    'status' => $trip->status,
                    'completed_at' => $trip->updated_at->toISOString()
                ],
                'deliveries' => [
                    'total' => $confirmedBookings->count(),
                    'completed' => $confirmedBookings->count()
                ],
                'message' => 'Voyage complété avec succès! Tous les colis ont été livrés.'
            ]);

        } catch (\Exception $e) {
            error_log("TripController::completeTrip Error: " . $e->getMessage());
            error_log("Stack trace: " . $e->getTraceAsString());
            return Response::serverError('Erreur lors de la complétion du voyage: ' . $e->getMessage());
        }
    }

    /**
     * Get all bookings for a specific trip
     * GET /trips/{id}/bookings
     */
    public function getTripBookings(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $tripId = $request->getAttribute('id');
            $userId = $request->getAttribute('user_id');

            // Récupérer le voyage
            $trip = Trip::find($tripId);
            if (!$trip) {
                return Response::notFound('Voyage non trouvé');
            }

            // Vérifier que l'utilisateur est le propriétaire du voyage
            if ($trip->user_id != $userId) {
                return Response::forbidden('Vous n\'êtes pas autorisé à voir ces réservations');
            }

            // Récupérer toutes les réservations du voyage avec les relations
            $bookings = Booking::where('trip_id', $tripId)
                ->with(['sender', 'receiver'])
                ->orderBy('created_at', 'desc')
                ->get();

            return Response::success([
                'bookings' => $bookings->map(function ($booking) {
                    return [
                        'id' => $booking->id,
                        'trip_id' => $booking->trip_id,
                        'sender_id' => $booking->sender_id,
                        'receiver_id' => $booking->receiver_id,
                        'package_description' => $booking->package_description,
                        'weight_kg' => $booking->weight_kg,
                        'dimensions_cm' => $booking->dimensions_cm,
                        'total_price' => $booking->total_price,
                        'pickup_address' => $booking->pickup_address,
                        'delivery_address' => $booking->delivery_address,
                        'special_instructions' => $booking->special_instructions,
                        'status' => $booking->status,
                        'created_at' => $booking->created_at,
                        'updated_at' => $booking->updated_at,
                        'sender' => $booking->sender ? [
                            'id' => $booking->sender->id,
                            'first_name' => $booking->sender->first_name,
                            'last_name' => $booking->sender->last_name,
                            'email' => $booking->sender->email,
                        ] : null,
                        'receiver' => $booking->receiver ? [
                            'id' => $booking->receiver->id,
                            'first_name' => $booking->receiver->first_name,
                            'last_name' => $booking->receiver->last_name,
                            'email' => $booking->receiver->email,
                        ] : null,
                    ];
                }),
                'total' => $bookings->count(),
            ]);

        } catch (\Exception $e) {
            error_log("TripController::getTripBookings Error: " . $e->getMessage());
            return Response::serverError('Erreur lors de la récupération des réservations');
        }
    }
}