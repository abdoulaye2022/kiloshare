<?php

namespace App\Modules\Trips\Controllers;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use App\Modules\Trips\Services\TripService;
use App\Modules\Trips\Services\TripImageService;
use KiloShare\Services\CloudinaryService;
use Psr\Log\LoggerInterface;
use PDO;
use Exception;

class TripController
{
    private TripService $tripService;
    private TripImageService $tripImageService;
    private CloudinaryService $cloudinaryService;
    private LoggerInterface $logger;
    private PDO $db;

    public function __construct(TripService $tripService, TripImageService $tripImageService, CloudinaryService $cloudinaryService, LoggerInterface $logger, PDO $db)
    {
        $this->tripService = $tripService;
        $this->tripImageService = $tripImageService;
        $this->cloudinaryService = $cloudinaryService;
        $this->logger = $logger;
        $this->db = $db;
    }

    private function jsonResponse(Response $response, array $data, int $status = 200): Response
    {
        $response->getBody()->write(json_encode($data));
        return $response->withStatus($status)->withHeader('Content-Type', 'application/json');
    }

    private function success(Response $response, array $data = []): Response
    {
        return $this->jsonResponse($response, array_merge(['success' => true], $data));
    }

    private function error(Response $response, string $message, int $status = 500): Response
    {
        return $this->jsonResponse($response, [
            'success' => false,
            'message' => $message
        ], $status);
    }

    /**
     * Create a new trip
     * POST /api/trips/create
     */
    public function create(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            if (!$user) {
                return $this->error($response, 'Authentication required', 401);
            }
            
            $data = json_decode($request->getBody()->getContents(), true);
            if (!$data) {
                return $this->error($response, 'Invalid JSON data');
            }
            
            // Validate required fields
            $requiredFields = [
                'departure_city', 'departure_country', 'departure_date',
                'arrival_city', 'arrival_country', 'arrival_date',
                'available_weight_kg', 'price_per_kg'
            ];
            
            foreach ($requiredFields as $field) {
                if (empty($data[$field])) {
                    return $this->error($response, "Field '$field' is required");
                }
            }
            
            $trip = $this->tripService->createTrip($data, $user['id']);
            
            return $this->success($response, [
                'trip' => $trip->toJson(),
                'message' => 'Trip created successfully'
            ], 201);
            
        } catch (Exception $e) {
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get user's trips
     * GET /api/trips/list
     */
    public function list(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            if (!$user) {
                return $this->error($response, 'Authentication required', 401);
            }
            
            $queryParams = $request->getQueryParams();
            $page = max(1, (int) ($queryParams['page'] ?? 1));
            $limit = min(50, max(10, (int) ($queryParams['limit'] ?? 20)));
            
            $trips = $this->tripService->getUserTrips($user['id'], $page, $limit);
            
            $tripsData = [];
            foreach ($trips as $trip) {
                $tripsData[] = $trip->toJson();
            }
            
            return $this->success($response, [
                'trips' => $tripsData,
                'pagination' => [
                    'page' => $page,
                    'limit' => $limit,
                    'has_more' => count($trips) === $limit
                ]
            ]);
            
        } catch (Exception $e) {
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get trip details
     * GET /api/trips/{id}
     */
    public function get(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = $args['id']; // Keep as string to handle both IDs and UUIDs
            
            // Try to get by UUID first, then by numeric ID
            $trip = null;
            if (!is_numeric($tripId)) {
                // If it's not numeric, try UUID lookup
                $trip = $this->tripService->getTripByUuid($tripId);
            } else {
                // If it's numeric, try ID lookup first, then UUID fallback
                $trip = $this->tripService->getTripById((int) $tripId);
                if (!$trip) {
                    $trip = $this->tripService->getTripByUuid($tripId);
                }
            }
            
            if (!$trip) {
                return $this->error($response, 'Trip not found', 404);
            }
            
            $user = $request->getAttribute('user');
            $isOwner = $user && ($user['id'] === $trip->getUserId());
            
            // If user is the owner, allow access to their trip regardless of status
            if ($isOwner) {
                // Owner can see their own trips in any status
            }
            // If not owner (authenticated or not), only allow access to approved and active/published trips
            else {
                $allowedStatuses = ['active', 'published'];
                // Trip must be approved AND have an allowed status to be publicly visible
                if (!$trip->getIsApproved() || !in_array($trip->getStatus(), $allowedStatuses)) {
                    return $this->error($response, 'Trip not found', 404);
                }
            }
            
            // Record view for analytics (if not the owner)
            if (!$user || $user['id'] !== $trip->getUserId()) {
                $viewerId = $user['id'] ?? null;
                $ip = $_SERVER['REMOTE_ADDR'] ?? null;
                $this->tripService->recordView($trip->getId(), $viewerId, $ip);
            }
            
            return $this->success($response, [
                'trip' => $trip->toJson()
            ]);
            
        } catch (Exception $e) {
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Update a trip
     * PUT /api/trips/{id}/update
     */
    public function update(Request $request, Response $response, array $args): Response
    {
        try {
            $user = $request->getAttribute('user');
            if (!$user) {
                return $this->error($response, 'Authentication required', 401);
            }
            
            $tripId = (int) $args['id'];
            $data = json_decode($request->getBody()->getContents(), true);
            if (!$data) {
                return $this->error($response, 'Invalid JSON data');
            }
            
            $trip = $this->tripService->updateTrip($tripId, $data, $user['id']);
            
            return $this->success($response, [
                'trip' => $trip->toJson(),
                'message' => 'Trip updated successfully'
            ]);
            
        } catch (Exception $e) {
            if (strpos($e->getMessage(), 'not found') !== false) {
                return $this->error($response, $e->getMessage());
            }
            if (strpos($e->getMessage(), 'Not authorized') !== false) {
                return $this->error($response, $e->getMessage());
            }
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Delete a trip
     * DELETE /api/trips/{id}/delete
     */
    public function delete(Request $request, Response $response, array $args): Response
    {
        try {
            $user = $request->getAttribute('user');
            if (!$user) {
                return $this->error($response, 'Authentication required', 401);
            }
            
            $tripId = (int) $args['id'];
            $this->tripService->deleteTrip($tripId, $user['id']);
            
            return $this->success($response, [
                'message' => 'Trip deleted successfully'
            ]);
            
        } catch (Exception $e) {
            if (strpos($e->getMessage(), 'not found') !== false) {
                return $this->error($response, $e->getMessage());
            }
            if (strpos($e->getMessage(), 'Not authorized') !== false) {
                return $this->error($response, $e->getMessage());
            }
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Search trips
     * GET /api/trips/search
     */
    public function search(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            $page = max(1, (int) ($queryParams['page'] ?? 1));
            $limit = min(50, max(10, (int) ($queryParams['limit'] ?? 20)));
            
            // Build filters
            $filters = [];
            $allowedFilters = [
                'departure_city', 'arrival_city', 'departure_country', 'arrival_country',
                'departure_date_from', 'departure_date_to', 'min_weight', 'max_price_per_kg',
                'currency', 'verified_only', 'ticket_verified'
            ];
            
            foreach ($allowedFilters as $filter) {
                if (isset($queryParams[$filter]) && $queryParams[$filter] !== '') {
                    if (in_array($filter, ['verified_only', 'ticket_verified'])) {
                        $filters[$filter] = (bool) $queryParams[$filter];
                    } else {
                        $filters[$filter] = $queryParams[$filter];
                    }
                }
            }
            
            $trips = $this->tripService->searchTrips($filters, $page, $limit);
            
            return $this->success($response, [
                'trips' => $trips,
                'filters' => $filters,
                'pagination' => [
                    'page' => $page,
                    'limit' => $limit,
                    'has_more' => count($trips) === $limit
                ]
            ]);
            
        } catch (Exception $e) {
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Validate ticket (optional)
     * POST /api/trips/{id}/validate-ticket
     */
    public function validateTicket(Request $request, Response $response, array $args): Response
    {
        try {
            $user = $request->getAttribute('user');
            if (!$user) {
                return $this->error($response, 'Authentication required', 401);
            }
            
            $tripId = (int) $args['id'];
            $data = json_decode($request->getBody()->getContents(), true);
            if (!$data) {
                return $this->error($response, 'Invalid JSON data');
            }
            
            $trip = $this->tripService->validateTicket($tripId, $data, $user['id']);
            
            return $this->success($response, [
                'trip' => $trip->toJson(),
                'message' => 'Ticket validated successfully'
            ]);
            
        } catch (Exception $e) {
            if (strpos($e->getMessage(), 'not found') !== false) {
                return $this->error($response, $e->getMessage());
            }
            if (strpos($e->getMessage(), 'Not authorized') !== false) {
                return $this->error($response, $e->getMessage());
            }
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get suggested price for a route
     * GET /api/trips/price-suggestion
     */
    public function getPriceSuggestion(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            
            $requiredParams = ['departure_city', 'departure_country', 'arrival_city', 'arrival_country'];
            foreach ($requiredParams as $param) {
                if (empty($queryParams[$param])) {
                    return $this->error($response, "Parameter '$param' is required");
                }
            }
            
            $currency = $queryParams['currency'] ?? 'EUR';
            
            $priceData = $this->tripService->getSuggestedPrice(
                $queryParams['departure_city'],
                $queryParams['departure_country'],
                $queryParams['arrival_city'],
                $queryParams['arrival_country'],
                $currency
            );
            
            return $this->success($response, [
                'price_suggestion' => $priceData
            ]);
            
        } catch (Exception $e) {
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get price breakdown
     * GET /api/trips/price-breakdown
     */
    public function getPriceBreakdown(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            
            $pricePerKg = (float) ($queryParams['price_per_kg'] ?? 0);
            $weightKg = (float) ($queryParams['weight_kg'] ?? 0);
            $currency = $queryParams['currency'] ?? 'EUR';
            
            if ($pricePerKg <= 0 || $weightKg <= 0) {
                return $this->error($response, 'Price per kg and weight must be greater than 0');
            }
            
            $breakdown = $this->tripService->getPriceBreakdown($pricePerKg, $weightKg, $currency);
            
            return $this->success($response, [
                'breakdown' => $breakdown
            ]);
            
        } catch (Exception $e) {
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get pending trips for admin review
     * GET /api/v1/admin/trips/pending
     */
    public function getPendingTrips(Request $request, Response $response): Response
    {
        try {
            $trips = $this->tripService->getPendingTrips();
            
            return $this->success($response, [
                'trips' => $trips
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to get pending trips: ' . $e->getMessage());
            return $this->error($response, 'Failed to get pending trips');
        }
    }

    /**
     * Approve a trip
     * POST /api/v1/admin/trips/{id}/approve
     */
    public function approveTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $adminUser = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $trip = $this->tripService->approveTrip($tripId, $adminUser['id']);
            
            return $this->success($response, [
                'message' => 'Trip approved successfully',
                'trip' => $trip
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to approve trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Reject a trip
     * POST /api/v1/admin/trips/{id}/reject
     */
    public function rejectTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $adminUser = $request->getAttribute('user');
            $data = $request->getParsedBody() ?? [];
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $reason = $data['reason'] ?? 'No reason provided';
            $trip = $this->tripService->rejectTrip($tripId, $adminUser['id'], $reason);
            
            return $this->success($response, [
                'message' => 'Trip rejected successfully',
                'trip' => $trip
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to reject trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Pause a trip
     * POST /api/v1/trips/{id}/pause
     */
    public function pauseTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody() ?? [];
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $reason = $data['reason'] ?? null;
            $trip = $this->tripService->pauseTrip($tripId, $user['id'], $reason);
            
            return $this->success($response, [
                'message' => 'Trip paused successfully',
                'trip' => $trip->toJson()
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to pause trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Resume a trip
     * POST /api/v1/trips/{id}/resume
     */
    public function resumeTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $trip = $this->tripService->resumeTrip($tripId, $user['id']);
            
            return $this->success($response, [
                'message' => 'Trip resumed successfully',
                'trip' => $trip->toJson()
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to resume trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Cancel a trip
     * POST /api/v1/trips/{id}/cancel
     */
    public function cancelTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody() ?? [];
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $reason = $data['reason'] ?? null;
            $details = $data['details'] ?? null;
            $trip = $this->tripService->cancelTrip($tripId, $user['id'], $reason, $details);
            
            return $this->success($response, [
                'message' => 'Trip cancelled successfully',
                'trip' => $trip->toJson()
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to cancel trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Complete a trip
     * POST /api/v1/trips/{id}/complete
     */
    public function completeTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $trip = $this->tripService->completeTrip($tripId, $user['id']);
            
            return $this->success($response, [
                'message' => 'Trip completed successfully',
                'trip' => $trip->toJson()
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to complete trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Publish trip
     * POST /api/v1/trips/{id}/publish
     */
    public function publishTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            error_log("TripController: Publishing trip ID: $tripId for user: " . $user['id']);
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $trip = $this->tripService->publishTrip($tripId, $user['id']);
            
            error_log("TripController: Trip service returned: " . ($trip ? 'Trip object' : 'null'));
            
            if (!$trip) {
                return $this->error($response, 'Failed to publish trip: service returned null', 500);
            }
            
            $tripJson = $trip->toJson();
            error_log("TripController: Trip toJson() returned: " . ($tripJson ? 'Array' : 'null'));
            
            return $this->success($response, [
                'message' => 'Trip published successfully',
                'trip' => $tripJson
            ]);
            
        } catch (Exception $e) {
            error_log('TripController: Exception in publishTrip: ' . $e->getMessage());
            $this->logger->error('Failed to publish trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Add trip to favorites
     * POST /api/v1/trips/{id}/favorite
     */
    public function addToFavorites(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $this->tripService->addToFavorites($tripId, $user['id']);
            
            return $this->success($response, [
                'message' => 'Trip added to favorites successfully'
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to add to favorites: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Remove trip from favorites
     * DELETE /api/v1/trips/{id}/favorite
     */
    public function removeFromFavorites(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $this->tripService->removeFromFavorites($tripId, $user['id']);
            
            return $this->success($response, [
                'message' => 'Trip removed from favorites successfully'
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to remove from favorites: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Report trip
     * POST /api/v1/trips/{id}/report
     */
    public function reportTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            $data = $request->getParsedBody() ?? [];
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $reportType = $data['report_type'] ?? null;
            $description = $data['description'] ?? null;

            if (!$reportType) {
                return $this->error($response, 'Report type is required', 400);
            }

            $this->tripService->reportTrip($tripId, $user['id'], $reportType, $description);
            
            return $this->success($response, [
                'message' => 'Trip reported successfully'
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to report trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Share trip
     * POST /api/v1/trips/{id}/share
     */
    public function shareTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $result = $this->tripService->shareTrip($tripId, $user['id']);
            
            return $this->success($response, [
                'message' => 'Trip shared successfully',
                'share_url' => $result['share_url']
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to share trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get trip analytics
     * GET /api/v1/trips/{id}/analytics
     */
    public function getTripAnalytics(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $analytics = $this->tripService->getTripAnalytics($tripId, $user['id']);
            
            return $this->success($response, [
                'analytics' => $analytics
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to get trip analytics: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Duplicate a trip
     * POST /api/v1/trips/{id}/duplicate
     */
    public function duplicateTrip(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            $newTrip = $this->tripService->duplicateTrip($tripId, $user['id']);
            
            return $this->success($response, [
                'message' => 'Trip duplicated successfully',
                'trip' => $newTrip->toJson()
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to duplicate trip: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get user drafts
     * GET /api/v1/trips/drafts
     */
    public function getUserDrafts(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            if (!$user) {
                return $this->error($response, 'Authentication required', 401);
            }

            $queryParams = $request->getQueryParams();
            $page = max(1, (int) ($queryParams['page'] ?? 1));
            $limit = min(50, max(10, (int) ($queryParams['limit'] ?? 20)));

            $drafts = $this->tripService->getUserDrafts($user['id'], $page, $limit);
            
            
            // Convert Trip objects to arrays for JSON response
            $draftsArray = [];
            foreach ($drafts as $draft) {
                if (method_exists($draft, 'toArray')) {
                    $draftsArray[] = $draft->toArray();
                } else {
                    $draftsArray[] = $draft; // fallback if it's already an array
                }
            }
            
            return $this->success($response, [
                'trips' => $draftsArray,
                'pagination' => [
                    'page' => $page,
                    'limit' => $limit,
                    'has_more' => count($drafts) === $limit
                ]
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to get user drafts: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get user favorites
     * GET /api/v1/trips/favorites
     */
    public function getUserFavorites(Request $request, Response $response): Response
    {
        try {
            $user = $request->getAttribute('user');
            if (!$user) {
                return $this->error($response, 'Authentication required', 401);
            }

            $queryParams = $request->getQueryParams();
            $page = max(1, (int) ($queryParams['page'] ?? 1));
            $limit = min(50, max(10, (int) ($queryParams['limit'] ?? 20)));

            $favorites = $this->tripService->getUserFavorites($user['id'], $page, $limit);
            
            return $this->success($response, [
                'trips' => $favorites,
                'pagination' => [
                    'page' => $page,
                    'limit' => $limit,
                    'has_more' => count($favorites) === $limit
                ]
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to get user favorites: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    public function getPublicTrips(Request $request, Response $response): Response
    {
        try {
            $queryParams = $request->getQueryParams();
            $limit = min(50, max(1, (int) ($queryParams['limit'] ?? 10)));
            
            $trips = $this->tripService->getPublicTrips($limit);
            
            return $this->success($response, [
                'trips' => $trips,
                'count' => count($trips)
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to get public trips: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Upload images for a trip using Cloudinary
     * POST /api/v1/trips/{id}/images
     */
    public function uploadTripImages(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $user = $request->getAttribute('user');
            $userId = is_array($user) && isset($user['id']) ? (int)$user['id'] : null;
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            if (!$userId) {
                return $this->error($response, 'User authentication required', 401);
            }

            // Verify trip ownership
            $trip = $this->tripService->getTripById($tripId);
            if (!$trip || $trip->getUserId() != $userId) {
                return $this->error($response, 'Trip not found or access denied', 404);
            }

            // Get uploaded files
            $uploadedFiles = $request->getUploadedFiles();
            if (empty($uploadedFiles) || !isset($uploadedFiles['images'])) {
                return $this->error($response, 'No images uploaded', 400);
            }

            $images = $uploadedFiles['images'];
            if (!is_array($images)) {
                $images = [$images];
            }

            // Filter valid uploads
            $validImages = [];
            foreach ($images as $uploadedFile) {
                if ($uploadedFile->getError() === UPLOAD_ERR_OK) {
                    $validImages[] = $uploadedFile;
                }
            }

            if (empty($validImages)) {
                return $this->error($response, 'No valid images to upload', 400);
            }

            // Limit to 5 photos per trip
            if (count($validImages) > 5) {
                return $this->error($response, 'Maximum 5 photos per trip', 400);
            }

            $this->logger->info('[TripController] Upload trip photos via Cloudinary', [
                'user_id' => $userId,
                'trip_id' => $tripId,
                'photo_count' => count($validImages)
            ]);

            // Upload to Cloudinary using the new service
            $result = $this->cloudinaryService->uploadMultipleImages(
                $validImages,
                'trip_photo',
                $userId,
                [
                    'related_entity_type' => 'trip',
                    'related_entity_id' => $tripId,
                    'additional_tags' => ['trip_' . $tripId, 'travel', 'user_' . $userId]
                ]
            );

            $successfulUploads = array_filter($result['results'], function($r) {
                return $r['success'] === true;
            });

            // Format response to match mobile expectations
            $uploadedImages = array_map(function($upload, $index) use ($tripId) {
                return [
                    'id' => $upload['local_data']['id'],
                    'trip_id' => $tripId,
                    'image_path' => '', // Not used with Cloudinary
                    'image_name' => basename($upload['cloudinary_data']['public_id']),
                    'image_url' => $upload['cloudinary_data']['secure_url'],
                    'file_size' => $upload['cloudinary_data']['bytes'],
                    'formatted_file_size' => $this->formatBytes($upload['cloudinary_data']['bytes']),
                    'mime_type' => 'image/' . $upload['cloudinary_data']['format'],
                    'upload_order' => $index + 1,
                    'created_at' => date('Y-m-d H:i:s'),
                    'updated_at' => date('Y-m-d H:i:s'),
                ];
            }, $successfulUploads, array_keys($successfulUploads));
            
            return $this->success($response, [
                'message' => 'Images uploaded successfully to Cloudinary',
                'images' => $uploadedImages,
                'summary' => $result['summary']
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('[TripController] Failed to upload trip images to Cloudinary: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Get images for a trip (from Cloudinary)
     * GET /api/v1/trips/{id}/images
     */
    public function getTripImages(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            
            if (!$tripId) {
                return $this->error($response, 'Trip ID is required', 400);
            }

            // Get images from Cloudinary image_uploads table
            $stmt = $this->db->prepare("
                SELECT * FROM image_uploads 
                WHERE image_type = 'trip_photo' 
                AND related_entity_type = 'trip' 
                AND related_entity_id = ? 
                AND deleted_at IS NULL
                ORDER BY created_at ASC
            ");
            $stmt->execute([$tripId]);
            $cloudinaryImages = $stmt->fetchAll(\PDO::FETCH_ASSOC);

            // Format images to match mobile expectations
            $imagesArray = array_map(function($img, $index) {
                return [
                    'id' => $img['id'],
                    'trip_id' => $img['related_entity_id'],
                    'image_path' => '', // Not used with Cloudinary
                    'image_name' => basename($img['cloudinary_public_id']),
                    'image_url' => $img['cloudinary_secure_url'],
                    'file_size' => $img['file_size'],
                    'formatted_file_size' => $this->formatBytes($img['file_size']),
                    'mime_type' => 'image/' . $img['format'],
                    'upload_order' => $index + 1,
                    'created_at' => $img['created_at'],
                    'updated_at' => $img['updated_at'],
                ];
            }, $cloudinaryImages, array_keys($cloudinaryImages));
            
            return $this->success($response, [
                'images' => $imagesArray
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('[TripController] Failed to get trip images from Cloudinary: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Delete a trip image
     * DELETE /api/v1/trips/{id}/images/{imageId}
     */
    public function deleteTripImage(Request $request, Response $response, array $args): Response
    {
        try {
            $tripId = (int) $args['id'];
            $imageId = (int) $args['imageId'];
            $user = $request->getAttribute('user');
            
            if (!$tripId || !$imageId) {
                return $this->error($response, 'Trip ID and Image ID are required', 400);
            }

            // Verify trip ownership
            $trip = $this->tripService->getTripById($tripId);
            if (!$trip || $trip->getUserId() != $user['id']) {
                return $this->error($response, 'Trip not found or access denied', 404);
            }

            $this->tripImageService->deleteTripImage($tripId, $imageId);
            
            return $this->success($response, [
                'message' => 'Image deleted successfully'
            ]);
            
        } catch (Exception $e) {
            $this->logger->error('Failed to delete trip image: ' . $e->getMessage());
            return $this->error($response, $e->getMessage());
        }
    }

    /**
     * Format bytes to human readable format
     */
    private function formatBytes(int $bytes): string
    {
        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $power = $bytes > 0 ? floor(log($bytes, 1024)) : 0;
        return number_format($bytes / pow(1024, $power), 2, '.', '') . ' ' . $units[$power];
    }
}