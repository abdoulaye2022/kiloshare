<?php

declare(strict_types=1);

namespace KiloShare\Middleware;

use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as RequestHandler;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use PDO;

class AdminAuthMiddleware implements MiddlewareInterface
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public function process(Request $request, RequestHandler $handler): Response
    {
        $authHeader = $request->getHeaderLine('Authorization');
        
        if (empty($authHeader) || !str_starts_with($authHeader, 'Bearer ')) {
            return $this->unauthorizedResponse();
        }

        $token = substr($authHeader, 7);
        
        try {
            // Decode JWT token
            $decoded = JWT::decode($token, new Key($_ENV['JWT_SECRET'] ?? 'kiloshare-secret-key', 'HS256'));
            
            // Get user from database
            $userId = $decoded->user->id ?? $decoded->user_id ?? null;
            if (!$userId) {
                return $this->unauthorizedResponse();
            }
            
            $stmt = $this->pdo->prepare("SELECT id, email, role FROM users WHERE id = ? AND role = 'admin'");
            $stmt->execute([$userId]);
            $user = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$user) {
                return $this->forbiddenResponse();
            }
            
            // Add user to request attributes
            $request = $request->withAttribute('user', $user);
            $request = $request->withAttribute('user_id', $user['id']);
            
            return $handler->handle($request);
            
        } catch (\Exception $e) {
            error_log('AdminAuthMiddleware: Authentication failed: ' . $e->getMessage());
            return $this->unauthorizedResponse();
        }
    }

    private function unauthorizedResponse(): Response
    {
        $response = new \Slim\Psr7\Response();
        $response->getBody()->write(json_encode([
            'success' => false,
            'message' => 'Token d\'authentification requis',
            'error_code' => 'UNAUTHORIZED'
        ]));
        
        return $response
            ->withStatus(401)
            ->withHeader('Content-Type', 'application/json');
    }

    private function forbiddenResponse(): Response
    {
        $response = new \Slim\Psr7\Response();
        $response->getBody()->write(json_encode([
            'success' => false,
            'message' => 'Accès refusé - Privilèges administrateur requis',
            'error_code' => 'FORBIDDEN'
        ]));
        
        return $response
            ->withStatus(403)
            ->withHeader('Content-Type', 'application/json');
    }
}