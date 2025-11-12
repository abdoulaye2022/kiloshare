<?php

declare(strict_types=1);

namespace KiloShare\Utils;

use Illuminate\Container\Container;
use Illuminate\Database\Capsule\Manager as Capsule;
use Illuminate\Events\Dispatcher;
use App\Utils\Logger;

class Database
{
    private static ?Capsule $capsule = null;

    public static function initialize(): void
    {
        if (self::$capsule !== null) {
            return;
        }

        $config = require __DIR__ . '/../../config/database.php';
        
        self::$capsule = new Capsule();
        
        // Configuration des connexions
        foreach ($config['connections'] as $name => $connectionConfig) {
            self::$capsule->addConnection($connectionConfig, $name);
        }

        // Configuration par défaut
        self::$capsule->getDatabaseManager()->setDefaultConnection($config['default']);

        // Configuration des événements Eloquent
        self::$capsule->setEventDispatcher(new Dispatcher(new Container()));

        // Configuration globale d'Eloquent
        self::$capsule->setAsGlobal();
        self::$capsule->bootEloquent();

        // Activation du query logging si en mode debug
        $settings = require __DIR__ . '/../../config/settings.php';
        if ($settings['app']['debug']) {
            self::$capsule->connection()->enableQueryLog();
        }

        // Capture des erreurs SQL
        self::setupErrorLogging();
    }

    public static function getCapsule(): Capsule
    {
        if (self::$capsule === null) {
            self::initialize();
        }

        return self::$capsule;
    }

    public static function getConnection(?string $name = null)
    {
        return self::getCapsule()->connection($name);
    }

    public static function getSchema(?string $connection = null)
    {
        return self::getCapsule()->schema($connection);
    }

    public static function beginTransaction(): void
    {
        self::getCapsule()->connection()->beginTransaction();
    }

    public static function commit(): void
    {
        self::getCapsule()->connection()->commit();
    }

    public static function rollBack(): void
    {
        self::getCapsule()->connection()->rollBack();
    }

    public static function getQueryLog(): array
    {
        return self::getCapsule()->connection()->getQueryLog();
    }

    public static function enableQueryLog(): void
    {
        self::getCapsule()->connection()->enableQueryLog();
    }

    public static function disableQueryLog(): void
    {
        self::getCapsule()->connection()->disableQueryLog();
    }

    /**
     * Configure SQL error logging
     */
    private static function setupErrorLogging(): void
    {
        // Listen to query execution failures
        self::getCapsule()->connection()->listen(function ($query) {
            // This is called for successful queries - we skip logging here
        });

        // Set PDO error mode to exception to catch SQL errors
        $pdo = self::getCapsule()->connection()->getPdo();
        $pdo->setAttribute(\PDO::ATTR_ERRMODE, \PDO::ERRMODE_EXCEPTION);
    }

    /**
     * Log SQL error
     */
    public static function logSqlError(\Throwable $exception, string $query = '', array $bindings = []): void
    {
        $fullQuery = $query;
        if (!empty($bindings)) {
            foreach ($bindings as $binding) {
                $value = is_string($binding) ? "'$binding'" : $binding;
                $fullQuery = preg_replace('/\?/', (string)$value, $fullQuery, 1);
            }
        }

        Logger::logSqlError(
            $fullQuery ?: $exception->getMessage(),
            $exception->getMessage(),
            [
                'file' => $exception->getFile(),
                'line' => $exception->getLine(),
                'bindings' => $bindings,
            ]
        );
    }
}