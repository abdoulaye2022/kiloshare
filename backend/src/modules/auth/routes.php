<?php

declare(strict_types=1);

use Slim\App;
use Slim\Routing\RouteCollectorProxy;
use KiloShare\Modules\Auth\Controllers\AuthController;
use KiloShare\Modules\Auth\Middleware\AuthMiddleware;

/** @var App $app */

// Auth routes - no authentication required
$app->group('/api/auth', function (RouteCollectorProxy $group) {
    
    // Public auth endpoints
    $group->post('/register', [AuthController::class, 'register']);
    $group->post('/login', [AuthController::class, 'login']);
    $group->post('/refresh-token', [AuthController::class, 'refreshToken']);
    $group->post('/forgot-password', [AuthController::class, 'forgotPassword']);
    $group->post('/reset-password', [AuthController::class, 'resetPassword']);
    
})->add(function ($request, $handler) {
    // Add CORS headers for auth endpoints
    $response = $handler->handle($request);
    return $response
        ->withHeader('Access-Control-Allow-Origin', '*')
        ->withHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Accept, Origin, Authorization')
        ->withHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
});

// Protected auth endpoints - require authentication
$app->group('/api/auth', function (RouteCollectorProxy $group) {
    
    $group->post('/verify-phone', [AuthController::class, 'verifyPhone']);
    $group->post('/logout', [AuthController::class, 'logout']);
    $group->get('/me', [AuthController::class, 'me']);
    
})->add(AuthMiddleware::class);

// Handle preflight OPTIONS requests for auth routes
$app->options('/api/auth/{routes:.+}', function ($request, $response) {
    return $response
        ->withHeader('Access-Control-Allow-Origin', '*')
        ->withHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Accept, Origin, Authorization')
        ->withHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
});