<?php

declare(strict_types=1);

namespace KiloShare\Middleware;

use KiloShare\Services\JWTService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\RequestHandlerInterface as RequestHandler;

class OptionalAuthMiddleware
{
    private JWTService $jwtService;

    public function __construct(JWTService $jwtService)
    {
        $this->jwtService = $jwtService;
    }

    public function __invoke(Request $request, RequestHandler $handler): Response
    {
        $authHeader = $request->getHeaderLine('Authorization');
        
        if (!empty($authHeader) && preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            $token = $matches[1];

            try {
                $user = $this->jwtService->getUserFromToken($token);
                
                if ($user) {
                    // Normalize user data for API
                    $user = \KiloShare\Models\User::normalizeForApi($user);
                    
                    $request = $request->withAttribute('user', $user);
                    $request = $request->withAttribute('token', $token);
                }
            } catch (\Exception $e) {
                // Continue without user data if token is invalid
            }
        }

        return $handler->handle($request);
    }
}