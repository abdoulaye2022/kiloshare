<?php

declare(strict_types=1);

namespace KiloShare\Traits;

trait HasJWTConfig
{
    private static ?array $jwtConfig = null;

    protected function getJWTConfig(): array
    {
        if (self::$jwtConfig === null) {
            $settings = require __DIR__ . '/../../config/settings.php';
            self::$jwtConfig = $settings['jwt'];
        }
        return self::$jwtConfig;
    }
}