<?php

declare(strict_types=1);

namespace KiloShare\Middleware;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;

class CorsMiddleware implements MiddlewareInterface
{
    private array $options;

    public function __construct(array $options = [])
    {
        $this->options = array_merge([
            'allowed_origins' => ['*'],
            'allowed_methods' => ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
            'allowed_headers' => ['Content-Type', 'Authorization', 'X-Requested-With'],
            'allow_credentials' => true,
            'max_age' => 86400,
        ], $options);
    }

    public function process(
        ServerRequestInterface $request,
        RequestHandlerInterface $handler
    ): ResponseInterface {
        $origin = $request->getHeaderLine('Origin');
        
        if ($request->getMethod() === 'OPTIONS') {
            // Préflight request
            $response = new \Slim\Psr7\Response();
        } else {
            $response = $handler->handle($request);
        }

        // Configuration des headers CORS
        if ($this->isOriginAllowed($origin)) {
            $response = $response->withHeader('Access-Control-Allow-Origin', $origin);
        } elseif (in_array('*', $this->options['allowed_origins'])) {
            $response = $response->withHeader('Access-Control-Allow-Origin', '*');
        }

        if ($this->options['allow_credentials']) {
            $response = $response->withHeader('Access-Control-Allow-Credentials', 'true');
        }

        $response = $response->withHeader(
            'Access-Control-Allow-Methods',
            implode(', ', $this->options['allowed_methods'])
        );

        $response = $response->withHeader(
            'Access-Control-Allow-Headers',
            implode(', ', $this->options['allowed_headers'])
        );

        if ($request->getMethod() === 'OPTIONS') {
            $response = $response->withHeader('Access-Control-Max-Age', (string) $this->options['max_age']);
        }

        return $response;
    }

    private function isOriginAllowed(string $origin): bool
    {
        if (empty($origin)) {
            return false;
        }

        return in_array($origin, $this->options['allowed_origins'], true);
    }
}