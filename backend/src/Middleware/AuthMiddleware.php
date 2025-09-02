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
            $user = User::find($decoded->user->id);
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