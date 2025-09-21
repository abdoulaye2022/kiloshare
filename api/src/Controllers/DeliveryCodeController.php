<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use KiloShare\Models\Booking;
use KiloShare\Models\DeliveryCode;
use KiloShare\Services\DeliveryCodeService;
use KiloShare\Services\CloudinaryService;
use Respect\Validation\Validator;
use Exception;

class DeliveryCodeController extends BaseController
{
    private DeliveryCodeService $deliveryCodeService;
    private CloudinaryService $cloudinaryService;

    public function __construct(
        DeliveryCodeService $deliveryCodeService,
        CloudinaryService $cloudinaryService
    ) {
        $this->deliveryCodeService = $deliveryCodeService;
        $this->cloudinaryService = $cloudinaryService;
    }

    /**
     * Génère un code de livraison pour une réservation
     * POST /bookings/{id}/delivery-code/generate
     */
    public function generateDeliveryCode(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $bookingId = $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');

            // Récupérer la réservation
            $booking = Booking::with(['sender', 'receiver', 'trip'])->find($bookingId);

            if (!$booking) {
                return $this->respondNotFound('Réservation non trouvée');
            }

            // Vérifier les permissions (propriétaire du voyage uniquement)
            if ($booking->receiver_id !== $currentUser->id) {
                return $this->respondForbidden('Seul le transporteur peut générer un code de livraison');
            }

            // Vérifier que la réservation est confirmée
            if ($booking->status !== Booking::STATUS_ACCEPTED) {
                return $this->respondBadRequest('La réservation doit être confirmée pour générer un code');
            }

            // Générer le code
            $deliveryCode = $this->deliveryCodeService->generateDeliveryCode($booking);

            return $this->respondSuccess([
                'delivery_code' => [
                    'id' => $deliveryCode->id,
                    'booking_id' => $deliveryCode->booking_id,
                    'status' => $deliveryCode->status,
                    'generated_at' => $deliveryCode->generated_at->toISOString(),
                    'expires_at' => $deliveryCode->expires_at?->toISOString(),
                    'max_attempts' => $deliveryCode->max_attempts,
                    'attempts_count' => $deliveryCode->attempts_count,
                ],
                'message' => 'Code de livraison généré et envoyé à l\'expéditeur'
            ]);

        } catch (Exception $e) {
            return $this->respondError($e->getMessage());
        }
    }

    /**
     * Valide un code de livraison saisi par l'utilisateur
     * POST /bookings/{id}/delivery-code/validate
     */
    public function validateDeliveryCode(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $bookingId = $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');
            $data = json_decode($request->getBody()->getContents(), true);

            // Validation des données
            $validator = new Validator();
            $rules = [
                'code' => $validator->notEmpty()->stringType()->length(6, 6),
                'latitude' => $validator->optional($validator->numericVal()),
                'longitude' => $validator->optional($validator->numericVal()),
                'photos' => $validator->optional($validator->arrayType()),
            ];

            $this->validateInput($data, $rules);

            // Récupérer la réservation
            $booking = Booking::with(['sender', 'receiver', 'trip'])->find($bookingId);

            if (!$booking) {
                return $this->respondNotFound('Réservation non trouvée');
            }

            // Traitement des photos si fournies
            $photos = [];
            if (!empty($data['photos']) && is_array($data['photos'])) {
                foreach ($data['photos'] as $photoBase64) {
                    if (!empty($photoBase64)) {
                        $uploadResult = $this->cloudinaryService->uploadBase64Image(
                            $photoBase64,
                            'delivery_confirmations',
                            [
                                'booking_id' => $booking->id,
                                'user_id' => $currentUser->id,
                                'timestamp' => time(),
                            ]
                        );

                        if ($uploadResult['success']) {
                            $photos[] = [
                                'url' => $uploadResult['url'],
                                'public_id' => $uploadResult['public_id'],
                                'uploaded_at' => now()->toISOString(),
                            ];
                        }
                    }
                }
            }

            // Valider le code
            $result = $this->deliveryCodeService->validateDeliveryCode(
                $booking,
                $data['code'],
                $currentUser,
                $data['latitude'] ?? null,
                $data['longitude'] ?? null,
                $photos
            );

            if ($result['success']) {
                return $this->respondSuccess([
                    'message' => $result['message'],
                    'booking_status' => $booking->fresh()->status,
                    'delivery_confirmed_at' => $booking->fresh()->delivery_confirmed_at?->toISOString(),
                    'photos_uploaded' => count($photos),
                ]);
            } else {
                return $this->respondBadRequest($result['error'], [
                    'attempts_remaining' => $result['attempts_remaining'] ?? 0,
                ]);
            }

        } catch (Exception $e) {
            return $this->respondError($e->getMessage());
        }
    }

    /**
     * Régénère un code de livraison (en cas de perte)
     * POST /bookings/{id}/delivery-code/regenerate
     */
    public function regenerateDeliveryCode(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $bookingId = $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');
            $data = json_decode($request->getBody()->getContents(), true);

            // Validation optionnelle de la raison
            if (isset($data['reason'])) {
                $validator = new Validator();
                $this->validateInput($data, [
                    'reason' => $validator->optional($validator->stringType()->length(1, 255)),
                ]);
            }

            // Récupérer la réservation
            $booking = Booking::with(['sender', 'receiver', 'trip'])->find($bookingId);

            if (!$booking) {
                return $this->respondNotFound('Réservation non trouvée');
            }

            // Régénérer le code
            $newDeliveryCode = $this->deliveryCodeService->regenerateDeliveryCode(
                $booking,
                $currentUser,
                $data['reason'] ?? 'Code perdu - régénération demandée'
            );

            return $this->respondSuccess([
                'delivery_code' => [
                    'id' => $newDeliveryCode->id,
                    'booking_id' => $newDeliveryCode->booking_id,
                    'status' => $newDeliveryCode->status,
                    'generated_at' => $newDeliveryCode->generated_at->toISOString(),
                    'expires_at' => $newDeliveryCode->expires_at?->toISOString(),
                    'max_attempts' => $newDeliveryCode->max_attempts,
                    'attempts_count' => $newDeliveryCode->attempts_count,
                ],
                'message' => 'Nouveau code de livraison généré et envoyé'
            ]);

        } catch (Exception $e) {
            return $this->respondError($e->getMessage());
        }
    }

    /**
     * Récupère les informations du code de livraison pour une réservation
     * GET /bookings/{id}/delivery-code
     */
    public function getDeliveryCode(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $bookingId = $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');

            // Récupérer la réservation
            $booking = Booking::with(['sender', 'receiver', 'trip'])->find($bookingId);

            if (!$booking) {
                return $this->respondNotFound('Réservation non trouvée');
            }

            // Vérifier les permissions
            if ($booking->sender_id !== $currentUser->id && $booking->receiver_id !== $currentUser->id) {
                return $this->respondForbidden('Accès non autorisé');
            }

            // Récupérer le code actif
            $deliveryCode = $this->deliveryCodeService->getActiveDeliveryCode($booking);

            if (!$deliveryCode) {
                return $this->respondNotFound('Aucun code de livraison actif');
            }

            // Préparer la réponse selon le rôle de l'utilisateur
            $response = [
                'delivery_code' => [
                    'id' => $deliveryCode->id,
                    'booking_id' => $deliveryCode->booking_id,
                    'status' => $deliveryCode->status,
                    'generated_at' => $deliveryCode->generated_at->toISOString(),
                    'expires_at' => $deliveryCode->expires_at?->toISOString(),
                    'max_attempts' => $deliveryCode->max_attempts,
                    'attempts_count' => $deliveryCode->attempts_count,
                    'remaining_attempts' => $deliveryCode->remaining_attempts,
                    'is_valid' => $deliveryCode->is_valid,
                    'is_expired' => $deliveryCode->is_expired,
                ],
                'booking' => [
                    'id' => $booking->id,
                    'uuid' => $booking->uuid,
                    'status' => $booking->status,
                    'package_description' => $booking->package_description,
                    'delivery_confirmed_at' => $booking->delivery_confirmed_at?->toISOString(),
                    'trip' => [
                        'departure_city' => $booking->trip->departure_city,
                        'arrival_city' => $booking->trip->arrival_city,
                        'arrival_date' => $booking->trip->arrival_date->toISOString(),
                    ],
                ],
            ];

            // Seul l'expéditeur peut voir le code réel
            if ($currentUser->id === $booking->sender_id) {
                $response['delivery_code']['code'] = $deliveryCode->code;
                $response['is_sender'] = true;
            } else {
                $response['is_sender'] = false;
                // Le destinataire ne voit pas le code, seulement qu'il existe
                $response['message'] = 'Code de livraison requis pour cette réservation';
            }

            return $this->respondSuccess($response);

        } catch (Exception $e) {
            return $this->respondError($e->getMessage());
        }
    }

    /**
     * Récupère l'historique des tentatives pour un code de livraison
     * GET /bookings/{id}/delivery-code/attempts
     */
    public function getDeliveryCodeAttempts(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $bookingId = $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');

            // Récupérer la réservation
            $booking = Booking::find($bookingId);

            if (!$booking) {
                return $this->respondNotFound('Réservation non trouvée');
            }

            // Vérifier les permissions (propriétaires uniquement)
            if ($booking->sender_id !== $currentUser->id && $booking->receiver_id !== $currentUser->id) {
                return $this->respondForbidden('Accès non autorisé');
            }

            // Récupérer le code de livraison et ses tentatives
            $deliveryCode = DeliveryCode::with(['attempts.user'])
                ->where('booking_id', $booking->id)
                ->where('status', DeliveryCode::STATUS_ACTIVE)
                ->first();

            if (!$deliveryCode) {
                return $this->respondNotFound('Aucun code de livraison actif');
            }

            $attempts = $deliveryCode->attempts()
                ->orderBy('attempted_at', 'desc')
                ->get()
                ->map(function ($attempt) {
                    return [
                        'id' => $attempt->id,
                        'user' => [
                            'id' => $attempt->user->id,
                            'name' => $attempt->user->first_name . ' ' . $attempt->user->last_name,
                        ],
                        'success' => $attempt->success,
                        'error_message' => $attempt->error_message,
                        'has_location' => $attempt->hasLocation(),
                        'attempted_at' => $attempt->attempted_at->toISOString(),
                    ];
                });

            return $this->respondSuccess([
                'attempts' => $attempts,
                'total_attempts' => $attempts->count(),
                'successful_attempts' => $attempts->where('success', true)->count(),
                'remaining_attempts' => $deliveryCode->remaining_attempts,
            ]);

        } catch (Exception $e) {
            return $this->respondError($e->getMessage());
        }
    }

    /**
     * Vérifie si une réservation nécessite un code de livraison
     * GET /bookings/{id}/delivery-code/required
     */
    public function checkDeliveryCodeRequired(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $bookingId = $request->getAttribute('id');
            $currentUser = $request->getAttribute('user');

            // Récupérer la réservation
            $booking = Booking::with(['trip'])->find($bookingId);

            if (!$booking) {
                return $this->respondNotFound('Réservation non trouvée');
            }

            // Vérifier les permissions
            if ($booking->sender_id !== $currentUser->id && $booking->receiver_id !== $currentUser->id) {
                return $this->respondForbidden('Accès non autorisé');
            }

            $required = $this->deliveryCodeService->requiresDeliveryCode($booking);
            $activeCode = $this->deliveryCodeService->getActiveDeliveryCode($booking);

            return $this->respondSuccess([
                'required' => $required,
                'has_active_code' => $activeCode !== null,
                'booking_status' => $booking->status,
                'delivery_confirmed' => $booking->delivery_confirmed_at !== null,
                'trip' => [
                    'arrival_date' => $booking->trip->arrival_date->toISOString(),
                    'has_arrived' => $booking->trip->arrival_date->isPast(),
                ],
            ]);

        } catch (Exception $e) {
            return $this->respondError($e->getMessage());
        }
    }

    /**
     * Statistiques des codes de livraison (admin uniquement)
     * GET /admin/delivery-codes/stats
     */
    public function getDeliveryCodeStats(ServerRequestInterface $request): ResponseInterface
    {
        try {
            $currentUser = $request->getAttribute('user');

            // Vérifier les permissions admin
            if (!$currentUser->isAdmin()) {
                return $this->respondForbidden('Accès réservé aux administrateurs');
            }

            $queryParams = $request->getQueryParams();
            $days = (int) ($queryParams['days'] ?? 30);

            $stats = $this->deliveryCodeService->getDeliveryCodeStats($days);

            return $this->respondSuccess([
                'stats' => $stats,
                'period_days' => $days,
                'generated_at' => now()->toISOString(),
            ]);

        } catch (Exception $e) {
            return $this->respondError($e->getMessage());
        }
    }
}