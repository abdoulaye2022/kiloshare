<?php

namespace App\Middleware;

use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface;
use Illuminate\Database\QueryException;
use KiloShare\Utils\Database;
use App\Utils\Logger;

class ErrorLoggingMiddleware implements MiddlewareInterface
{
    public function process(
        ServerRequestInterface $request,
        RequestHandlerInterface $handler
    ): ResponseInterface {
        try {
            return $handler->handle($request);
        } catch (QueryException $e) {
            // Log SQL errors
            Database::logSqlError(
                $e,
                $e->getSql() ?? '',
                $e->getBindings() ?? []
            );

            // Re-throw to let the error handler deal with the response
            throw $e;
        } catch (\PDOException $e) {
            // Log PDO errors
            Logger::logSqlError(
                'PDO Error',
                $e->getMessage(),
                [
                    'file' => $e->getFile(),
                    'line' => $e->getLine(),
                ]
            );

            // Re-throw to let the error handler deal with the response
            throw $e;
        } catch (\Throwable $e) {
            // Log other errors
            Logger::logError($e->getMessage(), [
                'file' => $e->getFile(),
                'line' => $e->getLine(),
                'trace' => $e->getTraceAsString(),
            ]);

            // Re-throw to let the error handler deal with the response
            throw $e;
        }
    }
}
