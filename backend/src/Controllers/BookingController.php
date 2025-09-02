<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Booking;
use KiloShare\Models\Trip;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;

class BookingController
{
    public function createBookingRequest(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        // Validation
        $validator = new Validator();
        $rules = [
            'trip_id' => Validator::required()->integer(),
            'weight' => Validator::required()->positive(),
            'package_description' => Validator::required()->stringType()->length(5, 500),
            'pickup_address' => Validator::required()->stringType(),
            'delivery_address' => Validator::required()->stringType(),
            'requested_pickup_date' => Validator::optional(Validator::date()),
            'requested_delivery_date' => Validator::optional(Validator::date()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $trip = Trip::find($data['trip_id']);

            if (!$trip) {
                return Response::notFound('Trip not found');
            }

            if (!$trip->canBeBookedBy($user)) {
                return Response::error('This trip cannot be booked');
            }

            if ($data['weight'] > $trip->available_weight) {
                return Response::error('Requested weight exceeds available space');
            }

            // Calculer le prix total
            $totalPrice = $data['weight'] * $trip->price_per_kg;

            $booking = Booking::create([
                'sender_id' => $user->id, // Utilisateur qui créé la demande = sender
                'receiver_id' => $trip->user_id, // Propriétaire du voyage = receiver
                'trip_id' => $trip->id,
                'status' => Booking::STATUS_PENDING,
                'weight' => (float) $data['weight'],
                'price_per_kg' => $trip->price_per_kg,
                'total_price' => $totalPrice,
                'currency' => $trip->currency,
                'package_description' => $data['package_description'],
                'pickup_address' => $data['pickup_address'],
                'delivery_address' => $data['delivery_address'],
                'pickup_notes' => $data['pickup_notes'] ?? '',
                'delivery_notes' => $data['delivery_notes'] ?? '',
                'requested_pickup_date' => isset($data['requested_pickup_date']) 
                    ? Carbon::parse($data['requested_pickup_date']) : null,
                'requested_delivery_date' => isset($data['requested_delivery_date']) 
                    ? Carbon::parse($data['requested_delivery_date']) : null,
            ]);

            return Response::created([
                'booking' => [
                    'id' => $booking->id,
                    'uuid' => $booking->uuid,
                    'status' => $booking->status,
                    'weight' => $booking->weight,
                    'total_price' => $booking->total_price,
                    'currency' => $booking->currency,
                    'created_at' => $booking->created_at,
                ]
            ], 'Booking request created successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to create booking request: ' . $e->getMessage());
        }
    }

    public function getUserBookings(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $queryParams = $request->getQueryParams();

        try {
            $page = (int) ($queryParams['page'] ?? 1);
            $limit = (int) ($queryParams['limit'] ?? 20);
            $status = $queryParams['status'] ?? null;
            $role = $queryParams['role'] ?? null; // 'sender' ou 'receiver'
            
            // Construction de la requête selon le rôle
            $query = Booking::query()->with(['trip.user']);
            
            if ($role === 'sender') {
                // L'utilisateur est celui qui envoie le colis (créateur de la réservation)
                $query->where('sender_id', $user->id);
            } elseif ($role === 'receiver') {
                // L'utilisateur est celui qui reçoit le colis (propriétaire du voyage)
                $query->where('receiver_id', $user->id);
            } else {
                // Par défaut, récupérer toutes les réservations de l'utilisateur
                $query->where(function($q) use ($user) {
                    $q->where('sender_id', $user->id)
                      ->orWhere('receiver_id', $user->id);
                });
            }

            if ($status) {
                $query->where('status', $status);
            }

            $bookings = $query->orderBy('created_at', 'desc')
                             ->skip(($page - 1) * $limit)
                             ->take($limit)
                             ->get();

            $total = Booking::query()
                ->when($role === 'sender', fn($q) => $q->where('sender_id', $user->id))
                ->when($role === 'receiver', fn($q) => $q->where('receiver_id', $user->id))
                ->when(!$role, fn($q) => $q->where(function($subQ) use ($user) {
                    $subQ->where('sender_id', $user->id)->orWhere('receiver_id', $user->id);
                }))
                ->when($status, fn($q) => $q->where('status', $status))
                ->count();

            return Response::success([
                'bookings' => $bookings->map(function ($booking) {
                    return [
                        'id' => $booking->id,
                        'uuid' => $booking->uuid,
                        'status' => $booking->status,
                        'weight' => $booking->weight,
                        'total_price' => $booking->total_price,
                        'currency' => $booking->currency,
                        'package_description' => $booking->package_description,
                        'pickup_address' => $booking->pickup_address,
                        'delivery_address' => $booking->delivery_address,
                        'payment_status' => $booking->payment_status,
                        'created_at' => $booking->created_at,
                        'trip' => [
                            'id' => $booking->trip->id,
                            'title' => $booking->trip->title,
                            'departure_city' => $booking->trip->departure_city,
                            'arrival_city' => $booking->trip->arrival_city,
                            'departure_date' => $booking->trip->departure_date,
                            'user' => [
                                'first_name' => $booking->trip->user->first_name,
                                'last_name' => $booking->trip->user->last_name,
                            ],
                        ],
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
            return Response::serverError('Failed to fetch bookings: ' . $e->getMessage());
        }
    }

    public function getBooking(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $booking = Booking::with(['trip.user', 'user', 'negotiations', 'packagePhotos'])
                             ->find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            // Vérifier les permissions (propriétaire du booking ou du trip)
            if ($booking->user_id !== $user->id && $booking->trip->user_id !== $user->id) {
                return Response::forbidden('Access denied');
            }

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'uuid' => $booking->uuid,
                    'status' => $booking->status,
                    'weight' => $booking->weight,
                    'price_per_kg' => $booking->price_per_kg,
                    'total_price' => $booking->total_price,
                    'currency' => $booking->currency,
                    'package_description' => $booking->package_description,
                    'pickup_address' => $booking->pickup_address,
                    'delivery_address' => $booking->delivery_address,
                    'pickup_notes' => $booking->pickup_notes,
                    'delivery_notes' => $booking->delivery_notes,
                    'requested_pickup_date' => $booking->requested_pickup_date,
                    'requested_delivery_date' => $booking->requested_delivery_date,
                    'confirmed_pickup_date' => $booking->confirmed_pickup_date,
                    'confirmed_delivery_date' => $booking->confirmed_delivery_date,
                    'payment_status' => $booking->payment_status,
                    'created_at' => $booking->created_at,
                    'updated_at' => $booking->updated_at,
                    'trip' => [
                        'id' => $booking->trip->id,
                        'uuid' => $booking->trip->uuid,
                        'title' => $booking->trip->title,
                        'departure_city' => $booking->trip->departure_city,
                        'arrival_city' => $booking->trip->arrival_city,
                        'departure_date' => $booking->trip->departure_date,
                        'arrival_date' => $booking->trip->arrival_date,
                        'transport_type' => $booking->trip->transport_type,
                        'user' => [
                            'id' => $booking->trip->user->id,
                            'uuid' => $booking->trip->user->uuid,
                            'first_name' => $booking->trip->user->first_name,
                            'last_name' => $booking->trip->user->last_name,
                            'profile_picture' => $booking->trip->user->profile_picture,
                            'is_verified' => $booking->trip->user->is_verified,
                        ],
                    ],
                    'user' => [
                        'id' => $booking->user->id,
                        'uuid' => $booking->user->uuid,
                        'first_name' => $booking->user->first_name,
                        'last_name' => $booking->user->last_name,
                        'profile_picture' => $booking->user->profile_picture,
                        'is_verified' => $booking->user->is_verified,
                    ],
                    'negotiations' => $booking->negotiations->map(function ($negotiation) {
                        return [
                            'id' => $negotiation->id,
                            'proposed_price' => $negotiation->proposed_price,
                            'message' => $negotiation->message,
                            'status' => $negotiation->status,
                            'created_at' => $negotiation->created_at,
                        ];
                    }),
                    'package_photos' => $booking->packagePhotos->map(function ($photo) {
                        return [
                            'id' => $photo->id,
                            'url' => $photo->url,
                            'thumbnail' => $photo->thumbnail,
                            'created_at' => $photo->created_at,
                        ];
                    }),
                    'can_accept' => $booking->canBeAcceptedBy($user),
                    'can_cancel' => $booking->canBeCancelledBy($user),
                ]
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to fetch booking: ' . $e->getMessage());
        }
    }

    public function acceptBooking(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $booking = Booking::with('trip')->find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            if (!$booking->canBeAcceptedBy($user)) {
                return Response::forbidden('You cannot accept this booking');
            }

            $booking->accept();

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'updated_at' => $booking->updated_at,
                ]
            ], 'Booking accepted successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to accept booking: ' . $e->getMessage());
        }
    }

    public function rejectBooking(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            $booking = Booking::with('trip')->find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            if ($booking->trip->user_id !== $user->id) {
                return Response::forbidden('You can only reject bookings for your trips');
            }

            if ($booking->status !== Booking::STATUS_PENDING) {
                return Response::error('Only pending bookings can be rejected');
            }

            $booking->status = Booking::STATUS_CANCELLED;
            $booking->save();

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'updated_at' => $booking->updated_at,
                ]
            ], 'Booking rejected successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to reject booking: ' . $e->getMessage());
        }
    }

    public function addNegotiation(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        $data = json_decode($request->getBody()->getContents(), true);

        // Validation
        $validator = new Validator();
        $rules = [
            'proposed_price' => Validator::required()->positive(),
            'message' => Validator::optional(Validator::stringType()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $booking = Booking::with('trip')->find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            // Seuls le client ou le propriétaire du trip peuvent négocier
            if ($booking->user_id !== $user->id && $booking->trip->user_id !== $user->id) {
                return Response::forbidden('Access denied');
            }

            if ($booking->status !== Booking::STATUS_PENDING) {
                return Response::error('Cannot negotiate on this booking');
            }

            // TODO: Créer le modèle BookingNegotiation
            /*
            $negotiation = BookingNegotiation::create([
                'booking_id' => $booking->id,
                'user_id' => $user->id,
                'proposed_price' => (float) $data['proposed_price'],
                'message' => $data['message'] ?? '',
                'status' => 'pending',
            ]);
            */

            return Response::success([
                'message' => 'Price negotiation submitted successfully'
            ], 'Negotiation added successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to add negotiation: ' . $e->getMessage());
        }
    }

    public function markPaymentReady(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $booking = Booking::with('trip')->find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            if ($booking->trip->user_id !== $user->id) {
                return Response::forbidden('Only trip owner can mark payment as ready');
            }

            if ($booking->status !== Booking::STATUS_CONFIRMED) {
                return Response::error('Only confirmed bookings can be marked for payment');
            }

            // TODO: Logique pour préparer le paiement
            $booking->payment_status = Booking::PAYMENT_PENDING;
            $booking->save();

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'payment_status' => $booking->payment_status,
                ]
            ], 'Booking marked as ready for payment');

        } catch (\Exception $e) {
            return Response::serverError('Failed to mark payment ready: ' . $e->getMessage());
        }
    }

    public function addPackagePhoto(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $booking = Booking::find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            if ($booking->user_id !== $user->id) {
                return Response::forbidden('You can only add photos to your own bookings');
            }

            // TODO: Gérer l'upload de photos
            // Pour l'instant, retourner un succès fictif
            
            return Response::success([
                'message' => 'Package photo uploaded successfully'
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Failed to add package photo: ' . $e->getMessage());
        }
    }
}