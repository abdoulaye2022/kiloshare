<?php

declare(strict_types=1);

namespace KiloShare\Middleware;

use KiloShare\Services\JWTService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\RequestHandlerInterface as RequestHandler;
use Slim\Psr7\Response as SlimResponse;

class AuthMiddleware
{
    private JWTService $jwtService;

    public function __construct(JWTService $jwtService)
    {
        $this->jwtService = $jwtService;
    }

    public function __invoke(Request $request, RequestHandler $handler): Response
    {
        $authHeader = $request->getHeaderLine('Authorization');
        
        if (empty($authHeader)) {
            return $this->unauthorizedResponse('Authorization header missing');
        }

        // Extract token from "Bearer <token>"
        if (!preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $this->unauthorizedResponse('Invalid authorization header format');
        }

        $token = $matches[1];

        try {
            // Validate token and get user data
            $user = $this->jwtService->getUserFromToken($token);
            
            if (!$user) {
                return $this->unauthorizedResponse('Invalid token payload');
            }

            // Normalize user data for API
            $user = \KiloShare\Models\User::normalizeForApi($user);
            
            // Add user data to request attributes
            $request = $request->withAttribute('user', $user);
            $request = $request->withAttribute('token', $token);

            return $handler->handle($request);
        } catch (\RuntimeException $e) {
            return $this->unauthorizedResponse($e->getMessage());
        } catch (\Exception $e) {
            return $this->unauthorizedResponse('Token validation failed');
        }
    }

    private function unauthorizedResponse(string $message): Response
    {
        $response = new SlimResponse();
        $response->getBody()->write(json_encode([
            'success' => false,
            'message' => $message,
            'error_code' => 'UNAUTHORIZED'
        ]));

        return $response
            ->withStatus(401)
            ->withHeader('Content-Type', 'application/json');
    }
}

class AdminAuthMiddleware
{
    private JWTService $jwtService;

    public function __construct(JWTService $jwtService)
    {
        $this->jwtService = $jwtService;
    }

    public function __invoke(Request $request, RequestHandler $handler): Response
    {
        $authHeader = $request->getHeaderLine('Authorization');
        
        if (empty($authHeader)) {
            return $this->forbiddenResponse('Authorization header missing');
        }

        if (!preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $this->forbiddenResponse('Invalid authorization header format');
        }

        $token = $matches[1];

        try {
            $user = $this->jwtService->getUserFromToken($token);
            
            if (!$user) {
                return $this->forbiddenResponse('Invalid token payload');
            }

            // Check if user is admin (you might have a role field in your user table)
            // For now, we'll assume all verified users can access admin routes
            // You should implement proper role-based access control
            // Normalize user data for API
            $user = \KiloShare\Models\User::normalizeForApi($user);
            
            if (!$user['is_verified']) {
                return $this->forbiddenResponse('Admin access required');
            }

            $request = $request->withAttribute('user', $user);
            $request = $request->withAttribute('token', $token);

            return $handler->handle($request);
        } catch (\RuntimeException $e) {
            return $this->forbiddenResponse($e->getMessage());
        } catch (\Exception $e) {
            return $this->forbiddenResponse('Token validation failed');
        }
    }

    private function forbiddenResponse(string $message): Response
    {
        $response = new SlimResponse();
        $response->getBody()->write(json_encode([
            'success' => false,
            'message' => $message,
            'error_code' => 'FORBIDDEN'
        ]));

        return $response
            ->withStatus(403)
            ->withHeader('Content-Type', 'application/json');
    }
}