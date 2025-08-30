<?php

declare(strict_types=1);

use Slim\App;
use Slim\Routing\RouteCollectorProxy;
use KiloShare\Controllers\AuthController;
use KiloShare\Controllers\SocialAuthController;
use KiloShare\Controllers\PhoneAuthController;
use KiloShare\Controllers\TestController;
use KiloShare\Middleware\AuthMiddleware;
use KiloShare\Middleware\OptionalAuthMiddleware;
use KiloShare\Middleware\AdminAuthMiddleware;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

return function (App $app) {
    // Health check endpoint
    $app->get('/', function (Request $request, Response $response) {
        $response->getBody()->write(json_encode([
            'success' => true,
            'message' => 'KiloShare API is running',
            'version' => '1.0.0',
            'timestamp' => date('Y-m-d H:i:s')
        ]));
        return $response->withHeader('Content-Type', 'application/json');
    });

    // API routes group
    $app->group('/api', function (RouteCollectorProxy $group) {
        
        // Auth routes group
        $group->group('/auth', function (RouteCollectorProxy $authGroup) {
            $authGroup->post('/register', [AuthController::class, 'register']);
            $authGroup->post('/login', [AuthController::class, 'login']);
            $authGroup->post('/refresh', [AuthController::class, 'refresh']);
            $authGroup->post('/forgot-password', [AuthController::class, 'forgotPassword']);
            $authGroup->post('/reset-password', [AuthController::class, 'resetPassword']);
            $authGroup->post('/verify-email', [AuthController::class, 'verifyEmail']);
            $authGroup->post('/resend-verification', [AuthController::class, 'resendEmailVerification']);
            
            // Protected auth routes
            $authGroup->post('/logout', [AuthController::class, 'logout'])
                ->add(AuthMiddleware::class);
            $authGroup->get('/me', [AuthController::class, 'me'])
                ->add(AuthMiddleware::class);
            $authGroup->put('/profile', [AuthController::class, 'updateProfile'])
                ->add(AuthMiddleware::class);
            $authGroup->post('/verify-phone', [AuthController::class, 'verifyPhone'])
                ->add(AuthMiddleware::class);
            $authGroup->post('/change-password', [AuthController::class, 'changePassword'])
                ->add(AuthMiddleware::class);
                
            // Phone Authentication Routes
            $authGroup->post('/phone/send-code', [PhoneAuthController::class, 'sendVerificationCode']);
            $authGroup->post('/phone/verify-login', [PhoneAuthController::class, 'verifyCodeAndLogin']);
            
            // Social Authentication Routes
            $authGroup->get('/social/providers', [SocialAuthController::class, 'getProviders']);
            $authGroup->post('/google', [SocialAuthController::class, 'googleAuth']);
            $authGroup->post('/apple', [SocialAuthController::class, 'appleAuth']);
            $authGroup->post('/firebase', [SocialAuthController::class, 'firebaseAuth']);
            
            // Protected social routes
            $authGroup->post('/social/link', [SocialAuthController::class, 'linkSocialAccount'])
                ->add(AuthMiddleware::class);
            $authGroup->delete('/social/unlink/{provider}', [SocialAuthController::class, 'unlinkSocialAccount'])
                ->add(AuthMiddleware::class);
        });

        // V1 API routes (for backward compatibility)
        $group->group('/v1', function (RouteCollectorProxy $v1Group) {
            
            // Auth routes
            $v1Group->group('/auth', function (RouteCollectorProxy $authGroup) {
                $authGroup->post('/register', [AuthController::class, 'register']);
                $authGroup->post('/login', [AuthController::class, 'login']);
                $authGroup->post('/refresh', [AuthController::class, 'refresh']);
                $authGroup->post('/forgot-password', [AuthController::class, 'forgotPassword']);
                $authGroup->post('/reset-password', [AuthController::class, 'resetPassword']);
                $authGroup->post('/verify-email', [AuthController::class, 'verifyEmail']);
                $authGroup->post('/resend-verification', [AuthController::class, 'resendEmailVerification']);
                
                // Protected auth routes
                $authGroup->post('/logout', [AuthController::class, 'logout'])
                    ->add(AuthMiddleware::class);
                $authGroup->get('/me', [AuthController::class, 'me'])
                    ->add(AuthMiddleware::class);
                $authGroup->put('/profile', [AuthController::class, 'updateProfile'])
                    ->add(AuthMiddleware::class);
                $authGroup->post('/verify-phone', [AuthController::class, 'verifyPhone'])
                    ->add(AuthMiddleware::class);
                $authGroup->post('/change-password', [AuthController::class, 'changePassword'])
                    ->add(AuthMiddleware::class);
                    
                // Phone Authentication Routes
                $authGroup->post('/phone/send-code', [PhoneAuthController::class, 'sendVerificationCode']);
                $authGroup->post('/phone/verify-login', [PhoneAuthController::class, 'verifyCodeAndLogin']);
                
                // Social Authentication Routes
                $authGroup->get('/social/providers', [SocialAuthController::class, 'getProviders']);
                $authGroup->post('/google', [SocialAuthController::class, 'googleAuth']);
                $authGroup->post('/apple', [SocialAuthController::class, 'appleAuth']);
                $authGroup->post('/firebase', [SocialAuthController::class, 'firebaseAuth']);
                
                // Protected social routes
                $authGroup->post('/social/link', [SocialAuthController::class, 'linkSocialAccount'])
                    ->add(AuthMiddleware::class);
                $authGroup->delete('/social/unlink/{provider}', [SocialAuthController::class, 'unlinkSocialAccount'])
                    ->add(AuthMiddleware::class);
            });
            
            // Test routes (development only)
            $v1Group->group('/test', function (RouteCollectorProxy $testGroup) {
                $testGroup->get('/email/config', [TestController::class, 'getEmailConfig']);
                $testGroup->post('/email/welcome', [TestController::class, 'testWelcomeEmail']);
                $testGroup->post('/email/verification', [TestController::class, 'testVerificationEmail']);
            });
        });
    });

    // Catch-all route for undefined endpoints
    $app->map(['GET', 'POST', 'PUT', 'DELETE', 'PATCH'], '/{routes:.+}', 
        function (Request $request, Response $response) {
            $response->getBody()->write(json_encode([
                'success' => false,
                'message' => 'Endpoint not found',
                'error_code' => 'NOT_FOUND'
            ]));
            return $response
                ->withStatus(404)
                ->withHeader('Content-Type', 'application/json');
        }
    );
};