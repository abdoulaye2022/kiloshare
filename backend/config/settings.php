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

    'firebase' => [
        'project_id' => $_ENV['FIREBASE_PROJECT_ID'] ?? '',
        'type' => $_ENV['FIREBASE_TYPE'] ?? 'service_account',
        'private_key_id' => $_ENV['FIREBASE_PRIVATE_KEY_ID'] ?? '',
        'private_key' => str_replace('\\n', "\n", $_ENV['FIREBASE_PRIVATE_KEY'] ?? ''),
        'client_email' => $_ENV['FIREBASE_CLIENT_EMAIL'] ?? '',
        'client_id' => $_ENV['FIREBASE_CLIENT_ID'] ?? '',
        'auth_uri' => $_ENV['FIREBASE_AUTH_URI'] ?? 'https://accounts.google.com/o/oauth2/auth',
        'token_uri' => $_ENV['FIREBASE_TOKEN_URI'] ?? 'https://oauth2.googleapis.com/token',
        'auth_provider_x509_cert_url' => $_ENV['FIREBASE_AUTH_PROVIDER_CERT_URL'] ?? 'https://www.googleapis.com/oauth2/v1/certs',
        'client_x509_cert_url' => $_ENV['FIREBASE_CLIENT_CERT_URL'] ?? '',
        'universe_domain' => $_ENV['FIREBASE_UNIVERSE_DOMAIN'] ?? 'googleapis.com',
        'database_url' => $_ENV['FIREBASE_DATABASE_URL'] ?? '',
        'storage_bucket' => $_ENV['FIREBASE_STORAGE_BUCKET'] ?? '',
        'messaging' => [
            'enabled' => filter_var($_ENV['FCM_ENABLED'] ?? true, FILTER_VALIDATE_BOOLEAN),
            'timeout' => (int) ($_ENV['FCM_TIMEOUT'] ?? 30),
            'batch_size' => (int) ($_ENV['FCM_BATCH_SIZE'] ?? 500),
        ],
    ],
];