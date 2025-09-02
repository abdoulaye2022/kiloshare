<?php

declare(strict_types=1);

return [
    'app' => [
        'env' => $_ENV['APP_ENV'] ?? 'development',
        'debug' => filter_var($_ENV['APP_DEBUG'] ?? false, FILTER_VALIDATE_BOOLEAN),
        'url' => $_ENV['APP_URL'] ?? 'http://127.0.0.1:8080',
        'timezone' => 'Europe/Paris',
        'locale' => 'fr_FR',
    ],

    'jwt' => [
        'secret' => $_ENV['JWT_SECRET'] ?? 'kiloshare-jwt-secret-key',
        'algorithm' => $_ENV['JWT_ALGORITHM'] ?? 'HS256',
        'access_token_expiry' => (int) ($_ENV['JWT_ACCESS_TOKEN_EXPIRY'] ?? 43200), // 12 hours
        'refresh_token_expiry' => (int) ($_ENV['JWT_REFRESH_TOKEN_EXPIRY'] ?? 604800), // 7 days
        'issuer' => 'kiloshare-api',
        'audience' => 'kiloshare-app',
    ],

    'mail' => [
        'mailer' => $_ENV['MAIL_MAILER'] ?? 'smtp',
        'host' => $_ENV['MAIL_HOST'] ?? 'smtp.gmail.com',
        'port' => (int) ($_ENV['MAIL_PORT'] ?? 587),
        'username' => $_ENV['MAIL_USERNAME'] ?? '',
        'password' => $_ENV['MAIL_PASSWORD'] ?? '',
        'encryption' => $_ENV['MAIL_ENCRYPTION'] ?? 'tls',
        'from' => [
            'address' => $_ENV['MAIL_FROM_ADDRESS'] ?? 'noreply@kiloshare.com',
            'name' => $_ENV['MAIL_FROM_NAME'] ?? 'KiloShare',
        ],
    ],

    'stripe' => [
        'secret_key' => $_ENV['STRIPE_SECRET_KEY'] ?? '',
        'publishable_key' => $_ENV['STRIPE_PUBLISHABLE_KEY'] ?? '',
        'webhook_secret' => $_ENV['STRIPE_WEBHOOK_SECRET'] ?? '',
        'connect_client_id' => $_ENV['STRIPE_CONNECT_CLIENT_ID'] ?? '',
    ],

    'cloudinary' => [
        'cloud_name' => $_ENV['CLOUDINARY_CLOUD_NAME'] ?? '',
        'api_key' => $_ENV['CLOUDINARY_API_KEY'] ?? '',
        'api_secret' => $_ENV['CLOUDINARY_API_SECRET'] ?? '',
        'upload_preset' => $_ENV['CLOUDINARY_UPLOAD_PRESET'] ?? 'kiloshare_uploads',
    ],

    'cors' => [
        'allowed_origins' => explode(',', $_ENV['CORS_ALLOWED_ORIGINS'] ?? '*'),
        'allowed_methods' => explode(',', $_ENV['CORS_ALLOWED_METHODS'] ?? 'GET,POST,PUT,DELETE,OPTIONS'),
        'allowed_headers' => explode(',', $_ENV['CORS_ALLOWED_HEADERS'] ?? 'Content-Type,Authorization,X-Requested-With'),
        'allow_credentials' => true,
        'max_age' => 86400,
    ],

    'logging' => [
        'level' => $_ENV['LOG_LEVEL'] ?? 'info',
        'channel' => $_ENV['LOG_CHANNEL'] ?? 'file',
        'path' => __DIR__ . '/../storage/logs/app.log',
    ],

    'sms' => [
        'twilio' => [
            'sid' => $_ENV['TWILIO_SID'] ?? '',
            'auth_token' => $_ENV['TWILIO_AUTH_TOKEN'] ?? '',
            'phone_number' => $_ENV['TWILIO_PHONE_NUMBER'] ?? '',
        ],
    ],

    'upload' => [
        'max_size' => 10 * 1024 * 1024, // 10MB
        'allowed_types' => ['image/jpeg', 'image/png', 'image/gif', 'application/pdf'],
        'storage_path' => __DIR__ . '/../storage/uploads',
    ],
];