<?php

declare(strict_types=1);

namespace KiloShare\Traits;

use KiloShare\Utils\Response;
use Psr\Http\Message\ResponseInterface;

trait HandlesAPIResponses
{
    protected function handleException(\Exception $e, string $context = ''): ResponseInterface
    {
        $message = $context ? "$context: {$e->getMessage()}" : $e->getMessage();
        
        // Log error for debugging
        error_log("[{$context}] " . $e->getMessage() . " in " . $e->getFile() . ":" . $e->getLine());
        
        return Response::error($message, 500);
    }

    protected function validateAndReturnError(array $data, array $rules): ?ResponseInterface
    {
        $validator = new \KiloShare\Utils\Validator();
        
        if (!$validator->validate($data, $rules)) {
            return Response::validationError($validator->getErrors());
        }
        
        return null;
    }
}