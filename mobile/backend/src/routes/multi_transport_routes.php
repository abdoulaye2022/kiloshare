<?php

use App\Modules\Trips\Controllers\MultiTransportTripController;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Slim\App;

return function (App $app) {
    $app->group('/api/trips', function ($group) {
        
        // Get transport limits
        // GET /api/trips/transport-limits - Get all transport limits
        // GET /api/trips/transport-limits/{type} - Get specific transport limits
        $group->get('/transport-limits[/{type}]', MultiTransportTripController::class . ':getTransportLimits');
        
        // Multi-transport price suggestion
        // POST /api/trips/price-suggestion-multi
        $group->post('/price-suggestion-multi', MultiTransportTripController::class . ':getPriceSuggestionMulti');
        
        // Transport recommendations
        // POST /api/trips/transport-recommendations
        $group->post('/transport-recommendations', MultiTransportTripController::class . ':getTransportRecommendations');
        
        // Vehicle validation (for car trips)
        // POST /api/trips/{id}/validate-vehicle
        $group->post('/{id}/validate-vehicle', MultiTransportTripController::class . ':validateVehicle');
        
        // List trips by transport type
        // GET /api/trips/list-by-transport/{type}
        $group->get('/list-by-transport/{type}', MultiTransportTripController::class . ':listTripsByTransport');
    });
    
    // Add CORS middleware for multi-transport endpoints
    $app->options('/api/trips/{routes:.*}', function (Request $request, Response $response) {
        return $response
            ->withHeader('Access-Control-Allow-Origin', '*')
            ->withHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
            ->withHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
    });
};