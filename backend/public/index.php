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
    
    // Services
    \KiloShare\Services\JWTService::class => function ($container) {
        return new \KiloShare\Services\JWTService($container->get('settings'));
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
            $container->get(PDO::class)
        );
    },
    
    // Controllers
    \KiloShare\Controllers\AuthController::class => function ($container) {
        return new \KiloShare\Controllers\AuthController(
            $container->get(\KiloShare\Services\AuthService::class)
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
            $container->get(\KiloShare\Services\JWTService::class)
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