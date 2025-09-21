<?php

declare(strict_types=1);

namespace KiloShare\Middleware;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use KiloShare\Models\User;
use KiloShare\Utils\Response;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;
use Exception;

class AuthMiddleware implements MiddlewareInterface
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

        if (empty($authHeader)) {
            return Response::unauthorized('Authorization header missing');
        }

        if (!preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return Response::unauthorized('Invalid authorization format');
        }

        $token = $matches[1];

        try {
            $decoded = JWT::decode($token, new Key($this->jwtConfig['secret'], $this->jwtConfig['algorithm']));
            
            // Vérifier que le token n'est pas expiré
            $now = time();
            if ($decoded->exp < $now) {
                return Response::unauthorized('Token has expired');
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
                return Response::unauthorized('Invalid token: missing user ID');
            }
            
            // If we don't already have the user object, fetch it
            if (!isset($user)) {
                $user = User::find($userId);
            }
            if (!$user) {
                return Response::unauthorized('User not found');
            }

            // Vérifier le statut de l'utilisateur
            if ($user->status !== 'active') {
                return Response::unauthorized('User account is not active');
            }

            // Ajouter l'utilisateur à la requête
            $request = $request->withAttribute('user', $user);
            $request = $request->withAttribute('user_id', $user->id);
            $request = $request->withAttribute('user_uuid', $user->uuid);

        } catch (Exception $e) {
            return Response::unauthorized('Invalid or expired token: ' . $e->getMessage());
        }

        return $handler->handle($request);
    }
}