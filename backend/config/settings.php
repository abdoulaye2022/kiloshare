<?php

declare(strict_types=1);

return [
    'displayErrorDetails' => $_ENV['APP_DEBUG'] === 'true',
    'logError' => true,
    'logErrorDetails' => true,
    'logger' => [
        'name' => 'kiloshare-api',
        'path' => __DIR__ . '/../logs/app.log',
        'level' => \Monolog\Logger::DEBUG,
    ],
    'jwt' => [
        'secret' => $_ENV['JWT_SECRET'] ?? 'your_secret_key',
        'access_expires_in' => (int)($_ENV['JWT_ACCESS_EXPIRES_IN'] ?? 3600),
        'refresh_expires_in' => (int)($_ENV['JWT_REFRESH_EXPIRES_IN'] ?? 604800),
        'algorithm' => 'HS256'
    ],
    'upload' => [
        'path' => $_ENV['UPLOAD_PATH'] ?? 'uploads/',
        'max_size' => (int)($_ENV['MAX_FILE_SIZE'] ?? 10485760),
        'allowed_extensions' => explode(',', $_ENV['ALLOWED_EXTENSIONS'] ?? 'jpg,jpeg,png,gif,pdf')
    ],
    'cors' => [
        'allowed_origins' => $_ENV['CORS_ALLOWED_ORIGINS'] ?? '*',
        'allowed_methods' => ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
        'allowed_headers' => ['Content-Type', 'Authorization', 'X-Requested-With']
    ]
];