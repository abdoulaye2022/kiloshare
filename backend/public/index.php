<?php

declare(strict_types=1);

use DI\ContainerBuilder;
use Slim\Factory\AppFactory;
use Slim\Factory\ServerRequestCreatorFactory;
use Slim\ResponseEmitter;

require __DIR__ . '/../vendor/autoload.php';

// Load environment variables
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

// Build DI container
$containerBuilder = new ContainerBuilder();

// Add container definitions
$containerBuilder->addDefinitions([
    'settings' => require __DIR__ . '/../config/settings.php',
    
    // Database PDO
    PDO::class => function () {
        $config = require __DIR__ . '/../config/database.php';
        $dsn = sprintf(
            '%s:host=%s;dbname=%s;charset=%s',
            $config['driver'],
            $config['host'],
            $config['database'],
            $config['charset']
        );
        
        return new PDO($dsn, $config['username'], $config['password'], $config['options']);
    },
    
    // Auth Module Dependencies
    \KiloShare\Modules\Auth\Services\JWTService::class => function ($container) {
        return new \KiloShare\Modules\Auth\Services\JWTService($container->get('settings'));
    },
    
    \KiloShare\Modules\Auth\Models\User::class => function ($container) {
        return new \KiloShare\Modules\Auth\Models\User($container->get(PDO::class));
    },
    
    \KiloShare\Modules\Auth\Services\AuthService::class => function ($container) {
        return new \KiloShare\Modules\Auth\Services\AuthService(
            $container->get(\KiloShare\Modules\Auth\Models\User::class),
            $container->get(\KiloShare\Modules\Auth\Services\JWTService::class),
            $container->get(PDO::class)
        );
    },
    
    \KiloShare\Modules\Auth\Controllers\AuthController::class => function ($container) {
        return new \KiloShare\Modules\Auth\Controllers\AuthController(
            $container->get(\KiloShare\Modules\Auth\Services\AuthService::class)
        );
    },
    
    \KiloShare\Modules\Auth\Middleware\AuthMiddleware::class => function ($container) {
        return new \KiloShare\Modules\Auth\Middleware\AuthMiddleware(
            $container->get(\KiloShare\Modules\Auth\Services\JWTService::class)
        );
    }
]);

$container = $containerBuilder->build();

// Create Slim app
AppFactory::setContainer($container);
$app = AppFactory::create();

// Add error middleware
$errorMiddleware = $app->addErrorMiddleware(
    $container->get('settings')['displayErrorDetails'],
    $container->get('settings')['logError'],
    $container->get('settings')['logErrorDetails']
);

// Add CORS middleware
$app->add(function ($request, $handler) {
    $response = $handler->handle($request);
    return $response
        ->withHeader('Access-Control-Allow-Origin', '*')
        ->withHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Accept, Origin, Authorization')
        ->withHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
});

// Handle preflight OPTIONS requests
$app->options('/{routes:.+}', function ($request, $response) {
    return $response;
});

// Register routes
require __DIR__ . '/../src/Routes/api.php';
require __DIR__ . '/../src/modules/auth/routes.php';

// Health check endpoint
$app->get('/health', function ($request, $response) {
    $payload = [
        'status' => 'OK',
        'timestamp' => date('c'),
        'service' => 'KiloShare API'
    ];
    
    $response->getBody()->write(json_encode($payload));
    return $response->withHeader('Content-Type', 'application/json');
});

// Create server request
$serverRequestCreator = ServerRequestCreatorFactory::create();
$request = $serverRequestCreator->createServerRequestFromGlobals();

// Run app
$response = $app->handle($request);
$responseEmitter = new ResponseEmitter();
$responseEmitter->emit($response);