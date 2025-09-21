<?php

declare(strict_types=1);

namespace KiloShare\Utils;

use Psr\Http\Message\ResponseInterface;
use Slim\Psr7\Response as SlimResponse;

class Response
{
    public static function json(
        array $data, 
        int $statusCode = 200, 
        array $headers = []
    ): ResponseInterface {
        $response = new SlimResponse();
        
        foreach ($headers as $name => $value) {
            $response = $response->withHeader($name, $value);
        }
        
        $response->getBody()->write(json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($statusCode);
    }

    public static function success(
        array $data = [], 
        string $message = 'Success',
        int $statusCode = 200
    ): ResponseInterface {
        return self::json([
            'success' => true,
            'message' => $message,
            'data' => $data,
            'timestamp' => date('Y-m-d H:i:s')
        ], $statusCode);
    }

    public static function error(
        string $message = 'An error occurred',
        array $errors = [],
        int $statusCode = 400,
        ?string $errorCode = null
    ): ResponseInterface {
        $data = [
            'success' => false,
            'message' => $message,
            'timestamp' => date('Y-m-d H:i:s')
        ];

        if (!empty($errors)) {
            $data['errors'] = $errors;
        }

        if ($errorCode) {
            $data['error_code'] = $errorCode;
        }

        return self::json($data, $statusCode);
    }

    public static function unauthorized(string $message = 'Unauthorized'): ResponseInterface
    {
        return self::error($message, [], 401, 'UNAUTHORIZED');
    }

    public static function forbidden(string $message = 'Forbidden'): ResponseInterface
    {
        return self::error($message, [], 403, 'FORBIDDEN');
    }

    public static function notFound(string $message = 'Resource not found'): ResponseInterface
    {
        return self::error($message, [], 404, 'NOT_FOUND');
    }

    public static function validationError(array $errors, string $message = 'Validation failed'): ResponseInterface
    {
        return self::error($message, $errors, 422, 'VALIDATION_ERROR');
    }

    public static function serverError(string $message = 'Internal server error'): ResponseInterface
    {
        return self::error($message, [], 500, 'SERVER_ERROR');
    }

    public static function created(array $data = [], string $message = 'Created successfully'): ResponseInterface
    {
        return self::success($data, $message, 201);
    }

    public static function noContent(): ResponseInterface
    {
        return (new SlimResponse())->withStatus(204);
    }
}