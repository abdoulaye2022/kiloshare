<?php

declare(strict_types=1);

// Configuration PHP pour éviter les erreurs dans les réponses JSON
ini_set('display_errors', '0');
ini_set('log_errors', '1');

use DI\Container;
use DI\Bridge\Slim\Bridge as SlimAppFactory;
use KiloShare\Utils\Database;
use KiloShare\Middleware\CorsMiddleware;
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

// Configuration des middlewares globaux
$app->addRoutingMiddleware();

// Middleware CORS
$app->add(new CorsMiddleware($settings['cors']));

// Middleware de gestion des erreurs
$errorMiddleware = $app->addErrorMiddleware(
    $settings['app']['debug'],
    true,
    true
);

// Configuration du gestionnaire d'erreurs
$errorHandler = $errorMiddleware->getDefaultErrorHandler();
$errorHandler->forceContentType('application/json');

// Chargement des routes
$routes = require __DIR__ . '/../config/routes.php';
$routes($app);

// Headers de sécurité
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');

// Démarrage de l'application
$app->run();