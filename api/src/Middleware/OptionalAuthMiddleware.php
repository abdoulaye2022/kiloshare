<?php

declare(strict_types=1);

namespace KiloShare\Middleware;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use KiloShare\Models\User;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;
use Exception;

/**
 * Middleware d'authentification optionnelle
 * Analyse le token JWT s'il est présent, mais laisse passer la requête même s'il n'y a pas de token
 */
class OptionalAuthMiddleware implements MiddlewareInterface
{
    private array $jwtConfig;

    public function __construct()
    {
        $settings = require __DIR__ . '/../../config/settings.php';
        $this->jwtConfig = $settings['jwt'];
    }

    public function process(
        ServerRequestInterface $request,
        RequestHandlerInterface $handler
    ): ResponseInterface {
        $authHeader = $request->getHeaderLine('Authorization');

        // Si pas de header d'autorisation, on continue sans utilisateur
        if (empty($authHeader)) {
            return $handler->handle($request);
        }

        // Vérifier le format Bearer
        if (!preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            // Format invalide, on continue sans utilisateur
            return $handler->handle($request);
        }

        $token = $matches[1];

        try {
            $decoded = JWT::decode($token, new Key($this->jwtConfig['secret'], $this->jwtConfig['algorithm']));

            // Vérifier que le token n'est pas expiré
            $now = time();
            if ($decoded->exp < $now) {
                // Token expiré, on continue sans utilisateur
                return $handler->handle($request);
            }

            // Récupérer l'utilisateur
            $userId = null;

            // Check if we have a user object in the token (from AuthController)
            if (isset($decoded->user) && isset($decoded->user->id)) {
                $userId = $decoded->user->id;
            }
            // Fallback to user_id or sub for other token types (JWTHelper)
            else if (isset($decoded->user_id)) {
                $userId = $decoded->user_id;
            }
            else if (isset($decoded->sub)) {
                // If sub is UUID, try to find user by UUID, otherwise use it as ID
                $user = User::where('uuid', $decoded->sub)->first();
                if ($user) {
                    $userId = $user->id;
                } else {
                    $userId = $decoded->sub;
                }
            }

            if (!$userId) {
                // Pas d'ID utilisateur, on continue sans utilisateur
                return $handler->handle($request);
            }

            // If we don't already have the user object, fetch it
            if (!isset($user)) {
                $user = User::find($userId);
            }
            if (!$user) {
                // Utilisateur non trouvé, on continue sans utilisateur
                return $handler->handle($request);
            }

            // Vérifier le statut de l'utilisateur
            if ($user->status !== 'active') {
                // Utilisateur inactif, on continue sans utilisateur
                return $handler->handle($request);
            }

            // Ajouter l'utilisateur à la requête
            $request = $request->withAttribute('user', $user);
            $request = $request->withAttribute('user_id', $user->id);
            $request = $request->withAttribute('user_uuid', $user->uuid);

        } catch (Exception $e) {
            // En cas d'erreur de décodage, on continue sans utilisateur
            error_log("OptionalAuthMiddleware: Token decode error: " . $e->getMessage());
        }

        return $handler->handle($request);
    }
}
