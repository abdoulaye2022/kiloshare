<?php

namespace App\Utils;

use DateTime;

class Logger
{
    private static string $logDir = __DIR__ . '/../../logs';

    /**
     * Log SQL errors to file
     */
    public static function logSqlError(string $query, string $error, array $context = []): void
    {
        $logFile = self::$logDir . '/sql_error.txt';

        // Create log directory if it doesn't exist
        if (!is_dir(self::$logDir)) {
            mkdir(self::$logDir, 0755, true);
        }

        $timestamp = (new DateTime())->format('Y-m-d H:i:s');
        $logEntry = sprintf(
            "[%s] SQL ERROR\n" .
            "Query: %s\n" .
            "Error: %s\n" .
            "Context: %s\n" .
            "Trace: %s\n" .
            "%s\n\n",
            $timestamp,
            $query,
            $error,
            json_encode($context, JSON_PRETTY_PRINT),
            self::getBacktrace(),
            str_repeat('-', 80)
        );

        file_put_contents($logFile, $logEntry, FILE_APPEND);
    }

    /**
     * Log general errors
     */
    public static function logError(string $message, array $context = []): void
    {
        $logFile = self::$logDir . '/error.txt';

        if (!is_dir(self::$logDir)) {
            mkdir(self::$logDir, 0755, true);
        }

        $timestamp = (new DateTime())->format('Y-m-d H:i:s');
        $logEntry = sprintf(
            "[%s] ERROR\n" .
            "Message: %s\n" .
            "Context: %s\n" .
            "Trace: %s\n" .
            "%s\n\n",
            $timestamp,
            $message,
            json_encode($context, JSON_PRETTY_PRINT),
            self::getBacktrace(),
            str_repeat('-', 80)
        );

        file_put_contents($logFile, $logEntry, FILE_APPEND);
    }

    /**
     * Log info messages (only in development)
     */
    public static function logInfo(string $message, array $context = []): void
    {
        if ($_ENV['ENVIRONMENT'] !== 'development') {
            return;
        }

        $logFile = self::$logDir . '/info.txt';

        if (!is_dir(self::$logDir)) {
            mkdir(self::$logDir, 0755, true);
        }

        $timestamp = (new DateTime())->format('Y-m-d H:i:s');
        $logEntry = sprintf(
            "[%s] INFO: %s %s\n",
            $timestamp,
            $message,
            !empty($context) ? json_encode($context) : ''
        );

        file_put_contents($logFile, $logEntry, FILE_APPEND);
    }

    /**
     * Get formatted backtrace
     */
    private static function getBacktrace(): string
    {
        $trace = debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS, 5);
        $formattedTrace = [];

        foreach ($trace as $i => $frame) {
            if ($i === 0) continue; // Skip the Logger class itself

            $file = $frame['file'] ?? 'unknown';
            $line = $frame['line'] ?? 0;
            $function = $frame['function'] ?? 'unknown';
            $class = $frame['class'] ?? '';

            $formattedTrace[] = sprintf(
                "#%d %s%s%s() at %s:%d",
                $i,
                $class,
                $class ? '::' : '',
                $function,
                basename($file),
                $line
            );
        }

        return implode("\n", $formattedTrace);
    }
}
