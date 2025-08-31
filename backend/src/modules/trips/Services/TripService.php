<?php

namespace App\Modules\Trips\Services;

use App\Modules\Trips\Models\Trip;
use PDO;
use Exception;

class TripService
{
    private PDO $db;
    private PriceCalculatorService $priceCalculator;

    public function __construct(PriceCalculatorService $priceCalculator, PDO $db)
    {
        $this->db = $db;
        $this->priceCalculator = $priceCalculator;
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
                $trip->getDepartureDate(),
                $trip->getArrivalCity(),
                $trip->getArrivalCountry(),
                $trip->getArrivalAirportCode(),
                $trip->getArrivalDate(),
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
            SELECT t.*, 
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes
            FROM trips t
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            WHERE t.id = ?
        ");
        
        $stmt->execute([$id]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$result) {
            return null;
        }
        
        // Parse JSON fields
        if ($result['restricted_categories']) {
            $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
        }
        if ($result['restricted_items']) {
            $result['restricted_items'] = json_decode($result['restricted_items'], true);
        }
        
        return new Trip($result);
    }

    /**
     * Get trip by UUID
     */
    public function getTripByUuid(string $uuid): ?Trip
    {
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   tr.restricted_categories, tr.restricted_items, tr.restriction_notes
            FROM trips t
            LEFT JOIN trip_restrictions tr ON t.id = tr.trip_id
            WHERE t.uuid = ?
        ");
        
        $stmt->execute([$uuid]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$result) {
            return null;
        }
        
        // Parse JSON fields
        if ($result['restricted_categories']) {
            $result['restricted_categories'] = json_decode($result['restricted_categories'], true);
        }
        if ($result['restricted_items']) {
            $result['restricted_items'] = json_decode($result['restricted_items'], true);
        }
        
        return new Trip($result);
    }

    /**
     * Get trips for a user
     */
    public function getUserTrips(int $userId, int $page = 1, int $limit = 20): array
    {
        $offset = ($page - 1) * $limit;
        
        $stmt = $this->db->prepare("
            SELECT t.*, 
                   COUNT(tv.id) as view_count_calculated
            FROM trips t
            LEFT JOIN trip_views tv ON t.id = tv.trip_id
            WHERE t.user_id = ?
            GROUP BY t.id
            ORDER BY t.created_at DESC
            LIMIT ? OFFSET ?
        ");
        
        $stmt->execute([$userId, $limit, $offset]);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $trips = [];
        foreach ($results as $result) {
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
        $whereConditions = ["t.status = 'published'", "t.departure_date > NOW()"];
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
                   u.first_name, u.last_name, u.profile_picture, u.is_verified,
                   COUNT(tv.id) as view_count_calculated
            FROM trips t
            JOIN users u ON t.user_id = u.id
            LEFT JOIN trip_views tv ON t.id = tv.trip_id
            WHERE {$whereClause}
            GROUP BY t.id, u.id
            ORDER BY t.departure_date ASC
            LIMIT ? OFFSET ?
        ");
        
        $stmt->execute($params);
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        $trips = [];
        foreach ($results as $result) {
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
                $trip->getDepartureDate(),
                $trip->getArrivalCity(),
                $trip->getArrivalCountry(),
                $trip->getArrivalAirportCode(),
                $trip->getArrivalDate(),
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
            
            // Update restrictions
            if (isset($data['restricted_categories']) || isset($data['restricted_items'])) {
                // Delete existing restrictions
                $stmt = $this->db->prepare("DELETE FROM trip_restrictions WHERE trip_id = ?");
                $stmt->execute([$tripId]);
                
                // Insert new restrictions
                $this->saveRestrictions($tripId, $data);
            }
            
            $this->db->commit();
            
            return $this->getTripById($tripId);
            
        } catch (Exception $e) {
            $this->db->rollBack();
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
            
            // Delete related data (CASCADE should handle this, but being explicit)
            $this->db->prepare("DELETE FROM trip_restrictions WHERE trip_id = ?")->execute([$tripId]);
            $this->db->prepare("DELETE FROM trip_views WHERE trip_id = ?")->execute([$tripId]);
            // $this->db->prepare("DELETE FROM trip_images WHERE trip_id = ?")->execute([$tripId]); // Table doesn't exist yet
            
            // Delete trip
            $stmt = $this->db->prepare("DELETE FROM trips WHERE id = ?");
            $stmt->execute([$tripId]);
            
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
        
        $stmt = $this->db->prepare("
            INSERT INTO trip_restrictions (trip_id, restricted_categories, restricted_items, restriction_notes)
            VALUES (?, ?, ?, ?)
        ");
        
        $stmt->execute([
            $tripId,
            isset($data['restricted_categories']) ? json_encode($data['restricted_categories']) : null,
            isset($data['restricted_items']) ? json_encode($data['restricted_items']) : null,
            $data['restriction_notes'] ?? null
        ]);
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
                WHERE t.status IN ('pending_approval', 'flagged_for_review')
                ORDER BY t.created_at DESC
            ");
            
            $stmt->execute();
            $trips = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Format trips data
            $formattedTrips = [];
            foreach ($trips as $trip) {
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

            // Update trip status
            $stmt = $this->db->prepare("
                UPDATE trips 
                SET status = 'published', updated_at = NOW()
                WHERE id = ? OR uuid = ?
            ");
            $stmt->execute([$tripId, $tripId]);

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
}