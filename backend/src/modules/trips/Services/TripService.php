<?php

namespace App\Modules\Trips\Services;

use App\Modules\Trips\Models\Trip;
use App\Modules\Trips\Models\TripImage;
use App\Modules\Trips\Services\TripImageService;
use PDO;
use Exception;

class TripService
{
    private PDO $db;
    private PriceCalculatorService $priceCalculator;
    private TripImageService $tripImageService;

    public function __construct(PriceCalculatorService $priceCalculator, PDO $db)
    {
        $this->db = $db;
        $this->priceCalculator = $priceCalculator;
        $this->tripImageService = new TripImageService($db);
    }

    /**
     * Create a new trip
     */
    public function createTrip(array $data, int $userId): Trip
    {
        // Generate UUID
        $uuid = $this->generateUuid();
        $data['uuid'] = $uuid;
        $data['user_id'] = $userId;
        
        // Create trip object and validate
        $trip = new Trip($data);
        $errors = $trip->validate();
        
        if (!empty($errors)) {
            throw new Exception('Validation failed: ' . implode(', ', $errors));
        }
        
        try {
            $this->db->beginTransaction();
            
            // Insert trip
            $stmt = $this->db->prepare("
                INSERT INTO trips (
                    uuid, user_id, departure_city, departure_country, departure_airport_code, departure_date,
                    arrival_city, arrival_country, arrival_airport_code, arrival_date,
                    available_weight_kg, price_per_kg, currency, flight_number, airline,
                    description, special_notes, status
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");
            
            $stmt->execute([
                $trip->getUuid(),
                $trip->getUserId(),
                $trip->getDepartureCity(),
                $trip->getDepartureCountry(),
                $trip->getDepartureAirportCode(),
                $this->formatDateTimeForDB($trip->getDepartureDate()),
                $trip->getArrivalCity(),
                $trip->getArrivalCountry(),
                $trip->getArrivalAirportCode(),
                $this->formatDateTimeForDB($trip->getArrivalDate()),
                $trip->getAvailableWeightKg(),
                $trip->getPricePerKg(),
                $trip->getCurrency(),
                $trip->getFlightNumber(),
                $trip->getAirline(),
                $trip->getDescription(),
                $trip->getSpecialNotes(),
                $trip->getStatus()
            ]);
            
            $tripId = $this->db->lastInsertId();
            $trip->setId($tripId);
            
            // Insert restrictions if provided
            if (isset($data['restricted_categories']) || isset($data['restricted_items'])) {
                $this->saveRestrictions($tripId, $data);
            }
            
            $this->db->commit();
            
            // Fetch the complete trip with timestamps
            return $this->getTripById($tripId);
            
        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to create trip: ' . $e->getMessage());
        }
    }

    /**
     * Get trip by ID
     */
    public function getTripById(int $id): ?Trip
    {
        $stmt = $this->db->prepare("
            SELECT t.id, t.uuid, t.user_id, 
                   t.departure_city, t.departure_country, t.departure_airport_code, t.departure_date,
                   t.arrival_city, t.arrival_country, t.arrival_airport_code, t.arrival_date,
                   t.available_weight_kg, t.price_per_kg, t.currency,
                   t.flight_number, t.airline, t.ticket_verified, t.ticket_verification_date,
                   t.status, t.is_approved, t.view_count, t.booking_count,
                   t.description, t.special_notes,
                   t.created_at, t.updated_at, t.published_at,
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes
            FROM trips t
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            WHERE t.id = ? AND t.deleted_at IS NULL
        ");
        
        $stmt->execute([$id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$result) {
            return null;
        }
        
        // Parse JSON fields safely
        if ($result['restricted_categories'] && $result['restricted_categories'] !== 'null') {
            $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
        } else {
            $result['restricted_categories'] = null;
        }
        
        if ($result['restricted_items'] && $result['restricted_items'] !== 'null') {
            $result['restricted_items'] = json_decode($result['restricted_items'], true);
        } else {
            $result['restricted_items'] = null;
        }
        
        $trip = new Trip($result);
        
        // Load images
        return $this->loadTripImages($trip);
    }

    /**
     * Get trip by UUID
     */
    public function getTripByUuid(string $uuid): ?Trip
    {
        $stmt = $this->db->prepare("
            SELECT t.id, t.uuid, t.user_id, 
                   t.departure_city, t.departure_country, t.departure_airport_code, t.departure_date,
                   t.arrival_city, t.arrival_country, t.arrival_airport_code, t.arrival_date,
                   t.available_weight_kg, t.price_per_kg, t.currency,
                   t.flight_number, t.airline, t.ticket_verified, t.ticket_verification_date,
                   t.status, t.is_approved, t.view_count, t.booking_count,
                   t.description, t.special_notes,
                   t.created_at, t.updated_at, t.published_at,
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes
            FROM trips t
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            WHERE t.uuid = ? AND t.deleted_at IS NULL
        ");
        
        $stmt->execute([$uuid]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$result) {
            return null;
        }
        
        // Parse JSON fields safely
        if ($result['restricted_categories'] && $result['restricted_categories'] !== 'null') {
            $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
        } else {
            $result['restricted_categories'] = null;
        }
        
        if ($result['restricted_items'] && $result['restricted_items'] !== 'null') {
            $result['restricted_items'] = json_decode($result['restricted_items'], true);
        } else {
            $result['restricted_items'] = null;
        }
        
        return new Trip($result);
    }

    /**
     * Get trips for a user
     */
    public function getUserTrips(int $userId, int $page = 1, int $limit = 20): array
    {
        error_log("[TripService] getUserTrips called for user $userId");
        $offset = ($page - 1) * $limit;
        
        $stmt = $this->db->prepare("
            SELECT t.id, t.uuid, t.user_id, 
                   t.departure_city, t.departure_country, t.departure_airport_code, t.departure_date,
                   t.arrival_city, t.arrival_country, t.arrival_airport_code, t.arrival_date,
                   t.available_weight_kg, t.price_per_kg, t.currency,
                   t.flight_number, t.airline, t.ticket_verified, t.ticket_verification_date,
                   t.status, t.is_approved, t.view_count, t.booking_count,
                   t.description, t.special_notes,
                   t.created_at, t.updated_at, t.published_at,
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes,
                   COUNT(tv.id) as view_count_calculated
            FROM trips t
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            LEFT JOIN trip_views tv ON t.id = tv.trip_id
            WHERE t.user_id = ? AND t.status != 'draft' AND t.deleted_at IS NULL
            GROUP BY t.id, t.uuid, t.user_id, t.departure_city, t.departure_country, t.departure_airport_code, 
                     t.departure_date, t.arrival_city, t.arrival_country, t.arrival_airport_code, t.arrival_date,
                     t.available_weight_kg, t.price_per_kg, t.currency, t.flight_number, t.airline, 
                     t.ticket_verified, t.ticket_verification_date, t.status, t.is_approved, t.view_count, 
                     t.booking_count, t.description, t.special_notes, t.created_at, t.updated_at, t.published_at,
                     tr.restricted_categories, tr.restricted_items, tr.restriction_notes
            ORDER BY t.created_at DESC
            LIMIT ? OFFSET ?
        ");
        
        $stmt->execute([$userId, $limit, $offset]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $trips = [];
        foreach ($results as $result) {
            // Parse JSON fields safely
            if ($result['restricted_categories'] && $result['restricted_categories'] !== 'null') {
                $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
            } else {
                $result['restricted_categories'] = null;
            }
            
            if ($result['restricted_items'] && $result['restricted_items'] !== 'null') {
                $result['restricted_items'] = json_decode($result['restricted_items'], true);
            } else {
                $result['restricted_items'] = null;
            }
            
            $trips[] = new Trip($result);
        }
        
        return $trips;
    }

    /**
     * Search trips
     */
    public function searchTrips(array $filters, int $page = 1, int $limit = 20): array
    {
        $offset = ($page - 1) * $limit;
        $whereConditions = ["t.status = 'published'", "t.departure_date > NOW()", "t.deleted_at IS NULL"];
        $params = [];
        
        // Apply filters
        if (!empty($filters['departure_city'])) {
            $whereConditions[] = "t.departure_city LIKE ?";
            $params[] = '%' . $filters['departure_city'] . '%';
        }
        
        if (!empty($filters['arrival_city'])) {
            $whereConditions[] = "t.arrival_city LIKE ?";
            $params[] = '%' . $filters['arrival_city'] . '%';
        }
        
        if (!empty($filters['departure_country'])) {
            $whereConditions[] = "t.departure_country = ?";
            $params[] = $filters['departure_country'];
        }
        
        if (!empty($filters['arrival_country'])) {
            $whereConditions[] = "t.arrival_country = ?";
            $params[] = $filters['arrival_country'];
        }
        
        if (!empty($filters['departure_date_from'])) {
            $whereConditions[] = "DATE(t.departure_date) >= ?";
            $params[] = $filters['departure_date_from'];
        }
        
        if (!empty($filters['departure_date_to'])) {
            $whereConditions[] = "DATE(t.departure_date) <= ?";
            $params[] = $filters['departure_date_to'];
        }
        
        if (!empty($filters['min_weight'])) {
            $whereConditions[] = "t.available_weight_kg >= ?";
            $params[] = $filters['min_weight'];
        }
        
        if (!empty($filters['max_price_per_kg'])) {
            $whereConditions[] = "t.price_per_kg <= ?";
            $params[] = $filters['max_price_per_kg'];
        }
        
        if (!empty($filters['currency'])) {
            $whereConditions[] = "t.currency = ?";
            $params[] = $filters['currency'];
        }
        
        if (isset($filters['verified_only']) && $filters['verified_only']) {
            $whereConditions[] = "u.is_verified = 1";
        }
        
        if (isset($filters['ticket_verified']) && $filters['ticket_verified']) {
            $whereConditions[] = "t.ticket_verified = 1";
        }
        
        $whereClause = implode(' AND ', $whereConditions);
        $params[] = $limit;
        $params[] = $offset;
        
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes,
                   u.first_name, u.last_name, u.profile_picture, u.is_verified,
                   COUNT(tv.id) as view_count_calculated
            FROM trips t
            JOIN users u ON t.user_id = u.id
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            LEFT JOIN trip_views tv ON t.id = tv.trip_id
            WHERE {$whereClause}
            GROUP BY t.id, u.id, tr.restricted_categories, tr.restricted_items, tr.restriction_notes
            ORDER BY t.departure_date ASC
            LIMIT ? OFFSET ?
        ");
        
        $stmt->execute($params);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $trips = [];
        foreach ($results as $result) {
            // Parse JSON fields safely
            if ($result['restricted_categories'] && $result['restricted_categories'] !== 'null') {
                $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
            } else {
                $result['restricted_categories'] = null;
            }
            
            if ($result['restricted_items'] && $result['restricted_items'] !== 'null') {
                $result['restricted_items'] = json_decode($result['restricted_items'], true);
            } else {
                $result['restricted_items'] = null;
            }
            
            $trip = new Trip($result);
            
            // Add user information
            $tripData = $trip->toArray();
            $tripData['user'] = [
                'first_name' => $result['first_name'],
                'last_name' => $result['last_name'],
                'profile_picture' => $result['profile_picture'],
                'is_verified' => (bool) $result['is_verified']
            ];
            
            $trips[] = $tripData;
        }
        
        return $trips;
    }

    /**
     * Update a trip
     */
    public function updateTrip(int $tripId, array $data, int $userId): Trip
    {
        // Get existing trip
        $existingTrip = $this->getTripById($tripId);
        if (!$existingTrip) {
            throw new Exception('Trip not found');
        }
        
        // Check ownership
        if ($existingTrip->getUserId() !== $userId) {
            throw new Exception('Not authorized to update this trip');
        }
        
        // Check if trip is editable
        if (!$existingTrip->isEditable()) {
            throw new Exception('Trip cannot be edited in current status or date has passed');
        }
        
        // Merge data with existing trip
        $updateData = array_merge($existingTrip->toArray(), $data);
        $trip = new Trip($updateData);
        
        // Validate
        $errors = $trip->validate();
        if (!empty($errors)) {
            throw new Exception('Validation failed: ' . implode(', ', $errors));
        }
        
        try {
            $this->db->beginTransaction();
            
            // Update trip
            $stmt = $this->db->prepare("
                UPDATE trips SET
                    departure_city = ?, departure_country = ?, departure_airport_code = ?, departure_date = ?,
                    arrival_city = ?, arrival_country = ?, arrival_airport_code = ?, arrival_date = ?,
                    available_weight_kg = ?, price_per_kg = ?, currency = ?, flight_number = ?, airline = ?,
                    description = ?, special_notes = ?, status = ?
                WHERE id = ?
            ");
            
            $stmt->execute([
                $trip->getDepartureCity(),
                $trip->getDepartureCountry(),
                $trip->getDepartureAirportCode(),
                $this->formatDateTimeForDB($trip->getDepartureDate()),
                $trip->getArrivalCity(),
                $trip->getArrivalCountry(),
                $trip->getArrivalAirportCode(),
                $this->formatDateTimeForDB($trip->getArrivalDate()),
                $trip->getAvailableWeightKg(),
                $trip->getPricePerKg(),
                $trip->getCurrency(),
                $trip->getFlightNumber(),
                $trip->getAirline(),
                $trip->getDescription(),
                $trip->getSpecialNotes(),
                $trip->getStatus(),
                $tripId
            ]);
            
            // Update restrictions - only if there are actual values to save
            $hasRestrictedCategories = isset($data['restricted_categories']) && 
                                     !empty($data['restricted_categories']) && 
                                     $data['restricted_categories'] !== '[]' && 
                                     $data['restricted_categories'] !== [];
                                     
            $hasRestrictedItems = isset($data['restricted_items']) && 
                                !empty($data['restricted_items']) && 
                                $data['restricted_items'] !== '[]' && 
                                $data['restricted_items'] !== [];
            
            error_log("TripService::updateTrip - Restrictions Debug:");
            error_log("  - restricted_categories: " . json_encode($data['restricted_categories'] ?? null));
            error_log("  - restricted_items: " . json_encode($data['restricted_items'] ?? null));
            error_log("  - restriction_notes: " . ($data['restriction_notes'] ?? 'null'));
            error_log("  - hasRestrictedCategories: " . ($hasRestrictedCategories ? 'true' : 'false'));
            error_log("  - hasRestrictedItems: " . ($hasRestrictedItems ? 'true' : 'false'));
                                
            if ($hasRestrictedCategories || $hasRestrictedItems || isset($data['restriction_notes'])) {
                // Delete existing restrictions
                $stmt = $this->db->prepare("DELETE FROM trip_restrictions WHERE trip_id = ?");
                $stmt->execute([$tripId]);
                
                // Insert new restrictions only if there's something to save
                if ($hasRestrictedCategories || $hasRestrictedItems || !empty($data['restriction_notes'])) {
                    $this->saveRestrictions($tripId, $data);
                }
            }
            
            $this->db->commit();
            
            return $this->getTripById($tripId);
            
        } catch (Exception $e) {
            $this->db->rollBack();
            error_log('TripService::updateTrip Error: ' . $e->getMessage());
            error_log('TripService::updateTrip Data: ' . json_encode($data));
            throw new Exception('Failed to update trip: ' . $e->getMessage());
        }
    }

    /**
     * Delete a trip
     */
    public function deleteTrip(int $tripId, int $userId): bool
    {
        $trip = $this->getTripById($tripId);
        if (!$trip) {
            throw new Exception('Trip not found');
        }
        
        if ($trip->getUserId() !== $userId) {
            throw new Exception('Not authorized to delete this trip');
        }
        
        try {
            $this->db->beginTransaction();
            
            // Soft delete: Set deleted_at timestamp
            $stmt = $this->db->prepare("UPDATE trips SET deleted_at = NOW(), updated_at = NOW() WHERE id = ?");
            $stmt->execute([$tripId]);
            
            // Log the action
            $this->logTripAction($tripId, $userId, 'delete', 'Trip soft deleted');
            
            $this->db->commit();
            
            return true;
            
        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to delete trip: ' . $e->getMessage());
        }
    }

    /**
     * Validate ticket (optional feature)
     */
    public function validateTicket(int $tripId, array $ticketData, int $userId): Trip
    {
        $trip = $this->getTripById($tripId);
        if (!$trip) {
            throw new Exception('Trip not found');
        }
        
        if ($trip->getUserId() !== $userId) {
            throw new Exception('Not authorized to validate ticket for this trip');
        }
        
        // In production, this would validate the ticket against airline APIs
        // For now, we'll just mark as verified
        
        try {
            $stmt = $this->db->prepare("
                UPDATE trips SET 
                    ticket_verified = 1,
                    ticket_verification_date = NOW(),
                    flight_number = COALESCE(?, flight_number),
                    airline = COALESCE(?, airline)
                WHERE id = ?
            ");
            
            $stmt->execute([
                $ticketData['flight_number'] ?? null,
                $ticketData['airline'] ?? null,
                $tripId
            ]);
            
            return $this->getTripById($tripId);
            
        } catch (Exception $e) {
            throw new Exception('Failed to validate ticket: ' . $e->getMessage());
        }
    }

    /**
     * Record a view for analytics
     */
    public function recordView(int $tripId, ?int $viewerId = null, ?string $ip = null): void
    {
        try {
            $stmt = $this->db->prepare("
                INSERT IGNORE INTO trip_views (trip_id, viewer_id, viewer_ip, user_agent)
                VALUES (?, ?, ?, ?)
            ");
            
            $stmt->execute([
                $tripId,
                $viewerId,
                $ip,
                $_SERVER['HTTP_USER_AGENT'] ?? null
            ]);
            
            // Update view count in trips table
            $this->db->prepare("
                UPDATE trips SET view_count = (
                    SELECT COUNT(*) FROM trip_views WHERE trip_id = ?
                ) WHERE id = ?
            ")->execute([$tripId, $tripId]);
            
        } catch (Exception $e) {
            // Don't fail on analytics error
            error_log("Failed to record view: " . $e->getMessage());
        }
    }

    /**
     * Get suggested price for a route
     */
    public function getSuggestedPrice(string $departureCity, string $departureCountry, string $arrivalCity, string $arrivalCountry, string $currency = 'EUR'): array
    {
        return $this->priceCalculator->calculateSuggestedPrice(
            $departureCity,
            $departureCountry,
            $arrivalCity,
            $arrivalCountry,
            $currency
        );
    }

    /**
     * Get price breakdown
     */
    public function getPriceBreakdown(float $pricePerKg, float $weightKg, string $currency = 'EUR'): array
    {
        return $this->priceCalculator->getPriceBreakdown($pricePerKg, $weightKg, $currency);
    }

    /**
     * Save trip restrictions
     */
    private function saveRestrictions(int $tripId, array $data): void
    {
        if (!isset($data['restricted_categories']) && !isset($data['restricted_items'])) {
            return;
        }
        
        // Handle different data formats safely
        $restrictedCategories = null;
        $restrictedItems = null;
        
        if (isset($data['restricted_categories'])) {
            if (is_array($data['restricted_categories'])) {
                $restrictedCategories = json_encode($data['restricted_categories']);
            } elseif (is_string($data['restricted_categories'])) {
                // Already JSON string, use as is
                $restrictedCategories = $data['restricted_categories'];
            }
        }
        
        if (isset($data['restricted_items'])) {
            if (is_array($data['restricted_items'])) {
                $restrictedItems = json_encode($data['restricted_items']);
            } elseif (is_string($data['restricted_items'])) {
                // Already JSON string, use as is  
                $restrictedItems = $data['restricted_items'];
            }
        }
        
        error_log('TripService::saveRestrictions - Categories: ' . ($restrictedCategories ?? 'null'));
        error_log('TripService::saveRestrictions - Items: ' . ($restrictedItems ?? 'null'));
        
        $stmt = $this->db->prepare("
            INSERT INTO trip_restrictions (trip_id, restricted_categories, restricted_items, restriction_notes)
            VALUES (?, ?, ?, ?)
        ");
        
        $stmt->execute([
            $tripId,
            $restrictedCategories,
            $restrictedItems,
            $data['restriction_notes'] ?? null
        ]);
    }

    /**
     * Format datetime for database storage (MySQL format)
     */
    private function formatDateTimeForDB(?string $dateTime): ?string
    {
        if (empty($dateTime)) {
            return null;
        }
        
        try {
            // Parse ISO8601 format from frontend and convert to MySQL format
            $date = new \DateTime($dateTime);
            return $date->format('Y-m-d H:i:s');
        } catch (\Exception $e) {
            error_log('TripService::formatDateTimeForDB - Invalid date format: ' . $dateTime . ' Error: ' . $e->getMessage());
            // Try to parse as-is if it's already in MySQL format
            return $dateTime;
        }
    }

    /**
     * Get trips pending approval
     */
    public function getPendingTrips(): array
    {
        try {
            $stmt = $this->db->prepare("
                SELECT 
                    t.*,
                    u.first_name, u.last_name, u.email
                FROM trips t
                LEFT JOIN users u ON t.user_id = u.id
                WHERE t.status IN ('pending_review', 'flagged_for_review')
                ORDER BY t.created_at DESC
            ");
            
            $stmt->execute();
            $trips = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Format trips data
            $formattedTrips = [];
            foreach ($trips as $trip) {
                // Get trip images
                $imageStmt = $this->db->prepare("
                    SELECT id, image_path, image_name, file_size, upload_order
                    FROM trip_images 
                    WHERE trip_id = ? 
                    ORDER BY upload_order ASC
                ");
                $imageStmt->execute([$trip['id']]);
                $images = $imageStmt->fetchAll(PDO::FETCH_ASSOC);
                
                // Format images with full URLs
                $formattedImages = [];
                foreach ($images as $image) {
                    $formattedImages[] = [
                        'id' => $image['id'],
                        'image_path' => $image['image_path'],
                        'image_name' => $image['image_name'],
                        'file_size' => (int) $image['file_size'],
                        'upload_order' => (int) $image['upload_order'],
                        'image_url' => (strpos($image['image_path'], 'http') === 0) 
                            ? $image['image_path'] 
                            : 'http://localhost:8080/' . ltrim($image['image_path'], '/'),
                        'formatted_file_size' => $this->formatFileSize((int) $image['file_size'])
                    ];
                }

                $formattedTrips[] = [
                    'id' => $trip['id'],
                    'uuid' => $trip['uuid'],
                    'transport_type' => $trip['transport_type'] ?? 'plane',
                    'departure_city' => $trip['departure_city'],
                    'departure_country' => $trip['departure_country'],
                    'departure_date' => $trip['departure_date'],
                    'arrival_city' => $trip['arrival_city'],
                    'arrival_country' => $trip['arrival_country'],
                    'arrival_date' => $trip['arrival_date'],
                    'available_weight_kg' => (float) $trip['available_weight_kg'],
                    'price_per_kg' => (float) $trip['price_per_kg'],
                    'currency' => $trip['currency'],
                    'status' => $trip['status'],
                    'has_images' => (bool) $trip['has_images'],
                    'image_count' => (int) $trip['image_count'],
                    'images' => $formattedImages,
                    'created_at' => $trip['created_at'],
                    'user' => [
                        'first_name' => $trip['first_name'],
                        'last_name' => $trip['last_name'],
                        'email' => $trip['email'],
                        'trust_score' => 50, // Default trust score - will be implemented later
                        'total_trips' => 0  // Default total trips - will be implemented later
                    ]
                ];
            }
            
            return $formattedTrips;
            
        } catch (Exception $e) {
            throw new Exception('Failed to get pending trips: ' . $e->getMessage());
        }
    }

    /**
     * Approve a trip
     */
    public function approveTrip(string $tripId, int $adminId): array
    {
        try {
            $this->db->beginTransaction();

            // Update trip status and approval
            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = 'active', is_approved = 1, moderated_by = ?, updated_at = NOW()
                WHERE id = ? OR uuid = ?
            ");
            $stmt->execute([$adminId, $tripId, $tripId]);

            if ($stmt->rowCount() === 0) {
                throw new Exception('Trip not found');
            }

            // Log admin action
            $stmt = $this->db->prepare("
                INSERT INTO admin_actions (admin_id, action_type, target_type, target_id, details)
                VALUES (?, 'approve', 'trip', ?, 'Trip approved by admin')
            ");
            $stmt->execute([$adminId, $tripId]);

            $this->db->commit();

            // Return updated trip data
            $stmt = $this->db->prepare("SELECT * FROM trips WHERE id = ? OR uuid = ?");
            $stmt->execute([$tripId, $tripId]);
            $trip = $stmt->fetch(PDO::FETCH_ASSOC);

            return $trip ?: [];

        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to approve trip: ' . $e->getMessage());
        }
    }

    /**
     * Reject a trip
     */
    public function rejectTrip(string $tripId, int $adminId, string $reason): array
    {
        try {
            $this->db->beginTransaction();

            // Update trip status
            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = 'rejected', updated_at = NOW()
                WHERE id = ? OR uuid = ?
            ");
            $stmt->execute([$tripId, $tripId]);

            if ($stmt->rowCount() === 0) {
                throw new Exception('Trip not found');
            }

            // Log admin action
            $stmt = $this->db->prepare("
                INSERT INTO admin_actions (admin_id, action_type, target_type, target_id, details)
                VALUES (?, 'reject', 'trip', ?, ?)
            ");
            $stmt->execute([$adminId, $tripId, "Trip rejected: $reason"]);

            $this->db->commit();

            // Return updated trip data
            $stmt = $this->db->prepare("SELECT * FROM trips WHERE id = ? OR uuid = ?");
            $stmt->execute([$tripId, $tripId]);
            $trip = $stmt->fetch(PDO::FETCH_ASSOC);

            return $trip ?: [];

        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to reject trip: ' . $e->getMessage());
        }
    }

    /**
     * Get user drafts
     */
    public function getUserDrafts(int $userId, int $page = 1, int $limit = 20): array
    {
        $offset = ($page - 1) * $limit;
        
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes,
                   COUNT(tv.id) as view_count_calculated
            FROM trips t
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            LEFT JOIN trip_views tv ON t.id = tv.trip_id
            WHERE t.user_id = ? AND t.status = 'draft' AND t.deleted_at IS NULL
            GROUP BY t.id, tr.restricted_categories, tr.restricted_items, tr.restriction_notes
            ORDER BY t.updated_at DESC
            LIMIT ? OFFSET ?
        ");
        $stmt->execute([$userId, $limit, $offset]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $drafts = [];
        foreach ($results as $result) {
            // Parse JSON fields safely
            if ($result['restricted_categories'] && $result['restricted_categories'] !== 'null') {
                $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
            } else {
                $result['restricted_categories'] = null;
            }
            
            if ($result['restricted_items'] && $result['restricted_items'] !== 'null') {
                $result['restricted_items'] = json_decode($result['restricted_items'], true);
            } else {
                $result['restricted_items'] = null;
            }
            
            $drafts[] = new Trip($result);
        }
        
        return $drafts;
    }

    /**
     * Get user favorites
     */
    public function getUserFavorites(int $userId, int $page = 1, int $limit = 20): array
    {
        $offset = ($page - 1) * $limit;
        
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes,
                   COUNT(tv.id) as view_count_calculated
            FROM trips t
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            LEFT JOIN trip_views tv ON t.id = tv.trip_id
            INNER JOIN trip_favorites tf ON t.id = tf.trip_id
            WHERE tf.user_id = ? AND t.deleted_at IS NULL
            GROUP BY t.id, tr.restricted_categories, tr.restricted_items, tr.restriction_notes, tf.created_at
            ORDER BY tf.created_at DESC
            LIMIT ? OFFSET ?
        ");
        $stmt->execute([$userId, $limit, $offset]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $favorites = [];
        foreach ($results as $result) {
            // Parse JSON fields safely
            if ($result['restricted_categories'] && $result['restricted_categories'] !== 'null') {
                $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
            } else {
                $result['restricted_categories'] = null;
            }
            
            if ($result['restricted_items'] && $result['restricted_items'] !== 'null') {
                $result['restricted_items'] = json_decode($result['restricted_items'], true);
            } else {
                $result['restricted_items'] = null;
            }
            
            $favorites[] = new Trip($result);
        }
        
        return $favorites;
    }

    /**
     * Publish trip (draft to active/pending_review)
     */
    public function publishTrip(int $tripId, int $userId): Trip
    {
        $trip = $this->getTripById($tripId);
        if (!$trip || $trip->getUserId() != $userId) {
            throw new Exception('Trip not found or access denied');
        }

        if (!$trip->canBePublished()) {
            throw new Exception('Trip cannot be published in current state');
        }

        try {
            $this->db->beginTransaction();

            // Determine target status based on auto-approval logic
            if ($trip->getAutoApproved()) {
                $status = 'active';
                $isApproved = true;
                $moderatedBy = null; // Auto-approved, no moderator
            } else {
                $status = 'pending_review';
                $isApproved = false;
                $moderatedBy = null;
            }
            
            $publishedAt = date('Y-m-d H:i:s');

            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = ?, published_at = ?, is_approved = ?, moderated_by = ?, updated_at = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$status, $publishedAt, $isApproved ? 1 : 0, $moderatedBy, $tripId]);

            $this->db->commit();
            return $this->getTripById($tripId);

        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to publish trip: ' . $e->getMessage());
        }
    }

    /**
     * Pause trip
     */
    public function pauseTrip(int $tripId, int $userId, ?string $reason = null): Trip
    {
        $trip = $this->getTripById($tripId);
        if (!$trip || $trip->getUserId() != $userId) {
            throw new Exception('Trip not found or access denied');
        }

        if (!in_array($trip->getStatus(), ['active', 'pending_review'])) {
            throw new Exception('Only active or pending review trips can be paused');
        }

        try {
            $this->db->beginTransaction();

            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = 'paused', paused_at = NOW(), pause_reason = ?, updated_at = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$reason, $tripId]);

            // Log the action
            $this->logTripAction($tripId, $userId, 'pause', $reason);

            $this->db->commit();
            return $this->getTripById($tripId);

        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to pause trip: ' . $e->getMessage());
        }
    }

    /**
     * Resume trip
     */
    public function resumeTrip(int $tripId, int $userId): Trip
    {
        $trip = $this->getTripById($tripId);
        if (!$trip || $trip->getUserId() != $userId) {
            throw new Exception('Trip not found or access denied');
        }

        if ($trip->getStatus() !== 'paused') {
            throw new Exception('Only paused trips can be resumed');
        }

        try {
            $this->db->beginTransaction();

            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = 'active', paused_at = NULL, pause_reason = NULL, updated_at = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$tripId]);

            // Log the action
            $this->logTripAction($tripId, $userId, 'resume');

            $this->db->commit();
            return $this->getTripById($tripId);

        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to resume trip: ' . $e->getMessage());
        }
    }

    /**
     * Cancel trip
     */
    public function cancelTrip(int $tripId, int $userId, ?string $reason = null, ?string $details = null): Trip
    {
        $trip = $this->getTripById($tripId);
        if (!$trip || $trip->getUserId() != $userId) {
            throw new Exception('Trip not found or access denied');
        }

        $allowedStatuses = ['draft', 'pending_review', 'active', 'paused', 'booked', 'in_progress'];
        if (!in_array($trip->getStatus(), $allowedStatuses)) {
            throw new Exception('Trip cannot be cancelled in current state');
        }

        try {
            $this->db->beginTransaction();

            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = 'cancelled', cancelled_at = NOW(), 
                    cancellation_reason = ?, cancellation_details = ?, updated_at = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$reason, $details, $tripId]);

            // Log the action
            $this->logTripAction($tripId, $userId, 'cancel', $reason);

            $this->db->commit();
            return $this->getTripById($tripId);

        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to cancel trip: ' . $e->getMessage());
        }
    }

    /**
     * Complete trip
     */
    public function completeTrip(int $tripId, int $userId): Trip
    {
        $trip = $this->getTripById($tripId);
        if (!$trip || $trip->getUserId() != $userId) {
            throw new Exception('Trip not found or access denied');
        }

        $allowedStatuses = ['booked', 'in_progress'];
        if (!in_array($trip->getStatus(), $allowedStatuses)) {
            throw new Exception('Trip cannot be completed in current state');
        }

        try {
            $this->db->beginTransaction();

            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = 'completed', completed_at = NOW(), updated_at = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$tripId]);

            // Log the action
            $this->logTripAction($tripId, $userId, 'complete');

            $this->db->commit();
            return $this->getTripById($tripId);

        } catch (Exception $e) {
            $this->db->rollBack();
            throw new Exception('Failed to complete trip: ' . $e->getMessage());
        }
    }

    /**
     * Add trip to favorites
     */
    public function addToFavorites(int $tripId, int $userId): void
    {
        try {
            $stmt = $this->db->prepare("
                INSERT IGNORE INTO trip_favorites (trip_id, user_id, created_at)
                VALUES (?, ?, NOW())
            ");
            $stmt->execute([$tripId, $userId]);

            // Update favorite count
            $this->updateFavoriteCount($tripId);

        } catch (Exception $e) {
            throw new Exception('Failed to add to favorites: ' . $e->getMessage());
        }
    }

    /**
     * Remove trip from favorites
     */
    public function removeFromFavorites(int $tripId, int $userId): void
    {
        try {
            $stmt = $this->db->prepare("
                DELETE FROM trip_favorites 
                WHERE trip_id = ? AND user_id = ?
            ");
            $stmt->execute([$tripId, $userId]);

            // Update favorite count
            $this->updateFavoriteCount($tripId);

        } catch (Exception $e) {
            throw new Exception('Failed to remove from favorites: ' . $e->getMessage());
        }
    }

    /**
     * Report trip
     */
    public function reportTrip(int $tripId, int $userId, string $reportType, ?string $description = null): void
    {
        $validTypes = ['spam', 'fraud', 'inappropriate', 'misleading', 'prohibited_items', 'suspicious_price', 'other'];
        if (!in_array($reportType, $validTypes)) {
            throw new Exception('Invalid report type');
        }

        try {
            $stmt = $this->db->prepare("
                INSERT INTO trip_reports (trip_id, reported_by, report_type, description, status, created_at)
                VALUES (?, ?, ?, ?, 'pending', NOW())
            ");
            $stmt->execute([$tripId, $userId, $reportType, $description]);

            // Update report count
            $this->updateReportCount($tripId);

        } catch (Exception $e) {
            throw new Exception('Failed to report trip: ' . $e->getMessage());
        }
    }

    /**
     * Get trip analytics
     */
    public function getTripAnalytics(int $tripId, int $userId): array
    {
        $trip = $this->getTripById($tripId);
        if (!$trip || $trip->getUserId() != $userId) {
            throw new Exception('Trip not found or access denied');
        }

        return [
            'views' => $trip->getViewCount(),
            'favorites' => $trip->getFavoriteCount(),
            'shares' => $trip->getShareCount(),
            'reports' => $trip->getReportCount(),
            'bookings' => $trip->getBookingCount(),
            'remaining_weight' => $trip->getRemainingWeight(),
            'conversion_rate' => $trip->getViewCount() > 0 ? ($trip->getBookingCount() / $trip->getViewCount()) * 100 : 0
        ];
    }

    /**
     * Share trip
     */
    public function shareTrip(int $tripId, int $userId): array
    {
        $trip = $this->getTripById($tripId);
        if (!$trip) {
            throw new Exception('Trip not found');
        }

        try {
            // Increment share count
            $stmt = $this->db->prepare("
                UPDATE trips 
                SET share_count = share_count + 1, updated_at = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$tripId]);

            // Generate share URL
            $shareUrl = "https://kiloshare.com/trips/" . $trip->getUuid();
            if ($trip->getShareToken()) {
                $shareUrl .= "?token=" . $trip->getShareToken();
            }

            return ['share_url' => $shareUrl];

        } catch (Exception $e) {
            throw new Exception('Failed to share trip: ' . $e->getMessage());
        }
    }

    /**
     * Duplicate trip
     */
    public function duplicateTrip(int $tripId, int $userId): Trip
    {
        error_log("=== DEBUG DUPLICATE TRIP BACKEND START ===");
        error_log("Trip ID to duplicate: $tripId");
        error_log("User ID: $userId");
        
        $originalTrip = $this->getTripById($tripId);
        if (!$originalTrip) {
            error_log("ERROR: Original trip not found");
            throw new Exception('Trip not found or access denied');
        }
        
        if ($originalTrip->getUserId() != $userId) {
            error_log("ERROR: Access denied - trip belongs to user " . $originalTrip->getUserId() . " but requesting user is $userId");
            throw new Exception('Trip not found or access denied');
        }

        error_log("Original trip found, getting data...");
        $tripData = $originalTrip->toArray();
        error_log("Original trip data keys: " . implode(', ', array_keys($tripData)));
        
        // Remove fields that shouldn't be duplicated
        unset($tripData['id'], $tripData['uuid'], $tripData['created_at'], $tripData['updated_at']);
        unset($tripData['published_at'], $tripData['view_count'], $tripData['booking_count']);
        unset($tripData['share_count'], $tripData['favorite_count'], $tripData['report_count']);
        
        // Set as draft and reference original
        $tripData['status'] = 'draft';
        $tripData['original_trip_id'] = $tripId;
        $tripData['duplicate_count'] = 0;

        error_log("Trip data prepared for duplication, keys: " . implode(', ', array_keys($tripData)));
        error_log("Calling createTrip...");

        try {
            $newTrip = $this->createTrip($tripData, $userId);
            error_log("SUCCESS: New trip created with ID: " . $newTrip->getId());
            error_log("=== DEBUG DUPLICATE TRIP BACKEND END ===");
            return $newTrip;
        } catch (Exception $e) {
            error_log("ERROR: Failed to create duplicate trip: " . $e->getMessage());
            error_log("=== DEBUG DUPLICATE TRIP BACKEND ERROR ===");
            throw $e;
        }
    }

    /**
     * Log trip action
     */
    private function logTripAction(int $tripId, int $userId, string $action, ?string $reason = null): void
    {
        $stmt = $this->db->prepare("
            INSERT INTO trip_action_logs (trip_id, user_id, action, reason, created_at)
            VALUES (?, ?, ?, ?, NOW())
        ");
        $stmt->execute([$tripId, $userId, $action, $reason]);
    }

    /**
     * Update favorite count
     */
    private function updateFavoriteCount(int $tripId): void
    {
        $stmt = $this->db->prepare("
            UPDATE trips 
            SET favorite_count = (
                SELECT COUNT(*) FROM trip_favorites WHERE trip_id = ?
            )
            WHERE id = ?
        ");
        $stmt->execute([$tripId, $tripId]);
    }

    /**
     * Get public trips (approved and published)
     */
    public function getPublicTrips(int $limit = 10): array
    {
        $stmt = $this->db->prepare("
            SELECT t.*, u.first_name, u.last_name, u.is_verified,
                   COUNT(tr.id) as report_count
            FROM trips t
            LEFT JOIN users u ON t.user_id = u.id
            LEFT JOIN trip_reports tr ON t.id = tr.trip_id
            WHERE t.status IN ('published', 'active') 
                AND t.deleted_at IS NULL
                AND t.is_approved = 1
                AND t.departure_date > NOW()
            GROUP BY t.id
            HAVING report_count <= 3
            ORDER BY t.created_at DESC
            LIMIT ?
        ");
        
        $stmt->execute([$limit]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $trips = [];
        foreach ($results as $result) {
            $trip = new Trip($result);
            $trips[] = $trip->toArray();
        }
        
        return $trips;
    }

    /**
     * Update report count
     */
    private function updateReportCount(int $tripId): void
    {
        $stmt = $this->db->prepare("
            UPDATE trips 
            SET report_count = (
                SELECT COUNT(*) FROM trip_reports WHERE trip_id = ?
            )
            WHERE id = ?
        ");
        $stmt->execute([$tripId, $tripId]);
    }

    /**
     * Load images for a trip
     */
    private function loadTripImages(Trip $trip): Trip
    {
        $images = $this->tripImageService->getTripImages($trip->getId());
        $imageArray = array_map(fn($img) => $img->toArray(), $images);
        
        $trip->setImages($imageArray);
        $trip->setImageCount(count($imageArray));
        $trip->setHasImages(count($imageArray) > 0);
        
        return $trip;
    }

    /**
     * Generate UUID
     */
    private function generateUuid(): string
    {
        return sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }

    /**
     * Format file size in human readable format
     */
    private function formatFileSize(int $bytes): string
    {
        if ($bytes < 1024) {
            return $bytes . ' B';
        } elseif ($bytes < 1048576) {
            return round($bytes / 1024, 1) . ' KB';
        } else {
            return round($bytes / 1048576, 1) . ' MB';
        }
    }
}