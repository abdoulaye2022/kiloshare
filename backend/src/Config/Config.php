<?php

declare(strict_types=1);

namespace KiloShare\Config;

class Config
{
    private static ?array $config = null;
    
    public static function get(?string $key = null, $default = null)
    {
        if (self::$config === null) {
            self::loadConfig();
        }
        
        if ($key === null) {
            return self::$config;
        }
        
        $keys = explode('.', $key);
        $value = self::$config;
        
        foreach ($keys as $k) {
            if (!isset($value[$k])) {
                return $default;
            }
            $value = $value[$k];
        }
        
        return $value;
    }
    
    private static function loadConfig(): void
    {
        self::$config = [
            'app' => [
                'name' => $_ENV['APP_NAME'] ?? 'KiloShare',
                'debug' => filter_var($_ENV['APP_DEBUG'] ?? false, FILTER_VALIDATE_BOOLEAN),
                'timezone' => $_ENV['APP_TIMEZONE'] ?? 'UTC',
                'url' => $_ENV['APP_URL'] ?? 'http://localhost',
                'version' => '1.0.0'
            ],
            
            'database' => [
                'host' => $_ENV['DB_HOST'] ?? 'localhost',
                'port' => $_ENV['DB_PORT'] ?? '3306',
                'name' => $_ENV['DB_NAME'] ?? 'kiloshare',
                'user' => $_ENV['DB_USER'] ?? 'root',
                'pass' => $_ENV['DB_PASS'] ?? '',
                'charset' => 'utf8mb4',
                'collation' => 'utf8mb4_unicode_ci'
            ],
            
            'jwt' => [
                'secret' => $_ENV['JWT_SECRET'] ?? 'your-super-secret-jwt-key-change-this-in-production',
                'algorithm' => $_ENV['JWT_ALGORITHM'] ?? 'HS256',
                'access_expires_in' => (int)($_ENV['JWT_ACCESS_EXPIRES_IN'] ?? 3600), // 1 hour
                'refresh_expires_in' => (int)($_ENV['JWT_REFRESH_EXPIRES_IN'] ?? 604800) // 7 days
            ],
            
            'cors' => [
                'allow_origins' => $_ENV['CORS_ALLOW_ORIGINS'] ?? '*',
                'allow_methods' => $_ENV['CORS_ALLOW_METHODS'] ?? 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
                'allow_headers' => $_ENV['CORS_ALLOW_HEADERS'] ?? 'X-Requested-With,Content-Type,Authorization,Origin,Cache-Control,Pragma',
                'allow_credentials' => filter_var($_ENV['CORS_ALLOW_CREDENTIALS'] ?? true, FILTER_VALIDATE_BOOLEAN),
                'max_age' => (int)($_ENV['CORS_MAX_AGE'] ?? 86400)
            ],
            
            'email' => [
                'smtp_host' => $_ENV['SMTP_HOST'] ?? 'localhost',
                'smtp_port' => (int)($_ENV['SMTP_PORT'] ?? 587),
                'smtp_secure' => $_ENV['SMTP_SECURE'] ?? 'tls',
                'smtp_username' => $_ENV['SMTP_USERNAME'] ?? '',
                'smtp_password' => $_ENV['SMTP_PASSWORD'] ?? '',
                'from_address' => $_ENV['MAIL_FROM_ADDRESS'] ?? 'noreply@kiloshare.com',
                'from_name' => $_ENV['MAIL_FROM_NAME'] ?? 'KiloShare',
                'brevo_api_key' => $_ENV['BREVO_API_KEY'] ?? $_ENV['CRON_SECRET_KEY'] ?? ''
            ],
            
            'security' => [
                'bcrypt_cost' => (int)($_ENV['BCRYPT_COST'] ?? 12),
                'max_login_attempts' => (int)($_ENV['MAX_LOGIN_ATTEMPTS'] ?? 5),
                'lockout_duration' => (int)($_ENV['LOCKOUT_DURATION'] ?? 900), // 15 minutes
                'password_min_length' => (int)($_ENV['PASSWORD_MIN_LENGTH'] ?? 6)
            ],
            
            'logging' => [
                'level' => $_ENV['LOG_LEVEL'] ?? 'info',
                'path' => $_ENV['LOG_PATH'] ?? '/var/log/kiloshare.log'
            ],
            
            'social' => [
                'google' => [
                    'client_id' => $_ENV['GOOGLE_CLIENT_ID'] ?? '',
                    'client_secret' => $_ENV['GOOGLE_CLIENT_SECRET'] ?? '',
                    'redirect_uri' => $_ENV['GOOGLE_REDIRECT_URI'] ?? '',
                ],
                'facebook' => [
                    'app_id' => $_ENV['FACEBOOK_APP_ID'] ?? '',
                    'app_secret' => $_ENV['FACEBOOK_APP_SECRET'] ?? '',
                    'redirect_uri' => $_ENV['FACEBOOK_REDIRECT_URI'] ?? '',
                ],
                'apple' => [
                    'client_id' => $_ENV['APPLE_CLIENT_ID'] ?? '',
                    'team_id' => $_ENV['APPLE_TEAM_ID'] ?? '',
                    'key_id' => $_ENV['APPLE_KEY_ID'] ?? '',
                    'private_key_path' => $_ENV['APPLE_PRIVATE_KEY_PATH'] ?? '',
                    'redirect_uri' => $_ENV['APPLE_REDIRECT_URI'] ?? '',
                ],
            ]
        ];
    }
    
    public static function set(string $key, $value): void
    {
        if (self::$config === null) {
            self::loadConfig();
        }
        
        $keys = explode('.', $key);
        $config = &self::$config;
        
        foreach ($keys as $k) {
            if (!isset($config[$k]) || !is_array($config[$k])) {
                $config[$k] = [];
            }
            $config = &$config[$k];
        }
        
        $config = $value;
    }
}