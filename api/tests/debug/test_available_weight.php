<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\Trip;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "Testing available weight calculation..." . PHP_EOL . PHP_EOL;

$tripId = 1;
$trip = Trip::with(['bookings'])->find($tripId);

if (!$trip) {
    echo "❌ Trip $tripId not found" . PHP_EOL;
    exit(1);
}

echo "=== TRIP INFO ===" . PHP_EOL;
echo "Trip ID: {$trip->id}" . PHP_EOL;
echo "Title: {$trip->title}" . PHP_EOL;
echo "available_weight_kg (database): {$trip->available_weight_kg}" . PHP_EOL;

echo PHP_EOL . "=== BOOKING INFO ===" . PHP_EOL;
echo "Total bookings: " . $trip->bookings->count() . PHP_EOL;

if ($trip->bookings->count() > 0) {
    foreach ($trip->bookings as $booking) {
        echo "  Booking {$booking->id}: status={$booking->status}, weight=" . ($booking->weight ?? 'NULL') . PHP_EOL;
    }
} else {
    echo "  No bookings found" . PHP_EOL;
}

echo PHP_EOL . "=== AVAILABLE WEIGHT CALCULATION ===" . PHP_EOL;

try {
    // Test the bookings sum query directly
    $confirmedBookings = $trip->bookings()
        ->whereIn('status', ['confirmed', 'in_progress', 'completed'])
        ->get();
    
    echo "Confirmed bookings count: " . $confirmedBookings->count() . PHP_EOL;
    
    if ($confirmedBookings->count() > 0) {
        foreach ($confirmedBookings as $booking) {
            echo "  Confirmed booking {$booking->id}: weight=" . ($booking->weight ?? 'NULL') . PHP_EOL;
        }
    }
    
    $bookedWeight = $trip->bookings()
        ->whereIn('status', ['confirmed', 'in_progress', 'completed'])
        ->sum('weight');
    
    echo "Total booked weight: {$bookedWeight}" . PHP_EOL;
    echo "Available weight kg: {$trip->available_weight_kg}" . PHP_EOL;
    echo "Calculated available weight: " . max(0.0, (float)$trip->available_weight_kg - (float)$bookedWeight) . PHP_EOL;
    
} catch (\Exception $e) {
    echo "❌ Error in booking calculation: " . $e->getMessage() . PHP_EOL;
    echo "Stack trace: " . $e->getTraceAsString() . PHP_EOL;
}

echo PHP_EOL . "=== ACCESSOR TEST ===" . PHP_EOL;
try {
    $availableWeight = $trip->available_weight;
    echo "available_weight accessor result: {$availableWeight}" . PHP_EOL;
} catch (\Exception $e) {
    echo "❌ Error in accessor: " . $e->getMessage() . PHP_EOL;
    echo "Stack trace: " . $e->getTraceAsString() . PHP_EOL;
}

echo PHP_EOL . "=== DATABASE SCHEMA CHECK ===" . PHP_EOL;
// Check if bookings table has a weight column
try {
    $bookingsSchema = Database::getSchema()->getColumnListing('bookings');
    echo "Bookings table columns: " . implode(', ', $bookingsSchema) . PHP_EOL;
    
    if (!in_array('weight', $bookingsSchema)) {
        echo "⚠️  WARNING: 'weight' column not found in bookings table!" . PHP_EOL;
    }
} catch (\Exception $e) {
    echo "❌ Error checking schema: " . $e->getMessage() . PHP_EOL;
}