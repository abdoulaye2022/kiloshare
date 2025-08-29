<?php

declare(strict_types=1);

use Slim\App;
use Slim\Routing\RouteCollectorProxy;

/** @var App $app */

// API v1 routes
$app->group('/api/v1', function (RouteCollectorProxy $group) {
    
    // Auth routes
    $group->post('/auth/register', '\KiloShare\Controllers\AuthController:register');
    $group->post('/auth/login', '\KiloShare\Controllers\AuthController:login');
    $group->post('/auth/refresh', '\KiloShare\Controllers\AuthController:refresh');
    $group->post('/auth/logout', '\KiloShare\Controllers\AuthController:logout');
    
    // User routes
    $group->get('/users/profile', '\KiloShare\Controllers\UserController:getProfile');
    $group->put('/users/profile', '\KiloShare\Controllers\UserController:updateProfile');
    $group->post('/users/avatar', '\KiloShare\Controllers\UserController:uploadAvatar');
    
    // Journey routes
    $group->get('/journeys', '\KiloShare\Controllers\JourneyController:list');
    $group->post('/journeys', '\KiloShare\Controllers\JourneyController:create');
    $group->get('/journeys/{id}', '\KiloShare\Controllers\JourneyController:get');
    $group->put('/journeys/{id}', '\KiloShare\Controllers\JourneyController:update');
    $group->delete('/journeys/{id}', '\KiloShare\Controllers\JourneyController:delete');
    
    // Space routes (luggage space)
    $group->get('/spaces', '\KiloShare\Controllers\SpaceController:list');
    $group->post('/spaces', '\KiloShare\Controllers\SpaceController:create');
    $group->get('/spaces/{id}', '\KiloShare\Controllers\SpaceController:get');
    $group->put('/spaces/{id}', '\KiloShare\Controllers\SpaceController:update');
    $group->delete('/spaces/{id}', '\KiloShare\Controllers\SpaceController:delete');
    
    // Booking routes
    $group->get('/bookings', '\KiloShare\Controllers\BookingController:list');
    $group->post('/bookings', '\KiloShare\Controllers\BookingController:create');
    $group->get('/bookings/{id}', '\KiloShare\Controllers\BookingController:get');
    $group->put('/bookings/{id}', '\KiloShare\Controllers\BookingController:update');
    $group->delete('/bookings/{id}', '\KiloShare\Controllers\BookingController:cancel');
    
    // Payment routes
    $group->post('/payments', '\KiloShare\Controllers\PaymentController:process');
    $group->get('/payments/{id}', '\KiloShare\Controllers\PaymentController:get');
    $group->post('/payments/{id}/refund', '\KiloShare\Controllers\PaymentController:refund');
    
    // Review routes
    $group->get('/reviews', '\KiloShare\Controllers\ReviewController:list');
    $group->post('/reviews', '\KiloShare\Controllers\ReviewController:create');
    $group->get('/reviews/{id}', '\KiloShare\Controllers\ReviewController:get');
    $group->put('/reviews/{id}', '\KiloShare\Controllers\ReviewController:update');
    $group->delete('/reviews/{id}', '\KiloShare\Controllers\ReviewController:delete');
    
    // Notification routes
    $group->get('/notifications', '\KiloShare\Controllers\NotificationController:list');
    $group->put('/notifications/{id}/read', '\KiloShare\Controllers\NotificationController:markAsRead');
    $group->delete('/notifications/{id}', '\KiloShare\Controllers\NotificationController:delete');
    
    // Message routes
    $group->get('/messages', '\KiloShare\Controllers\MessageController:list');
    $group->post('/messages', '\KiloShare\Controllers\MessageController:send');
    $group->get('/messages/{id}', '\KiloShare\Controllers\MessageController:get');
    $group->put('/messages/{id}/read', '\KiloShare\Controllers\MessageController:markAsRead');
    
    // Search routes
    $group->get('/search/journeys', '\KiloShare\Controllers\SearchController:searchJourneys');
    $group->get('/search/spaces', '\KiloShare\Controllers\SearchController:searchSpaces');
    
    // Admin routes
    $group->group('/admin', function (RouteCollectorProxy $adminGroup) {
        $adminGroup->get('/users', '\KiloShare\Controllers\AdminController:getUsers');
        $adminGroup->get('/statistics', '\KiloShare\Controllers\AdminController:getStatistics');
        $adminGroup->put('/users/{id}/status', '\KiloShare\Controllers\AdminController:updateUserStatus');
    });
    
});