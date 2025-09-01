<?php

namespace App\Modules\Search\Controllers;

use App\Modules\Search\Services\SearchService;
use App\Modules\Search\Models\SearchAlert;
use KiloShare\Services\JWTService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Log\LoggerInterface;

class SearchController
{
    private SearchService $searchService;
    private JWTService $jwtService;
    private LoggerInterface $logger;

    public function __construct(SearchService $searchService, JWTService $jwtService, LoggerInterface $logger)
    {
        $this->searchService = $searchService;
        $this->jwtService = $jwtService;
        $this->logger = $logger;
    }

    /**
     * GET /api/search/trips - Search for trips
     */
    public function searchTrips(Request $request, Response $response): Response
    {
        try {
            $params = $request->getQueryParams();
            $page = (int) ($params['page'] ?? 1);
            $limit = min((int) ($params['limit'] ?? 20), 50); // Max 50 per page

            // Save search to history if user is authenticated
            $authHeader = $request->getHeaderLine('Authorization');
            if ($authHeader && str_starts_with($authHeader, 'Bearer ')) {
                try {
                    $token = substr($authHeader, 7);
                    $decodedToken = $this->jwtService->validateToken($token);
                    $userId = $decodedToken['user_id'];
                    
                    // Save search history (non-blocking)
                    $this->searchService->saveSearchHistory($userId, $params);
                } catch (\Exception $e) {
                    // Don't fail the search if auth fails, just log it
                    $this->logger->info('Search without valid auth: ' . $e->getMessage());
                }
            }

            $results = $this->searchService->searchTrips($params, $page, $limit);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $results,
                'message' => count($results['trips']) . ' voyages trouvés'
            ], JSON_UNESCAPED_UNICODE));

            return $response->withHeader('Content-Type', 'application/json; charset=utf-8');

        } catch (\Exception $e) {
            $this->logger->error('Search trips error: ' . $e->getMessage(), $request->getQueryParams());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la recherche',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }

    /**
     * GET /api/search/suggestions - Get city suggestions
     */
    public function getCitySuggestions(Request $request, Response $response): Response
    {
        try {
            $params = $request->getQueryParams();
            $query = trim($params['q'] ?? '');
            $limit = min((int) ($params['limit'] ?? 10), 20);

            if (strlen($query) < 2) {
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'data' => [],
                    'message' => 'Minimum 2 caractères requis'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $suggestions = $this->searchService->getCitySuggestions($query, $limit);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $suggestions,
                'message' => count($suggestions) . ' suggestions trouvées'
            ], JSON_UNESCAPED_UNICODE));

            return $response->withHeader('Content-Type', 'application/json; charset=utf-8');

        } catch (\Exception $e) {
            $this->logger->error('Get city suggestions error: ' . $e->getMessage(), $request->getQueryParams());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la récupération des suggestions',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }

    /**
     * POST /api/search/save-alert - Save search alert
     */
    public function saveSearchAlert(Request $request, Response $response): Response
    {
        try {
            // Authentication required
            $authHeader = $request->getHeaderLine('Authorization');
            if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Token d\'authentification requis'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(401)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $token = substr($authHeader, 7);
            $decodedToken = $this->jwtService->validateToken($token);
            $userId = $decodedToken['user_id'];

            $data = json_decode($request->getBody()->getContents(), true);

            if (!$data) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Données invalides'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(400)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            // Validate required fields
            if (empty($data['departure_city']) || empty($data['arrival_city'])) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Ville de départ et d\'arrivée requises'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(400)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $alert = new SearchAlert(
                $userId,
                $data['departure_city'],
                $data['arrival_city'],
                $data['departure_country'] ?? 'Canada',
                $data['arrival_country'] ?? 'Canada',
                $data['date_range_start'] ?? null,
                $data['date_range_end'] ?? null,
                isset($data['max_price']) ? (float) $data['max_price'] : null,
                isset($data['max_weight']) ? (int) $data['max_weight'] : null,
                $data['transport_type'] ?? null,
                isset($data['min_rating']) ? (float) $data['min_rating'] : null,
                (bool) ($data['verified_only'] ?? false),
                (bool) ($data['active'] ?? true)
            );

            $alertId = $this->searchService->saveSearchAlert($alert);

            if ($alertId) {
                $alert->setId($alertId);
                
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'data' => $alert->toArray(),
                    'message' => 'Alerte de recherche sauvegardée'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(201)->withHeader('Content-Type', 'application/json; charset=utf-8');
            } else {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Erreur lors de la sauvegarde de l\'alerte'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

        } catch (\Exception $e) {
            $this->logger->error('Save search alert error: ' . $e->getMessage(), ['user_token' => substr($authHeader ?? '', 7, 20) . '...']);
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la sauvegarde de l\'alerte',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }

    /**
     * GET /api/search/recent - Get user's recent searches
     */
    public function getRecentSearches(Request $request, Response $response): Response
    {
        try {
            // Authentication required
            $authHeader = $request->getHeaderLine('Authorization');
            if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Token d\'authentification requis'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(401)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $token = substr($authHeader, 7);
            $decodedToken = $this->jwtService->validateToken($token);
            $userId = $decodedToken['user_id'];

            $params = $request->getQueryParams();
            $limit = min((int) ($params['limit'] ?? 10), 20);

            $recentSearches = $this->searchService->getUserSearchHistory($userId, $limit);

            $searchesData = array_map(function($search) {
                return $search->toArray();
            }, $recentSearches);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $searchesData,
                'message' => count($searchesData) . ' recherches récentes trouvées'
            ], JSON_UNESCAPED_UNICODE));

            return $response->withHeader('Content-Type', 'application/json; charset=utf-8');

        } catch (\Exception $e) {
            $this->logger->error('Get recent searches error: ' . $e->getMessage(), ['user_token' => substr($authHeader ?? '', 7, 20) . '...']);
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la récupération des recherches récentes',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }

    /**
     * GET /api/search/alerts - Get user's search alerts
     */
    public function getUserSearchAlerts(Request $request, Response $response): Response
    {
        try {
            // Authentication required
            $authHeader = $request->getHeaderLine('Authorization');
            if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Token d\'authentification requis'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(401)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $token = substr($authHeader, 7);
            $decodedToken = $this->jwtService->validateToken($token);
            $userId = $decodedToken['user_id'];

            $params = $request->getQueryParams();
            $activeOnly = filter_var($params['active_only'] ?? 'true', FILTER_VALIDATE_BOOLEAN);

            $alerts = $this->searchService->getUserSearchAlerts($userId, $activeOnly);

            $alertsData = array_map(function($alert) {
                return $alert->toArray();
            }, $alerts);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $alertsData,
                'message' => count($alertsData) . ' alertes trouvées'
            ], JSON_UNESCAPED_UNICODE));

            return $response->withHeader('Content-Type', 'application/json; charset=utf-8');

        } catch (\Exception $e) {
            $this->logger->error('Get user search alerts error: ' . $e->getMessage(), ['user_token' => substr($authHeader ?? '', 7, 20) . '...']);
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la récupération des alertes',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }

    /**
     * DELETE /api/search/alerts/{id} - Delete search alert
     */
    public function deleteSearchAlert(Request $request, Response $response, array $args): Response
    {
        try {
            // Authentication required
            $authHeader = $request->getHeaderLine('Authorization');
            if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Token d\'authentification requis'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(401)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $token = substr($authHeader, 7);
            $decodedToken = $this->jwtService->validateToken($token);
            $userId = $decodedToken['user_id'];

            $alertId = (int) $args['id'];

            if (!$alertId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'ID de l\'alerte invalide'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(400)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $deleted = $this->searchService->deleteSearchAlert($alertId, $userId);

            if ($deleted) {
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'message' => 'Alerte supprimée avec succès'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withHeader('Content-Type', 'application/json; charset=utf-8');
            } else {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Alerte non trouvée ou non autorisée'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(404)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

        } catch (\Exception $e) {
            $this->logger->error('Delete search alert error: ' . $e->getMessage(), ['alert_id' => $args['id'] ?? 'unknown']);
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la suppression de l\'alerte',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }

    /**
     * PATCH /api/search/alerts/{id}/toggle - Toggle search alert status
     */
    public function toggleSearchAlert(Request $request, Response $response, array $args): Response
    {
        try {
            // Authentication required
            $authHeader = $request->getHeaderLine('Authorization');
            if (!$authHeader || !str_starts_with($authHeader, 'Bearer ')) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Token d\'authentification requis'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(401)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $token = substr($authHeader, 7);
            $decodedToken = $this->jwtService->validateToken($token);
            $userId = $decodedToken['user_id'];

            $alertId = (int) $args['id'];

            if (!$alertId) {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'ID de l\'alerte invalide'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(400)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

            $toggled = $this->searchService->toggleSearchAlert($alertId, $userId);

            if ($toggled) {
                $response->getBody()->write(json_encode([
                    'success' => true,
                    'message' => 'Statut de l\'alerte modifié avec succès'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withHeader('Content-Type', 'application/json; charset=utf-8');
            } else {
                $response->getBody()->write(json_encode([
                    'success' => false,
                    'message' => 'Alerte non trouvée ou non autorisée'
                ], JSON_UNESCAPED_UNICODE));

                return $response->withStatus(404)->withHeader('Content-Type', 'application/json; charset=utf-8');
            }

        } catch (\Exception $e) {
            $this->logger->error('Toggle search alert error: ' . $e->getMessage(), ['alert_id' => $args['id'] ?? 'unknown']);
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la modification du statut de l\'alerte',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }

    /**
     * GET /api/search/popular-routes - Get popular routes
     */
    public function getPopularRoutes(Request $request, Response $response): Response
    {
        try {
            $params = $request->getQueryParams();
            $limit = min((int) ($params['limit'] ?? 20), 50);

            $popularRoutes = $this->searchService->getPopularRoutes($limit);

            $routesData = array_map(function($route) {
                return $route->toArray();
            }, $popularRoutes);

            $response->getBody()->write(json_encode([
                'success' => true,
                'data' => $routesData,
                'message' => count($routesData) . ' routes populaires trouvées'
            ], JSON_UNESCAPED_UNICODE));

            return $response->withHeader('Content-Type', 'application/json; charset=utf-8');

        } catch (\Exception $e) {
            $this->logger->error('Get popular routes error: ' . $e->getMessage());
            
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Erreur lors de la récupération des routes populaires',
                'error' => $e->getMessage()
            ], JSON_UNESCAPED_UNICODE));

            return $response->withStatus(500)->withHeader('Content-Type', 'application/json; charset=utf-8');
        }
    }
}