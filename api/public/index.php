<?php

declare(strict_types=1);

// Configuration d'erreurs selon l'environnement
if (($_ENV['APP_ENV'] ?? 'production') === 'development') {
    ini_set('display_errors', '1');
    ini_set('display_startup_errors', '1');
} else {
    ini_set('display_errors', '0');
    ini_set('log_errors', '1');
}

use DI\Container;
use DI\Bridge\Slim\Bridge as SlimAppFactory;
use KiloShare\Utils\Database;
use KiloShare\Middleware\CorsMiddleware;
use KiloShare\Middleware\JsonResponseMiddleware;
use Slim\Middleware\ErrorMiddleware;
use Dotenv\Dotenv;

require_once __DIR__ . '/../vendor/autoload.php';

// Chargement des variables d'environnement
$dotenv = Dotenv::createImmutable(__DIR__ . '/../');
try {
    $dotenv->load();
} catch (Exception $e) {
    // Les variables d'environnement ne sont pas obligatoires en production
    if ($_ENV['APP_ENV'] ?? 'production' === 'development') {
        throw $e;
    }
}

// Chargement de la configuration
$settings = require __DIR__ . '/../config/settings.php';

// Création du conteneur DI
$container = new Container();

// Configuration du conteneur
$container->set('settings', $settings);

// Initialisation de la base de données
Database::initialize();

// Création de l'application Slim
$app = SlimAppFactory::create($container);

// Configuration du base path pour l'hébergement mutualisé
if (($_ENV['APP_ENV'] ?? 'production') !== 'development') {
    // Configurer le base path basé sur l'erreur qu'on voit
    $app->setBasePath('/api.kiloshare');
}

// Configuration des middlewares globaux
$app->addRoutingMiddleware();

// Middleware pour forcer les réponses JSON
$app->add(new JsonResponseMiddleware());

// Middleware CORS
$app->add(new CorsMiddleware($settings['cors']));

// Middleware de gestion des erreurs
$errorMiddleware = $app->addErrorMiddleware(
    $settings['app']['debug'],
    true,
    true
);

// Configuration du gestionnaire d'erreurs personnalisé pour forcer JSON
$errorHandler = $errorMiddleware->getDefaultErrorHandler();
$errorHandler->forceContentType('application/json');

// Gestionnaire d'erreur personnalisé pour s'assurer que TOUTES les réponses sont JSON
$errorHandler->setDefaultErrorRenderer('application/json', function ($exception, $displayErrorDetails) {
    $error = [
        'success' => false,
        'message' => $exception->getMessage() ?: 'An error occurred',
        'timestamp' => date('Y-m-d H:i:s'),
        'error_code' => 'SERVER_ERROR'
    ];
    
    if ($displayErrorDetails) {
        $error['details'] = [
            'type' => get_class($exception),
            'file' => $exception->getFile(),
            'line' => $exception->getLine(),
            'trace' => $exception->getTraceAsString()
        ];
    }
    
    return json_encode($error, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
});

// Chargement des routes
$routes = require __DIR__ . '/../config/routes.php';
$routes($app);

// Headers de sécurité
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');

// Démarrage de l'application
$app->run();