<?php

namespace App\Modules\Search\Services;

use App\Modules\Search\Models\SearchHistory;
use App\Modules\Search\Models\SearchAlert;
use App\Modules\Search\Models\PopularRoute;
use PDO;
use PDOException;
use Psr\Log\LoggerInterface;

class SearchService
{
    private PDO $db;
    private LoggerInterface $logger;

    public function __construct(PDO $db, LoggerInterface $logger)
    {
        $this->db = $db;
        $this->logger = $logger;
    }

    /**
     * Search trips with comprehensive filtering and sorting
     */
    public function searchTrips(array $params, int $page = 1, int $limit = 20): array
    {
        try {
            $offset = ($page - 1) * $limit;
            
            // Base query without problematic CASE statement for now
            $sql = "
                SELECT t.*, u.first_name, u.last_name, u.profile_picture, u.is_verified
                FROM trips t
                LEFT JOIN users u ON t.user_id = u.id
                WHERE t.status IN ('active', 'published') 
                AND t.departure_date >= CURDATE()
                AND t.available_weight_kg > 0
            ";

            $searchParams = [];
            
            // City filtering
            if (!empty($params['departure_city'])) {
                $sql .= " AND LOWER(t.departure_city) LIKE LOWER(:departure_search)";
                $searchParams[':departure_search'] = '%' . trim($params['departure_city']) . '%';
            }

            if (!empty($params['arrival_city'])) {
                $sql .= " AND LOWER(t.arrival_city) LIKE LOWER(:arrival_search)";
                $searchParams[':arrival_search'] = '%' . trim($params['arrival_city']) . '%';
            }

            // Date filtering with flexibility (+/- 3 days)
            if (!empty($params['departure_date'])) {
                $targetDate = $params['departure_date'];
                $sql .= " AND t.departure_date BETWEEN DATE_SUB(:target_date_1, INTERVAL 3 DAY) 
                         AND DATE_ADD(:target_date_2, INTERVAL 3 DAY)";
                $searchParams[':target_date_1'] = $targetDate;
                $searchParams[':target_date_2'] = $targetDate;
            }

            // Price filtering
            if (!empty($params['max_price'])) {
                $sql .= " AND t.price_per_kg <= :max_price";
                $searchParams[':max_price'] = (float) $params['max_price'];
            }

            // Weight filtering
            if (!empty($params['min_weight'])) {
                $sql .= " AND t.available_weight_kg >= :min_weight";
                $searchParams[':min_weight'] = (int) $params['min_weight'];
            }

            // Transport type filtering
            if (!empty($params['transport_type'])) {
                $sql .= " AND t.transport_type = :transport_type";
                $searchParams[':transport_type'] = $params['transport_type'];
            }

            // Verified users only
            if (!empty($params['verified_only'])) {
                $sql .= " AND u.is_verified = 1";
            }

            // Skip minimum rating filter since we don't have user ratings yet
            // if (!empty($params['min_rating'])) {
            //     $sql .= " AND u.rating >= :min_rating";
            //     $searchParams[':min_rating'] = (float) $params['min_rating'];
            // }

            // Sorting
            $sortBy = $params['sort_by'] ?? 'date_asc';
            switch ($sortBy) {
                case 'price_asc':
                    $sql .= " ORDER BY t.price_per_kg ASC";
                    break;
                case 'price_desc':
                    $sql .= " ORDER BY t.price_per_kg DESC";
                    break;
                case 'date_asc':
                    $sql .= " ORDER BY t.departure_date ASC";
                    break;
                case 'date_desc':
                    $sql .= " ORDER BY t.departure_date DESC";
                    break;
                case 'rating':
                    $sql .= " ORDER BY t.created_at DESC"; // Fallback to creation date since no ratings
                    break;
                case 'relevance':
                default:
                    $sql .= " ORDER BY t.departure_date ASC, t.created_at DESC";
                    break;
            }

            $sql .= " LIMIT :limit OFFSET :offset";
            $searchParams[':limit'] = $limit;
            $searchParams[':offset'] = $offset;

            $stmt = $this->db->prepare($sql);
            
            foreach ($searchParams as $key => $value) {
                if ($key === ':limit' || $key === ':offset') {
                    $stmt->bindValue($key, $value, PDO::PARAM_INT);
                } else {
                    $stmt->bindValue($key, $value);
                }
            }
            
            $stmt->execute();
            $trips = $stmt->fetchAll(PDO::FETCH_ASSOC);

            // Get total count for pagination
            $countSql = str_replace(['SELECT t.*, u.first_name, u.last_name, u.profile_picture, u.is_verified', 'LEFT JOIN users u ON t.user_id = u.id'], 
                                  ['SELECT COUNT(t.id) as total', ''], $sql);
            $countSql = preg_replace('/ORDER BY.*LIMIT.*OFFSET.*/', '', $countSql);
            
            $countStmt = $this->db->prepare($countSql);
            foreach ($searchParams as $key => $value) {
                if (!in_array($key, [':limit', ':offset'])) {
                    $countStmt->bindValue($key, $value);
                }
            }
            $countStmt->execute();
            $totalResults = $countStmt->fetchColumn();

            return [
                'trips' => $trips,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $limit,
                    'total' => (int) $totalResults,
                    'total_pages' => ceil($totalResults / $limit)
                ]
            ];

        } catch (PDOException $e) {
            $this->logger->error('Search trips error: ' . $e->getMessage(), $params);
            throw $e;
        }
    }

    /**
     * Get city suggestions based on input
     */
    public function getCitySuggestions(string $query, int $limit = 10): array
    {
        try {
            $sql = "
                SELECT city_name, country, search_count, is_popular
                FROM city_suggestions 
                WHERE city_name LIKE :query
                ORDER BY is_popular DESC, search_count DESC, city_name ASC
                LIMIT :limit
            ";

            $stmt = $this->db->prepare($sql);
            $stmt->bindValue(':query', '%' . trim($query) . '%');
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();

            return $stmt->fetchAll(PDO::FETCH_ASSOC);

        } catch (PDOException $e) {
            $this->logger->error('Get city suggestions error: ' . $e->getMessage(), ['query' => $query]);
            return [];
        }
    }

    /**
     * Save user search to history
     */
    public function saveSearchHistory(int $userId, array $searchParams): bool
    {
        try {
            $history = new SearchHistory($userId, $searchParams);
            
            $sql = "
                INSERT INTO search_history (user_id, search_params_json, searched_at)
                VALUES (:user_id, :search_params_json, :searched_at)
            ";

            $stmt = $this->db->prepare($sql);
            $dbArray = $history->toDbArray();
            
            foreach ($dbArray as $key => $value) {
                $stmt->bindValue(':' . $key, $value);
            }
            
            $result = $stmt->execute();

            // Update popular routes
            if (!empty($searchParams['departure_city']) && !empty($searchParams['arrival_city'])) {
                $this->updatePopularRoute(
                    $searchParams['departure_city'],
                    $searchParams['arrival_city'],
                    $searchParams['departure_country'] ?? 'Canada',
                    $searchParams['arrival_country'] ?? 'Canada'
                );
            }

            // Update city suggestions
            $this->updateCitySuggestions([
                $searchParams['departure_city'] ?? '',
                $searchParams['arrival_city'] ?? ''
            ]);

            return $result;

        } catch (PDOException $e) {
            $this->logger->error('Save search history error: ' . $e->getMessage(), ['user_id' => $userId]);
            return false;
        }
    }

    /**
     * Get user's recent searches
     */
    public function getUserSearchHistory(int $userId, int $limit = 10): array
    {
        try {
            $sql = "
                SELECT * FROM search_history 
                WHERE user_id = :user_id 
                ORDER BY searched_at DESC 
                LIMIT :limit
            ";

            $stmt = $this->db->prepare($sql);
            $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();

            $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            return array_map(function($row) {
                return SearchHistory::fromArray($row);
            }, $results);

        } catch (PDOException $e) {
            $this->logger->error('Get user search history error: ' . $e->getMessage(), ['user_id' => $userId]);
            return [];
        }
    }

    /**
     * Save search alert
     */
    public function saveSearchAlert(SearchAlert $alert): ?int
    {
        try {
            $sql = "
                INSERT INTO search_alerts (
                    user_id, departure_city, departure_country, arrival_city, arrival_country,
                    date_range_start, date_range_end, max_price, max_weight, transport_type,
                    min_rating, verified_only, active
                ) VALUES (
                    :user_id, :departure_city, :departure_country, :arrival_city, :arrival_country,
                    :date_range_start, :date_range_end, :max_price, :max_weight, :transport_type,
                    :min_rating, :verified_only, :active
                )
            ";

            $stmt = $this->db->prepare($sql);
            $dbArray = $alert->toDbArray();
            
            foreach ($dbArray as $key => $value) {
                $stmt->bindValue(':' . $key, $value);
            }
            
            if ($stmt->execute()) {
                return (int) $this->db->lastInsertId();
            }

            return null;

        } catch (PDOException $e) {
            $this->logger->error('Save search alert error: ' . $e->getMessage(), ['user_id' => $alert->getUserId()]);
            return null;
        }
    }

    /**
     * Get user's search alerts
     */
    public function getUserSearchAlerts(int $userId, bool $activeOnly = true): array
    {
        try {
            $sql = "
                SELECT * FROM search_alerts 
                WHERE user_id = :user_id
            ";

            if ($activeOnly) {
                $sql .= " AND active = 1";
            }

            $sql .= " ORDER BY created_at DESC";

            $stmt = $this->db->prepare($sql);
            $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
            $stmt->execute();

            $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            return array_map(function($row) {
                return SearchAlert::fromArray($row);
            }, $results);

        } catch (PDOException $e) {
            $this->logger->error('Get user search alerts error: ' . $e->getMessage(), ['user_id' => $userId]);
            return [];
        }
    }

    /**
     * Get popular routes
     */
    public function getPopularRoutes(int $limit = 20): array
    {
        try {
            $sql = "
                SELECT * FROM popular_routes 
                ORDER BY search_count DESC, last_searched DESC 
                LIMIT :limit
            ";

            $stmt = $this->db->prepare($sql);
            $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
            $stmt->execute();

            $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            return array_map(function($row) {
                return PopularRoute::fromArray($row);
            }, $results);

        } catch (PDOException $e) {
            $this->logger->error('Get popular routes error: ' . $e->getMessage());
            return [];
        }
    }

    /**
     * Update popular route statistics
     */
    private function updatePopularRoute(string $departureCity, string $arrivalCity, 
                                      string $departureCountry = 'Canada', string $arrivalCountry = 'Canada'): bool
    {
        try {
            // Check if route exists
            $checkSql = "
                SELECT id FROM popular_routes 
                WHERE departure_city = :departure_city 
                AND departure_country = :departure_country
                AND arrival_city = :arrival_city 
                AND arrival_country = :arrival_country
            ";

            $checkStmt = $this->db->prepare($checkSql);
            $checkStmt->bindValue(':departure_city', $departureCity);
            $checkStmt->bindValue(':departure_country', $departureCountry);
            $checkStmt->bindValue(':arrival_city', $arrivalCity);
            $checkStmt->bindValue(':arrival_country', $arrivalCountry);
            $checkStmt->execute();

            if ($checkStmt->fetchColumn()) {
                // Update existing route
                $updateSql = "
                    UPDATE popular_routes 
                    SET search_count = search_count + 1, last_searched = CURRENT_TIMESTAMP
                    WHERE departure_city = :departure_city 
                    AND departure_country = :departure_country
                    AND arrival_city = :arrival_city 
                    AND arrival_country = :arrival_country
                ";

                $updateStmt = $this->db->prepare($updateSql);
                $updateStmt->bindValue(':departure_city', $departureCity);
                $updateStmt->bindValue(':departure_country', $departureCountry);
                $updateStmt->bindValue(':arrival_city', $arrivalCity);
                $updateStmt->bindValue(':arrival_country', $arrivalCountry);
                
                return $updateStmt->execute();
            } else {
                // Insert new route
                $route = new PopularRoute($departureCity, $arrivalCity, $departureCountry, $arrivalCountry);
                
                $insertSql = "
                    INSERT INTO popular_routes (departure_city, departure_country, arrival_city, arrival_country, search_count, last_searched)
                    VALUES (:departure_city, :departure_country, :arrival_city, :arrival_country, :search_count, :last_searched)
                ";

                $insertStmt = $this->db->prepare($insertSql);
                $dbArray = $route->toDbArray();
                
                foreach ($dbArray as $key => $value) {
                    $insertStmt->bindValue(':' . $key, $value);
                }
                
                return $insertStmt->execute();
            }

        } catch (PDOException $e) {
            $this->logger->error('Update popular route error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Update city suggestions statistics
     */
    private function updateCitySuggestions(array $cities): bool
    {
        try {
            foreach ($cities as $cityName) {
                if (empty($cityName)) continue;

                $checkSql = "SELECT id FROM city_suggestions WHERE city_name = :city_name";
                $checkStmt = $this->db->prepare($checkSql);
                $checkStmt->bindValue(':city_name', $cityName);
                $checkStmt->execute();

                if ($checkStmt->fetchColumn()) {
                    $updateSql = "
                        UPDATE city_suggestions 
                        SET search_count = search_count + 1, updated_at = CURRENT_TIMESTAMP
                        WHERE city_name = :city_name
                    ";

                    $updateStmt = $this->db->prepare($updateSql);
                    $updateStmt->bindValue(':city_name', $cityName);
                    $updateStmt->execute();
                }
            }

            return true;

        } catch (PDOException $e) {
            $this->logger->error('Update city suggestions error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Delete search alert
     */
    public function deleteSearchAlert(int $alertId, int $userId): bool
    {
        try {
            $sql = "DELETE FROM search_alerts WHERE id = :id AND user_id = :user_id";
            $stmt = $this->db->prepare($sql);
            $stmt->bindValue(':id', $alertId, PDO::PARAM_INT);
            $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
            
            return $stmt->execute();

        } catch (PDOException $e) {
            $this->logger->error('Delete search alert error: ' . $e->getMessage(), ['alert_id' => $alertId, 'user_id' => $userId]);
            return false;
        }
    }

    /**
     * Toggle search alert status
     */
    public function toggleSearchAlert(int $alertId, int $userId): bool
    {
        try {
            $sql = "
                UPDATE search_alerts 
                SET active = NOT active, updated_at = CURRENT_TIMESTAMP
                WHERE id = :id AND user_id = :user_id
            ";
            
            $stmt = $this->db->prepare($sql);
            $stmt->bindValue(':id', $alertId, PDO::PARAM_INT);
            $stmt->bindValue(':user_id', $userId, PDO::PARAM_INT);
            
            return $stmt->execute();

        } catch (PDOException $e) {
            $this->logger->error('Toggle search alert error: ' . $e->getMessage(), ['alert_id' => $alertId, 'user_id' => $userId]);
            return false;
        }
    }
}