<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Models\Booking;
use KiloShare\Models\Trip;
use KiloShare\Models\User;
use KiloShare\Models\PaymentAuthorization;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use KiloShare\Services\CancellationService;
use KiloShare\Services\SmartNotificationService;
use KiloShare\Services\PaymentAuthorizationService;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Carbon\Carbon;

class BookingController
{
    private SmartNotificationService $notificationService;
    private PaymentAuthorizationService $paymentAuthService;

    public function __construct()
    {
        $this->notificationService = new SmartNotificationService();
        $this->paymentAuthService = new PaymentAuthorizationService();
    }

    public function createBookingRequest(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');

        // S'assurer que $data est un array
        $body = $request->getBody()->getContents();
        $data = [];
        if (!empty($body)) {
            $decoded = json_decode($body, true);
            $data = is_array($decoded) ? $decoded : [];
        }

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

            // Envoyer notification au propriétaire du voyage (receiver)
            $this->notificationService->send(
                $trip->user_id,
                'new_booking_request',
                [
                    'sender_name' => $user->first_name . ' ' . $user->last_name,
                    'weight' => $data['weight'],
                    'price' => $totalPrice,
                    'package_description' => $data['package_description']
                ]
            );

            // Envoyer notification au voyageur (receiver)
            $this->notificationService->send(
                $trip->user_id,
                'booking_request_received',
                [
                    'sender_name' => $user->first_name . ' ' . $user->last_name,
                    'trip_title' => $trip->title ?? 'Votre voyage',
                    'package_description' => $data['package_description'],
                    'weight_kg' => $data['weight'],
                    'proposed_price' => $booking->proposed_price,
                    'booking_id' => $booking->id
                ]
            );

            return Response::created([
                'booking' => [
                    'id' => $booking->id,
                    'uuid' => $booking->uuid,
                    'status' => $booking->status,
                    'weight_kg' => $booking->weight_kg,
                    'proposed_price' => $booking->proposed_price,
                    'created_at' => $booking->created_at,
                ]
            ], 'Demande de réservation créée avec succès');

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
            $booking = Booking::with(['trip.user', 'sender', 'receiver'])
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

            // Accepter la réservation et passer au statut payment_authorized
            $booking->accept($finalPrice);

            // Créer l'autorisation de paiement avec capture différée
            try {
                $sender = User::find($booking->sender_id);
                if (!$sender) {
                    throw new \Exception('Expéditeur non trouvé');
                }

                $authorization = $this->paymentAuthService->createAuthorization($booking, $sender);

                // Recharger le booking pour avoir les valeurs mises à jour
                $booking->refresh();
            } catch (\Exception $e) {
                // Annuler l'acceptation si l'autorisation échoue
                $booking->update(['status' => Booking::STATUS_PENDING]);

                return Response::error(
                    'Erreur lors de la création de l\'autorisation de paiement: ' . $e->getMessage(),
                    [],
                    500
                );
            }

            // Envoyer notification au sender avec instructions de confirmation
            $this->notificationService->send(
                $booking->sender_id,
                'booking_accepted_payment_pending',
                [
                    'trip_title' => $booking->trip->title ?? 'Votre voyage',
                    'total_amount' => $booking->final_price,
                    'confirmation_deadline' => '4 heures'
                ]
            );

            // Récupérer le client_secret pour l'app mobile
            $clientSecret = null;
            if ($booking->payment_authorization_id) {
                $authorization = PaymentAuthorization::find($booking->payment_authorization_id);
                if ($authorization) {
                    $clientSecret = $this->paymentAuthService->getClientSecret($authorization);
                }
            }

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'final_price' => $booking->final_price,
                    'payment_authorization_id' => $booking->payment_authorization_id,
                    'updated_at' => $booking->updated_at,
                ],
                'payment' => [
                    'client_secret' => $clientSecret,
                    'amount' => $booking->final_price,
                    'currency' => 'CAD',
                    'requires_payment_method' => !empty($clientSecret),
                ]
            ], 'Réservation acceptée avec succès. Autorisation de paiement créée.');

        } catch (\Exception $e) {
            return Response::serverError('Failed to accept booking: ' . $e->getMessage());
        }
    }

    public function rejectBooking(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        // S'assurer que $data est un array
        $body = $request->getBody()->getContents();
        $data = [];
        if (!empty($body)) {
            $decoded = json_decode($body, true);
            $data = is_array($decoded) ? $decoded : [];
        }

        // Validation des données optionnelles
        $validator = new Validator();
        $rules = [
            'reason' => Validator::optional(Validator::stringType()->length(1, 500))
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

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
            if (isset($data['reason']) && !empty(trim($data['reason']))) {
                $booking->rejection_reason = trim($data['reason']);
            }
            $booking->save();

            // Envoyer notification au sender (celui qui a fait la demande)
            $this->notificationService->send(
                $booking->sender_id,
                'booking_rejected',
                [
                    'traveler_name' => $user->first_name . ' ' . $user->last_name,
                    'trip_title' => $booking->trip->title ?? 'Le voyage'
                ]
            );

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'rejection_reason' => $booking->rejection_reason,
                    'updated_at' => $booking->updated_at,
                ]
            ], 'Booking rejected successfully');

        } catch (\Exception $e) {
            return Response::serverError('Failed to reject booking: ' . $e->getMessage());
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

        error_log("=== DÉBUT ANNULATION RÉSERVATION ===");
        error_log("User ID: " . ($user->id ?? 'null'));
        error_log("Booking ID: " . ($id ?? 'null'));

        try {
            $booking = Booking::with('trip')->find($id);
            error_log("Booking trouvée: " . ($booking ? "OUI (ID: {$booking->id}, Status: {$booking->status})" : "NON"));

            if (!$booking) {
                error_log("Erreur: Réservation non trouvée");
                return Response::notFound('Réservation non trouvée');
            }

            // Vérifications simples
            error_log("Sender ID: {$booking->sender_id}, User ID: {$user->id}");
            if ($booking->sender_id != $user->id) {
                error_log("Erreur: Utilisateur non autorisé");
                return Response::forbidden('Vous ne pouvez pas annuler cette réservation');
            }

            error_log("Statut actuel: {$booking->status}");
            if (!in_array($booking->status, [
                Booking::STATUS_PENDING,
                Booking::STATUS_ACCEPTED,
                Booking::STATUS_PAYMENT_AUTHORIZED,
                Booking::STATUS_PAYMENT_CONFIRMED,
                Booking::STATUS_PAYMENT_CANCELLED  // Permettre l'annulation même si le paiement est déjà annulé
            ])) {
                error_log("Erreur: Statut ne permet pas l'annulation");
                return Response::error('Cette réservation ne peut plus être annulée');
            }

            // Si il y a une autorisation de paiement, l'annuler
            error_log("Payment authorization ID: " . ($booking->payment_authorization_id ?? 'null'));
            if ($booking->payment_authorization_id) {
                try {
                    error_log("Début annulation autorisation paiement...");
                    $authorization = PaymentAuthorization::with(['booking.trip'])->find($booking->payment_authorization_id);
                    if ($authorization) {
                        error_log("Autorisation trouvée, appel du service...");
                        $this->paymentAuthService->cancelAuthorization($authorization, $user, 'cancelled_by_sender');
                        error_log("Autorisation annulée avec succès");
                    } else {
                        error_log("Autorisation non trouvée");
                    }
                } catch (\Exception $e) {
                    error_log("Erreur annulation autorisation paiement: " . $e->getMessage());
                    error_log("Stack trace: " . $e->getTraceAsString());
                    // Continuer avec l'annulation même si l'autorisation échoue
                }
            }

            // Annulation de la réservation
            error_log("Mise à jour du statut de la réservation...");
            $booking->status = Booking::STATUS_CANCELLED;
            $booking->save();
            error_log("Statut mis à jour avec succès");

            // Notification au transporteur
            error_log("Envoi de notification...");
            try {
                $notificationData = [
                    'sender_name' => $user->first_name . ' ' . $user->last_name,
                    'trip_title' => $booking->trip->title ?? 'Voyage',
                    'booking_id' => $booking->id
                ];

                // Vérifier que le receiver_id existe avant d'envoyer la notification
                error_log("Receiver ID: " . ($booking->receiver_id ?? 'null'));
                if ($booking->receiver_id) {
                    error_log("Envoi notification au receiver...");
                    $this->notificationService->send(
                        $booking->receiver_id,
                        'booking_cancelled',
                        $notificationData
                    );
                    error_log("Notification envoyée avec succès");
                } else {
                    error_log("Pas de receiver_id pour la réservation {$booking->id}");
                }
            } catch (\Exception $notifException) {
                error_log("Erreur notification: " . $notifException->getMessage());
                // Continue même si la notification échoue
            }

            error_log("Retour de la réponse de succès...");
            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status
                ],
                'message' => 'Réservation annulée avec succès'
            ]);

        } catch (\Exception $e) {
            error_log("=== ERREUR COMPLÈTE ANNULATION ===");
            error_log("Message: " . $e->getMessage());
            error_log("Fichier: " . $e->getFile() . ":" . $e->getLine());
            error_log("Trace: " . $e->getTraceAsString());
            return Response::error('Erreur lors de l\'annulation de la réservation: ' . $e->getMessage());
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

    /**
     * Confirmer le paiement - l'expéditeur confirme qu'il accepte les conditions
     */
    public function getPaymentDetails(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $booking = Booking::find($id);
            if (!$booking) {
                return Response::notFound('Réservation non trouvée');
            }

            // Vérifier que c'est l'expéditeur
            if ($booking->sender_id !== $user->id) {
                return Response::forbidden('Seul l\'expéditeur peut obtenir les détails de paiement');
            }

            // Vérifier qu'il y a une autorisation de paiement
            if (!$booking->payment_authorization_id) {
                return Response::error('Aucune autorisation de paiement trouvée');
            }

            $authorization = PaymentAuthorization::find($booking->payment_authorization_id);
            if (!$authorization) {
                return Response::error('Autorisation de paiement non trouvée');
            }

            // Obtenir le client_secret
            $clientSecret = $this->paymentAuthService->getClientSecret($authorization);
            if (!$clientSecret) {
                return Response::error('Impossible d\'obtenir le client_secret. Vérifiez que l\'autorisation est valide.');
            }

            return Response::success([
                'client_secret' => $clientSecret,
                'payment_intent_id' => $authorization->payment_intent_id,
                'amount' => $authorization->getAmountInDollars(),
                'currency' => $authorization->currency,
                'authorization_id' => $authorization->id,
            ]);

        } catch (\Exception $e) {
            return Response::error('Erreur lors de la récupération des détails de paiement: ' . $e->getMessage());
        }
    }

    public function confirmPayment(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $booking = Booking::with('trip')->find($id);
            if (!$booking) {
                return Response::notFound('Réservation non trouvée');
            }

            // Vérifier que c'est l'expéditeur
            if ($booking->sender_id != $user->id) {
                return Response::forbidden('Vous ne pouvez pas confirmer cette réservation');
            }

            // Vérifier le statut - doit être payment_authorized, accepted, ou cancelled avec autorisation
            $validStatuses = [Booking::STATUS_PAYMENT_AUTHORIZED, Booking::STATUS_ACCEPTED, Booking::STATUS_CANCELLED];
            if (!in_array($booking->status, $validStatuses) && !$booking->payment_authorization_id) {
                return Response::error('Cette réservation n\'est pas en attente de confirmation de paiement (statut: ' . $booking->status . ')');
            }

            // Vérifier ou créer l'autorisation de paiement si manquante
            if (!$booking->payment_authorization_id) {
                // Si c'est une réservation acceptée sans autorisation, la créer maintenant
                if ($booking->status === Booking::STATUS_ACCEPTED || $booking->status === Booking::STATUS_CANCELLED) {
                    try {
                        $sender = User::find($booking->sender_id);
                        if (!$sender) {
                            return Response::error('Expéditeur non trouvé');
                        }

                        $authorization = $this->paymentAuthService->createAuthorization($booking, $sender);
                        $booking->refresh(); // Recharger pour avoir le payment_authorization_id

                        if (!$booking->payment_authorization_id) {
                            return Response::error('Impossible de créer l\'autorisation de paiement');
                        }
                    } catch (\Exception $e) {
                        return Response::error('Erreur lors de la création de l\'autorisation: ' . $e->getMessage());
                    }
                } else {
                    return Response::error('Aucune autorisation de paiement trouvée pour cette réservation');
                }
            }

            // Vérifier que le payment_status permet la confirmation
            if (in_array($booking->payment_status, ['paid', 'captured', 'confirmed'])) {
                return Response::error('Cette réservation a déjà été payée');
            }

            // Récupérer l'autorisation de paiement
            $authorization = PaymentAuthorization::find($booking->payment_authorization_id);
            if (!$authorization) {
                return Response::error('Autorisation de paiement non trouvée');
            }

            // Confirmer l'autorisation de paiement
            try {
                $user = $request->getAttribute('user');
                $confirmed = $this->paymentAuthService->confirmAuthorization($authorization, $user);

                if (!$confirmed) {
                    return Response::error('Impossible de confirmer l\'autorisation de paiement');
                }
            } catch (\Exception $e) {
                return Response::error(
                    'Erreur lors de la confirmation du paiement: ' . $e->getMessage()
                );
            }

            // Mettre à jour le statut de la réservation
            $booking->update(['status' => Booking::STATUS_PAYMENT_CONFIRMED]);

            // Envoyer notification au transporteur
            $this->notificationService->send(
                $booking->receiver_id,
                'payment_confirmed',
                [
                    'sender_name' => $user->first_name . ' ' . $user->last_name,
                    'trip_title' => $booking->trip->title ?? 'Votre voyage',
                    'total_amount' => $booking->final_price
                ]
            );

            return Response::success([
                'booking' => [
                    'id' => $booking->id,
                    'status' => $booking->status,
                    'updated_at' => $booking->updated_at,
                ]
            ], 'Paiement confirmé avec succès. Le montant sera capturé automatiquement.');

        } catch (\Exception $e) {
            return Response::serverError('Erreur lors de la confirmation du paiement: ' . $e->getMessage());
        }
    }

    /**
     * Capturer le paiement manuellement (par le transporteur ou admin)
     */
    public function capturePayment(ServerRequestInterface $request): ResponseInterface
    {
        // DÉSACTIVÉ: La capture manuelle a été remplacée par la capture automatique
        // lors de la validation du code secret de livraison
        return Response::error([
            'error' => 'La capture manuelle des paiements a été désactivée.',
            'message' => 'Le paiement sera automatiquement capturé lors de la validation du code secret de livraison.',
            'disabled_feature' => true
        ], 410); // HTTP 410 Gone - Feature no longer available
    }

    /**
     * Obtenir le statut de l'autorisation de paiement
     */
    public function getPaymentStatus(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $id = $request->getAttribute('id');

        try {
            $booking = Booking::find($id);
            if (!$booking) {
                return Response::notFound('Réservation non trouvée');
            }

            // Vérifier que l'utilisateur a accès à cette réservation
            if ($booking->sender_id != $user->id && $booking->receiver_id != $user->id) {
                return Response::forbidden('Vous n\'avez pas accès à cette réservation');
            }

            if (!$booking->payment_authorization_id) {
                return Response::success([
                    'payment_status' => 'no_authorization',
                    'booking_status' => $booking->status
                ]);
            }

            // Obtenir les détails de l'autorisation
            $authDetails = $this->paymentAuthService->getPaymentAuthorizationDetails(
                $booking->payment_authorization_id
            );

            return Response::success([
                'payment_status' => $authDetails['success'] ? $authDetails['authorization'] : null,
                'booking_status' => $booking->status
            ]);

        } catch (\Exception $e) {
            return Response::serverError('Erreur lors de la récupération du statut: ' . $e->getMessage());
        }
    }
}