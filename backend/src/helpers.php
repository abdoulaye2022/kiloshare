<?php

if (!function_exists('now')) {
    /**
     * Get current timestamp
     * Laravel-like helper function for compatibility
     */
    function now(): string
    {
        return date('Y-m-d H:i:s');
    }
}