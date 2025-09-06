<?php

declare(strict_types=1);

namespace KiloShare\Controllers;

use KiloShare\Services\SimpleTrackingService;
use KiloShare\Utils\Response;
use KiloShare\Utils\Validator;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;

class TrackingController
{
    private SimpleTrackingService $trackingService;

    public function __construct()
    {
        $this->trackingService = new SimpleTrackingService();
    }

    /**
     * Confirmer la récupération du colis
     */
    public function confirmPickup(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'booking_id' => Validator::required()->intType(),
            'photo_url' => Validator::required()->stringType(),
            'pickup_code' => Validator::optional(Validator::stringType()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $result = $this->trackingService->confirmPickup(
                $data['booking_id'],
                $user->id,
                $data['photo_url'],
                $data['pickup_code'] ?? null
            );

            if ($result['success']) {
                return Response::success([
                    'status' => $result['status']
                ], $result['message']);
            } else {
                return Response::error($result['message']);
            }

        } catch (\Exception $e) {
            return Response::serverError('Pickup confirmation failed: ' . $e->getMessage());
        }
    }

    /**
     * Démarrer le trajet
     */
    public function startRoute(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'booking_id' => Validator::required()->intType(),
            'latitude' => Validator::optional(Validator::floatType()),
            'longitude' => Validator::optional(Validator::floatType()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $result = $this->trackingService->startRoute(
                $data['booking_id'],
                $user->id,
                $data['latitude'] ?? null,
                $data['longitude'] ?? null
            );

            if ($result['success']) {
                return Response::success([
                    'status' => $result['status']
                ], $result['message']);
            } else {
                return Response::error($result['message']);
            }

        } catch (\Exception $e) {
            return Response::serverError('Start route failed: ' . $e->getMessage());
        }
    }

    /**
     * Confirmer la livraison
     */
    public function confirmDelivery(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'booking_id' => Validator::required()->intType(),
            'photo_url' => Validator::required()->stringType(),
            'delivery_code' => Validator::optional(Validator::stringType()),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $result = $this->trackingService->confirmDelivery(
                $data['booking_id'],
                $user->id,
                $data['photo_url'],
                $data['delivery_code'] ?? null
            );

            if ($result['success']) {
                return Response::success([
                    'status' => $result['status']
                ], $result['message']);
            } else {
                return Response::error($result['message']);
            }

        } catch (\Exception $e) {
            return Response::serverError('Delivery confirmation failed: ' . $e->getMessage());
        }
    }

    /**
     * Signaler un problème
     */
    public function reportIssue(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'booking_id' => Validator::required()->intType(),
            'issue_type' => Validator::required()->in(['late_pickup', 'late_delivery', 'damaged_package', 'communication_issue', 'payment_issue', 'other']),
            'description' => Validator::required()->stringType()->length(10, 500),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $result = $this->trackingService->reportIssue(
                $data['booking_id'],
                $user->id,
                $data['issue_type'],
                $data['description']
            );

            if ($result['success']) {
                return Response::success([], $result['message']);
            } else {
                return Response::error($result['message']);
            }

        } catch (\Exception $e) {
            return Response::serverError('Issue report failed: ' . $e->getMessage());
        }
    }

    /**
     * Obtenir le statut de tracking
     */
    public function getTrackingStatus(ServerRequestInterface $request): ResponseInterface
    {
        $bookingId = (int) $request->getAttribute('booking_id');
        $user = $request->getAttribute('user');

        if (!$bookingId) {
            return Response::error('Booking ID is required');
        }

        try {
            $result = $this->trackingService->getTrackingStatus($bookingId);

            if ($result['success']) {
                // Vérifier que l'utilisateur a le droit de voir ce tracking
                $booking = $result['booking'];
                if ($booking['sender_id'] !== $user->id && $booking['carrier_id'] !== $user->id) {
                    return Response::unauthorized('Access denied to this booking');
                }

                return Response::success([
                    'booking_id' => $bookingId,
                    'status' => $result['current_status'],
                    'progress_steps' => $result['progress_steps'],
                    'events' => $result['events'],
                    'booking_details' => [
                        'pickup_address' => $booking['pickup_address'],
                        'delivery_address' => $booking['delivery_address'],
                        'pickup_photo_url' => $booking['pickup_photo_url'],
                        'delivery_photo_url' => $booking['delivery_photo_url']
                    ]
                ]);
            } else {
                return Response::error($result['message']);
            }

        } catch (\Exception $e) {
            return Response::serverError('Get tracking status failed: ' . $e->getMessage());
        }
    }

    /**
     * Créer une évaluation après livraison
     */
    public function createReview(ServerRequestInterface $request): ResponseInterface
    {
        $user = $request->getAttribute('user');
        $data = json_decode($request->getBody()->getContents(), true);

        $validator = new Validator();
        $rules = [
            'booking_id' => Validator::required()->intType(),
            'rating' => Validator::required()->intType()->between(1, 5),
            'comment' => Validator::optional(Validator::stringType()->length(5, 500)),
        ];

        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }

        try {
            $db = \KiloShare\Database\Connection::getInstance();
            
            // Vérifier que le booking existe et est livré
            $stmt = $db->prepare("
                SELECT sender_id, carrier_id, status 
                FROM bookings 
                WHERE id = ?
            ");
            $stmt->execute([$data['booking_id']]);
            $booking = $stmt->fetch();

            if (!$booking) {
                return Response::error('Booking not found');
            }

            if ($booking['status'] !== 'delivered') {
                return Response::error('Can only review after delivery');
            }

            // Déterminer qui est évalué
            $reviewedId = ($booking['sender_id'] === $user->id) ? $booking['carrier_id'] : $booking['sender_id'];

            if ($booking['sender_id'] !== $user->id && $booking['carrier_id'] !== $user->id) {
                return Response::unauthorized('Access denied');
            }

            // Créer l'évaluation
            $stmt = $db->prepare("
                INSERT INTO booking_reviews (booking_id, reviewer_id, reviewed_id, rating, comment)
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE rating = VALUES(rating), comment = VALUES(comment)
            ");
            $stmt->execute([
                $data['booking_id'],
                $user->id,
                $reviewedId,
                $data['rating'],
                $data['comment'] ?? null
            ]);

            return Response::success([], 'Review submitted successfully');

        } catch (\Exception $e) {
            return Response::serverError('Review creation failed: ' . $e->getMessage());
        }
    }
}