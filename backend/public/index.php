<?php

declare(strict_types=1);

use DI\ContainerBuilder;
use Slim\Factory\AppFactory;
use Slim\Factory\ServerRequestCreatorFactory;
use Slim\ResponseEmitter;
use KiloShare\Config\Database;
use KiloShare\Config\Config;

require __DIR__ . '/../vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

// Build DI container
$containerBuilder = new ContainerBuilder();

// Add container definitions
$containerBuilder->addDefinitions([
    'settings' => [
        'displayErrorDetails' => Config::get('app.debug', false),
        'logError' => true,
        'logErrorDetails' => Config::get('app.debug', false),
        'jwt' => [
            'secret' => Config::get('jwt.secret'),
            'algorithm' => Config::get('jwt.algorithm'),
            'access_expires_in' => Config::get('jwt.access_expires_in'),
            'refresh_expires_in' => Config::get('jwt.refresh_expires_in')
        ]
    ],
    
    // Database PDO
    PDO::class => function () {
        return Database::getConnection();
    },
    
    // Logger
    Psr\Log\LoggerInterface::class => function () {
        $logger = new \Monolog\Logger('kiloshare');
        $handler = new \Monolog\Handler\StreamHandler('php://stderr', \Monolog\Level::Debug);
        $logger->pushHandler($handler);
        return $logger;
    },
    
    // Services
    \KiloShare\Services\JWTService::class => function ($container) {
        return new \KiloShare\Services\JWTService(Config::get());
    },
    
    \KiloShare\Services\EmailService::class => function ($container) {
        return new \KiloShare\Services\EmailService(Config::get());
    },
    
    \KiloShare\Services\TwilioSmsService::class => function ($container) {
        return new \KiloShare\Services\TwilioSmsService(
            Config::get('twilio.sid'),
            Config::get('twilio.token'),
            Config::get('twilio.from')
        );
    },
    
    \KiloShare\Services\PhoneVerificationService::class => function ($container) {
        return new \KiloShare\Services\PhoneVerificationService(
            $container->get(PDO::class),
            $container->get(\KiloShare\Services\TwilioSmsService::class)
        );
    },
    
    // Models
    \KiloShare\Models\User::class => function ($container) {
        return new \KiloShare\Models\User($container->get(PDO::class));
    },
    
    // Services with dependencies
    \KiloShare\Services\AuthService::class => function ($container) {
        return new \KiloShare\Services\AuthService(
            $container->get(\KiloShare\Models\User::class),
            $container->get(\KiloShare\Services\JWTService::class),
            $container->get(\KiloShare\Services\EmailService::class),
            $container->get(PDO::class)
        );
    },
    
    \KiloShare\Services\SocialAuthService::class => function ($container) {
        return new \KiloShare\Services\SocialAuthService(
            $container->get(\KiloShare\Models\User::class),
            $container->get(\KiloShare\Services\JWTService::class),
            $container->get(\KiloShare\Services\EmailService::class),
            Config::get('social') // Configuration sociale depuis Config.php
        );
    },
    
    // Controllers
    \KiloShare\Controllers\AuthController::class => function ($container) {
        return new \KiloShare\Controllers\AuthController(
            $container->get(\KiloShare\Services\AuthService::class)
        );
    },
    
    \KiloShare\Controllers\SocialAuthController::class => function ($container) {
        return new \KiloShare\Controllers\SocialAuthController(
            $container->get(\KiloShare\Services\SocialAuthService::class)
        );
    },
    
    \KiloShare\Controllers\TestController::class => function ($container) {
        return new \KiloShare\Controllers\TestController(
            $container->get(\KiloShare\Services\EmailService::class)
        );
    },
    
    \KiloShare\Controllers\PhoneAuthController::class => function ($container) {
        return new \KiloShare\Controllers\PhoneAuthController(
            $container->get(PDO::class),
            $container->get(\KiloShare\Services\JWTService::class),
            $container->get(\KiloShare\Services\PhoneVerificationService::class),
            $container->get(\KiloShare\Services\TwilioSmsService::class)
        );
    },
    
    // Profile services
    \App\Services\FtpUploadService::class => function ($container) {
        return new \App\Services\FtpUploadService();
    },
    
    \App\Modules\Profile\Services\ProfileService::class => function ($container) {
        return new \App\Modules\Profile\Services\ProfileService(
            $container->get(PDO::class)
        );
    },
    
    \App\Modules\Profile\Controllers\ProfileController::class => function ($container) {
        return new \App\Modules\Profile\Controllers\ProfileController(
            $container->get(\App\Modules\Profile\Services\ProfileService::class),
            $container->get(\App\Services\FtpUploadService::class),
            $container->get(Psr\Log\LoggerInterface::class)
        );
    },
    
    // Trip services
    \App\Modules\Trips\Services\PriceCalculatorService::class => function ($container) {
        return new \App\Modules\Trips\Services\PriceCalculatorService(
            $container->get(PDO::class)
        );
    },
    
    \App\Modules\Trips\Services\TripService::class => function ($container) {
        return new \App\Modules\Trips\Services\TripService(
            $container->get(\App\Modules\Trips\Services\PriceCalculatorService::class),
            $container->get(PDO::class)
        );
    },
    
    \App\Modules\Trips\Services\TripImageService::class => function ($container) {
        return new \App\Modules\Trips\Services\TripImageService(
            $container->get(PDO::class)
        );
    },
    
    \App\Modules\Trips\Controllers\TripController::class => function ($container) {
        return new \App\Modules\Trips\Controllers\TripController(
            $container->get(\App\Modules\Trips\Services\TripService::class),
            $container->get(\App\Modules\Trips\Services\TripImageService::class),
            $container->get(Psr\Log\LoggerInterface::class)
        );
    },
    
    // Middleware
    \KiloShare\Middleware\AuthMiddleware::class => function ($container) {
        return new \KiloShare\Middleware\AuthMiddleware(
            $container->get(\KiloShare\Services\JWTService::class)
        );
    },
    
    \KiloShare\Middleware\OptionalAuthMiddleware::class => function ($container) {
        return new \KiloShare\Middleware\OptionalAuthMiddleware(
            $container->get(\KiloShare\Services\JWTService::class)
        );
    },
    
    \KiloShare\Middleware\AdminAuthMiddleware::class => function ($container) {
        return new \KiloShare\Middleware\AdminAuthMiddleware(
            $container->get(PDO::class)
        );
    }
]);

$container = $containerBuilder->build();

// Create Slim app
AppFactory::setContainer($container);
$app = AppFactory::create();

// Add error middleware
$errorMiddleware = $app->addErrorMiddleware(
    Config::get('app.debug', false),
    true,
    Config::get('app.debug', false)
);

// Add CORS middleware
$app->add(function ($request, $handler) use ($container) {
    $response = $handler->handle($request);
    return $response
        ->withHeader('Access-Control-Allow-Origin', Config::get('cors.allow_origins', '*'))
        ->withHeader('Access-Control-Allow-Headers', Config::get('cors.allow_headers', 'X-Requested-With, Content-Type, Accept, Origin, Authorization'))
        ->withHeader('Access-Control-Allow-Methods', Config::get('cors.allow_methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS'))
        ->withHeader('Access-Control-Allow-Credentials', Config::get('cors.allow_credentials', true) ? 'true' : 'false');
});

// Handle preflight OPTIONS requests
$app->options('/{routes:.+}', function ($request, $response) {
    return $response;
});

// Register routes
$routes = require __DIR__ . '/../src/Config/routes.php';
$routes($app);

// Create server request
$serverRequestCreator = ServerRequestCreatorFactory::create();
$request = $serverRequestCreator->createServerRequestFromGlobals();

// Run app
$response = $app->handle($request);
$responseEmitter = new ResponseEmitter();
$responseEmitter->emit($response);