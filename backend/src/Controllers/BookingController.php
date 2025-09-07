<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Booking;
use KiloShare\Models\Trip;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use KiloShare\Services\CancellationService;
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
            'trip_id' => Validator::required()->intType(),
            'weight' => Validator::required()->positive(),
            'package_description' => Validator::required()->stringType()->length(5, 500),
            'pickup_address' => Validator::optional(Validator::stringType()),
            'delivery_address' => Validator::optional(Validator::stringType()),
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
                'weight_kg' => (float) $data['weight'],
                'proposed_price' => $totalPrice,
                'package_description' => $data['package_description'],
                'pickup_address' => $data['pickup_address'] ?? '',
                'delivery_address' => $data['delivery_address'] ?? '',
                'special_instructions' => ($data['pickup_notes'] ?? '') . ' ' . ($data['delivery_notes'] ?? ''),
                'pickup_date' => isset($data['requested_pickup_date']) 
                    ? Carbon::parse($data['requested_pickup_date']) : null,
                'delivery_date' => isset($data['requested_delivery_date']) 
                    ? Carbon::parse($data['requested_delivery_date']) : null,
            ]);

            return Response::created([
                'booking' => [
                    'id' => $booking->id,
                    'uuid' => $booking->uuid,
                    'status' => $booking->status,
                    'weight_kg' => $booking->weight_kg,
                    'proposed_price' => $booking->proposed_price,
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
            $query = Booking::query()->with(['trip.user', 'sender', 'receiver']);
            
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
                        'sender_id' => $booking->sender_id,
                        'receiver_id' => $booking->receiver_id,
                        'status' => $booking->status,
                        'weight_kg' => $booking->weight_kg,
                        'proposed_price' => $booking->proposed_price,
                        'final_price' => $booking->final_price,
                        'package_description' => $booking->package_description,
                        'pickup_address' => $booking->pickup_address,
                        'delivery_address' => $booking->delivery_address,
                        'special_instructions' => $booking->special_instructions,
                        'created_at' => $booking->created_at,
                        'sender' => [
                            'id' => $booking->sender->id,
                            'first_name' => $booking->sender->first_name,
                            'last_name' => $booking->sender->last_name,
                            'email' => $booking->sender->email,
                            'profile_picture' => $booking->sender->profile_picture,
                        ],
                        'receiver' => [
                            'id' => $booking->receiver->id,
                            'first_name' => $booking->receiver->first_name,
                            'last_name' => $booking->receiver->last_name,
                            'email' => $booking->receiver->email,
                            'profile_picture' => $booking->receiver->profile_picture,
                        ],
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
            $booking = Booking::with(['trip.user', 'sender', 'receiver', 'negotiation'])
                             ->find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            // Vérifier les permissions (sender ou receiver)
            if ($booking->sender_id !== $user->id && $booking->receiver_id !== $user->id) {
                return Response::forbidden('Access denied');
            }

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'uuid' => $booking->uuid,
                    'sender_id' => $booking->sender_id,
                    'receiver_id' => $booking->receiver_id,
                    'status' => $booking->status,
                    'weight_kg' => $booking->weight_kg,
                    'proposed_price' => $booking->proposed_price,
                    'final_price' => $booking->final_price,
                    'package_description' => $booking->package_description,
                    'pickup_address' => $booking->pickup_address,
                    'delivery_address' => $booking->delivery_address,
                    'special_instructions' => $booking->special_instructions,
                    'pickup_date' => $booking->pickup_date,
                    'delivery_date' => $booking->delivery_date,
                    'created_at' => $booking->created_at,
                    'updated_at' => $booking->updated_at,
                    'sender' => [
                        'id' => $booking->sender->id,
                        'first_name' => $booking->sender->first_name,
                        'last_name' => $booking->sender->last_name,
                        'email' => $booking->sender->email,
                        'profile_picture' => $booking->sender->profile_picture,
                    ],
                    'receiver' => [
                        'id' => $booking->receiver->id,
                        'first_name' => $booking->receiver->first_name,
                        'last_name' => $booking->receiver->last_name,
                        'email' => $booking->receiver->email,
                        'profile_picture' => $booking->receiver->profile_picture,
                    ],
                    'trip' => [
                        'id' => $booking->trip->id,
                        'title' => $booking->trip->title,
                        'departure_city' => $booking->trip->departure_city,
                        'arrival_city' => $booking->trip->arrival_city,
                        'departure_date' => $booking->trip->departure_date,
                        'user' => [
                            'id' => $booking->trip->user->id,
                            'first_name' => $booking->trip->user->first_name,
                            'last_name' => $booking->trip->user->last_name,
                            'profile_picture' => $booking->trip->user->profile_picture,
                        ],
                    ],
                    'negotiation' => $booking->negotiation ? [
                        'id' => $booking->negotiation->id,
                        'status' => $booking->negotiation->status,
                        'proposed_price' => $booking->negotiation->proposed_price,
                        'proposed_weight' => $booking->negotiation->proposed_weight,
                        'package_description' => $booking->negotiation->package_description,
                        'pickup_address' => $booking->negotiation->pickup_address,
                        'delivery_address' => $booking->negotiation->delivery_address,
                        'counter_offer_price' => $booking->negotiation->counter_offer_price,
                        'counter_offer_message' => $booking->negotiation->counter_offer_message,
                        'created_at' => $booking->negotiation->created_at,
                    ] : null,
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
        $data = json_decode($request->getBody()->getContents(), true);

        try {
            $booking = Booking::with('trip')->find($id);

            if (!$booking) {
                return Response::notFound('Booking not found');
            }

            if (!$booking->canBeAcceptedBy($user)) {
                return Response::forbidden('You cannot accept this booking');
            }

            // CRITICAL: Verify Stripe Connect account before acceptance
            $userStripeAccount = \KiloShare\Models\UserStripeAccount::where('user_id', $user->id)->first();
            
            if (!$userStripeAccount) {
                return Response::error(
                    'Vous devez configurer votre compte Stripe Connect pour accepter des réservations',
                    [
                        'error_code' => 'stripe_account_required',
                        'action' => 'setup_stripe',
                        'redirect_url' => '/profile/wallet'
                    ],
                    400
                );
            }

            if (!$userStripeAccount->canAcceptPayments()) {
                return Response::error(
                    'Votre compte Stripe Connect n\'est pas entièrement configuré',
                    [
                        'error_code' => 'stripe_account_incomplete', 
                        'action' => 'complete_stripe_onboarding',
                        'redirect_url' => '/profile/wallet',
                        'onboarding_url' => $userStripeAccount->onboarding_url
                    ],
                    400
                );
            }

            // Handle final price if provided (from negotiation)
            $finalPrice = isset($data['final_price']) ? (float)$data['final_price'] : null;
            
            $booking->accept($finalPrice);

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'final_price' => $booking->final_price,
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

    /**
     * Vérifie si un expéditeur peut annuler sa réservation
     */
    public function checkBookingCancellation(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $booking = Booking::find($id);
            if (!$booking) {
                return Response::notFound('Réservation non trouvée');
            }

            $cancellationService = new CancellationService();
            $result = $cancellationService->canSenderCancelBooking($user, $booking);

            $responseData = [
                'can_cancel' => $result['allowed'],
                'reason' => $result['reason'] ?? null
            ];

            if ($result['allowed']) {
                $responseData['cancellation_type'] = $result['type'];
                $responseData['refund_percentage'] = $result['refund_rate'];
                
                // Calculer les détails financiers
                if ($result['type'] === 'late_cancel') {
                    $responseData['warning'] = 'Annulation tardive: vous ne récupérerez que 50% du montant payé';
                } elseif ($result['type'] === 'early_cancel') {
                    $responseData['warning'] = 'Les frais KiloShare et Stripe seront déduits du remboursement';
                }
            }

            return Response::success($responseData);

        } catch (\Exception $e) {
            return Response::serverError('Erreur lors de la vérification: ' . $e->getMessage());
        }
    }

    /**
     * Annule une réservation avec les politiques strictes
     */
    public function cancelBooking(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $booking = Booking::find($id);
            if (!$booking) {
                return Response::notFound('Réservation non trouvée');
            }

            $cancellationService = new CancellationService();
            $result = $cancellationService->cancelBookingBySender($booking);

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'cancelled_at' => $booking->cancelled_at,
                    'cancellation_type' => $booking->cancellation_type
                ],
                'message' => $result['message'],
                'refund_percentage' => $result['refund_percentage']
            ]);

        } catch (\Exception $e) {
            return Response::badRequest($e->getMessage());
        }
    }

    /**
     * Marque une réservation comme no-show (non-présentation)
     */
    public function markAsNoShow(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');
        
        try {
            $booking = Booking::find($id);
            if (!$booking) {
                return Response::notFound('Réservation non trouvée');
            }

            // Vérifier que c'est le voyageur qui marque comme no-show
            if ($booking->trip->user_id !== $user->id) {
                return Response::forbidden('Seul le voyageur peut marquer une réservation comme no-show');
            }

            // Vérifier que la réservation est confirmée
            if ($booking->status !== Booking::STATUS_ACCEPTED) {
                return Response::badRequest('Seules les réservations confirmées peuvent être marquées comme no-show');
            }

            $cancellationService = new CancellationService();
            $cancellationService->markBookingAsNoShow($booking);

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'cancellation_type' => $booking->cancellation_type,
                    'cancelled_at' => $booking->cancelled_at
                ],
                'message' => 'Réservation marquée comme no-show. L\'expéditeur ne sera pas remboursé.'
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Erreur lors du marquage no-show: ' . $e->getMessage());
        }
    }

    /**
     * Récupère l'historique des annulations d'un expéditeur
     */
    public function getCancellationHistory(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        
        try {
            // Récupérer les réservations annulées par l'expéditeur
            $cancelledBookings = Booking::where('sender_id', $user->id)
                ->whereIn('status', [Booking::STATUS_CANCELLED])
                ->whereNotNull('cancelled_at')
                ->with(['trip'])
                ->orderBy('cancelled_at', 'desc')
                ->get();

            $history = $cancelledBookings->map(function ($booking) {
                return [
                    'booking_id' => $booking->id,
                    'trip_title' => $booking->trip->title,
                    'trip_route' => $booking->trip->departure_city . ' → ' . $booking->trip->arrival_city,
                    'cancelled_at' => $booking->cancelled_at,
                    'cancellation_type' => $booking->cancellation_type,
                    'cancellation_reason' => $booking->cancellation_reason,
                    'final_price' => $booking->final_price,
                    'refund_processed' => true // À implémenter selon le système de paiement
                ];
            });

            // Calculer des statistiques
            $stats = [
                'total_cancellations' => $cancelledBookings->count(),
                'early_cancellations' => $cancelledBookings->where('cancellation_type', 'early')->count(),
                'late_cancellations' => $cancelledBookings->where('cancellation_type', 'late')->count(),
                'no_shows' => $cancelledBookings->where('cancellation_type', 'no_show')->count()
            ];

            return Response::success([
                'history' => $history,
                'statistics' => $stats
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Erreur lors de la récupération de l\'historique: ' . $e->getMessage());
        }
    }
}