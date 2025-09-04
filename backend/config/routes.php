<?php

declare(strict_types=1);

use Slim\App;
use Slim\Routing\RouteCollectorProxy;
use KiloShare\Controllers\AuthController;
use KiloShare\Controllers\AdminController;
use KiloShare\Controllers\TripController;
use KiloShare\Controllers\BookingController;
use KiloShare\Controllers\SearchController;
use KiloShare\Controllers\UserProfileController;
use KiloShare\Controllers\FavoriteController;
use KiloShare\Controllers\MessageController;
use KiloShare\Controllers\NotificationController;
use KiloShare\Controllers\SocialAuthController;
use KiloShare\Middleware\AuthMiddleware;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

return function (App $app) {
    // Health check endpoint
    $app->get('/', function (Request $request, Response $response) {
        $response->getBody()->write(json_encode([
            'success' => true,
            'message' => 'KiloShare API is running',
            'version' => '2.0.0',
            'timestamp' => date('Y-m-d H:i:s')
        ]));
        return $response->withHeader('Content-Type', 'application/json');
    });

    // API routes group
    $app->group('/api', function (RouteCollectorProxy $group) {
        
        // V1 API routes
        $group->group('/v1', function (RouteCollectorProxy $v1Group) {
            
            // Auth routes
            $v1Group->group('/auth', function (RouteCollectorProxy $authGroup) {
                $authGroup->post('/register', [AuthController::class, 'register']);
                $authGroup->post('/login', [AuthController::class, 'login']);
                $authGroup->post('/refresh', [AuthController::class, 'refreshToken']);
                $authGroup->post('/forgot-password', [AuthController::class, 'forgotPassword']);
                $authGroup->post('/reset-password', [AuthController::class, 'resetPassword']);
                $authGroup->get('/verify-email', [AuthController::class, 'verifyEmail']);
                $authGroup->post('/resend-verification', [AuthController::class, 'resendEmailVerification']);
                
                // Protected auth routes
                $authGroup->post('/logout', [AuthController::class, 'logout'])
                    ->add(new AuthMiddleware());
                $authGroup->get('/me', [AuthController::class, 'me'])
                    ->add(new AuthMiddleware());
                $authGroup->put('/profile', [AuthController::class, 'updateProfile'])
                    ->add(new AuthMiddleware());
                $authGroup->post('/change-password', [AuthController::class, 'changePassword'])
                    ->add(new AuthMiddleware());
                
                // Social authentication routes
                $authGroup->post('/google', [SocialAuthController::class, 'googleAuth']);
                $authGroup->post('/apple', [SocialAuthController::class, 'appleAuth']);
            });

            // Admin routes
            $v1Group->group('/admin', function (RouteCollectorProxy $adminGroup) {
                // Admin auth
                $adminGroup->post('/auth/login', [AuthController::class, 'adminLogin']);
                $adminGroup->get('/auth/me', [AuthController::class, 'me'])
                    ->add(new AuthMiddleware());
                
                // Protected admin routes
                $adminGroup->get('/dashboard/stats', [AdminController::class, 'getDashboardStats'])
                    ->add(new AuthMiddleware());
                
                // User management
                $adminGroup->get('/users', [AdminController::class, 'getUsers'])
                    ->add(new AuthMiddleware());
                $adminGroup->get('/users/{id}', [AdminController::class, 'getUser'])
                    ->add(new AuthMiddleware());
                $adminGroup->post('/users/{id}/block', [AdminController::class, 'blockUser'])
                    ->add(new AuthMiddleware());
                $adminGroup->post('/users/{id}/unblock', [AdminController::class, 'unblockUser'])
                    ->add(new AuthMiddleware());
                $adminGroup->post('/users/{id}/verify', [AdminController::class, 'verifyUser'])
                    ->add(new AuthMiddleware());
                
                // Trip management
                $adminGroup->get('/trips/pending', [AdminController::class, 'getPendingTrips'])
                    ->add(new AuthMiddleware());
                $adminGroup->post('/trips/approve', [AdminController::class, 'approveTrip'])
                    ->add(new AuthMiddleware());
                $adminGroup->post('/trips/reject', [AdminController::class, 'rejectTrip'])
                    ->add(new AuthMiddleware());
                $adminGroup->get('/trips', [AdminController::class, 'getAllTrips'])
                    ->add(new AuthMiddleware());
                
                // Payment management
                $adminGroup->get('/payments/stats', [AdminController::class, 'getPaymentStats'])
                    ->add(new AuthMiddleware());
                $adminGroup->get('/payments/transactions', [AdminController::class, 'getPaymentTransactions'])
                    ->add(new AuthMiddleware());
                
                // Stripe connected accounts management
                $adminGroup->get('/stripe/connected-accounts', [AdminController::class, 'getConnectedAccounts'])
                    ->add(new AuthMiddleware());
                $adminGroup->get('/stripe/connected-accounts/stats', [AdminController::class, 'getConnectedAccountsStats'])
                    ->add(new AuthMiddleware());
                $adminGroup->post('/stripe/connected-accounts/{id}/action', [AdminController::class, 'performAccountAction'])
                    ->add(new AuthMiddleware());
            });

            // Public trips (no auth required)
            $v1Group->get('/trips', [TripController::class, 'getPublicTrips']);
            $v1Group->get('/trips/price-suggestion', [TripController::class, 'getPriceSuggestion']);
            $v1Group->get('/trips/{id}', [TripController::class, 'get']);

            // Protected trip routes
            $v1Group->group('/trips', function (RouteCollectorProxy $tripGroup) {
                $tripGroup->post('', [TripController::class, 'create']);
                $tripGroup->put('/{id}', [TripController::class, 'update']);
                $tripGroup->delete('/{id}', [TripController::class, 'delete']);
                $tripGroup->post('/{id}/publish', [TripController::class, 'publishTrip']);
                $tripGroup->post('/{id}/pause', [TripController::class, 'pauseTrip']);
                $tripGroup->post('/{id}/resume', [TripController::class, 'resumeTrip']);
                $tripGroup->post('/{id}/cancel', [TripController::class, 'cancelTrip']);
                $tripGroup->post('/{id}/complete', [TripController::class, 'completeTrip']);
                $tripGroup->post('/{id}/images', [TripController::class, 'addTripImage']);
                $tripGroup->delete('/{id}/images/{imageId}', [TripController::class, 'removeTripImage']);
            })->add(new AuthMiddleware());

            // User trip management
            $v1Group->get('/user/trips', [TripController::class, 'list'])
                ->add(new AuthMiddleware());

            // Search routes
            $v1Group->get('/search/trips', [SearchController::class, 'searchTrips']);
            $v1Group->get('/search/cities', [SearchController::class, 'getCitySuggestions']);
            $v1Group->get('/search/popular-routes', [SearchController::class, 'getPopularRoutes']);
            
            // Protected search routes
            $v1Group->group('/search', function (RouteCollectorProxy $searchGroup) {
                $searchGroup->post('/alerts', [SearchController::class, 'saveSearchAlert']);
                $searchGroup->get('/alerts', [SearchController::class, 'getUserSearchAlerts']);
                $searchGroup->delete('/alerts/{id}', [SearchController::class, 'deleteSearchAlert']);
                $searchGroup->get('/recent', [SearchController::class, 'getRecentSearches']);
            })->add(new AuthMiddleware());

            // Booking routes
            $v1Group->group('/bookings', function (RouteCollectorProxy $bookingGroup) {
                $bookingGroup->post('', [BookingController::class, 'createBookingRequest']);
                $bookingGroup->get('', [BookingController::class, 'getUserBookings']);
                $bookingGroup->get('/{id}', [BookingController::class, 'getBooking']);
                $bookingGroup->post('/{id}/accept', [BookingController::class, 'acceptBooking']);
                $bookingGroup->post('/{id}/reject', [BookingController::class, 'rejectBooking']);
                $bookingGroup->post('/{id}/negotiate', [BookingController::class, 'addNegotiation']);
                $bookingGroup->post('/{id}/payment-ready', [BookingController::class, 'markPaymentReady']);
                $bookingGroup->post('/{id}/photos', [BookingController::class, 'addPackagePhoto']);
            })->add(new AuthMiddleware());

            // User profile routes
            $v1Group->group('/user', function (RouteCollectorProxy $userGroup) {
                $userGroup->get('/profile', [UserProfileController::class, 'getProfile']);
                $userGroup->put('/profile', [UserProfileController::class, 'updateProfile']);
                $userGroup->post('/profile/picture', [UserProfileController::class, 'uploadProfilePicture']);
                $userGroup->delete('/account', [UserProfileController::class, 'deleteAccount']);
            })->add(new AuthMiddleware());

            // Public user profiles
            $v1Group->get('/users/{id}/profile', [UserProfileController::class, 'getUserPublicProfile']);

            // Favorite routes
            $v1Group->group('/favorites', function (RouteCollectorProxy $favGroup) {
                $favGroup->get('', [FavoriteController::class, 'getUserFavorites']);
                $favGroup->post('/trips/{id}/toggle', [FavoriteController::class, 'toggleFavorite']);
                $favGroup->post('/trips/{id}', [FavoriteController::class, 'addToFavorites']);
                $favGroup->delete('/trips/{id}', [FavoriteController::class, 'removeFromFavorites']);
                $favGroup->get('/trips/{id}/status', [FavoriteController::class, 'checkFavoriteStatus']);
            })->add(new AuthMiddleware());

            // Message routes
            $v1Group->group('/messages', function (RouteCollectorProxy $msgGroup) {
                $msgGroup->get('/conversations', [MessageController::class, 'getUserConversations']);
                $msgGroup->get('/bookings/{id}', [MessageController::class, 'getBookingMessages']);
                $msgGroup->post('/bookings/{id}', [MessageController::class, 'sendMessage']);
                $msgGroup->post('/{id}/read', [MessageController::class, 'markAsRead']);
            })->add(new AuthMiddleware());

            // Notification routes
            $v1Group->group('/notifications', function (RouteCollectorProxy $notifGroup) {
                $notifGroup->get('', [NotificationController::class, 'getUserNotifications']);
                $notifGroup->get('/unread-count', [NotificationController::class, 'getUnreadCount']);
                $notifGroup->get('/type/{type}', [NotificationController::class, 'getNotificationsByType']);
                $notifGroup->post('/{id}/read', [NotificationController::class, 'markAsRead']);
                $notifGroup->post('/read-all', [NotificationController::class, 'markAllAsRead']);
                $notifGroup->delete('/{id}', [NotificationController::class, 'deleteNotification']);
            })->add(new AuthMiddleware());

            // Legacy routes compatibility (if needed)
            $v1Group->group('/legacy', function (RouteCollectorProxy $legacyGroup) {
                // Map old route patterns to new controllers
                $legacyGroup->get('/annonces', [TripController::class, 'getPublicTrips']);
                $legacyGroup->get('/annonces/{id}', [TripController::class, 'getTrip']);
                $legacyGroup->post('/demandes', [BookingController::class, 'createBookingRequest'])
                    ->add(new AuthMiddleware());
                $legacyGroup->get('/recherche', [SearchController::class, 'searchTrips']);
                $legacyGroup->get('/utilisateur/favoris', [FavoriteController::class, 'getUserFavorites'])
                    ->add(new AuthMiddleware());
            });
        });
    });

    // Catch-all route for undefined endpoints
    $app->map(['GET', 'POST', 'PUT', 'DELETE', 'PATCH'], '/{routes:.+}', 
        function (Request $request, Response $response) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Endpoint not found',
                'error_code' => 'NOT_FOUND',
                'requested_path' => $request->getUri()->getPath(),
                'method' => $request->getMethod()
            ]));
            return $response
                ->withStatus(404)
                ->withHeader('Content-Type', 'application/json');
        }
    );
};