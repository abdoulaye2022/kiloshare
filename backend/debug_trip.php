<?php
// Script de debug pour tester la sérialisation JSON du trip

require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\Trip;
use Dotenv\Dotenv;

// Chargement des variables d'environnement
$dotenv = Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialisation de la base de données
Database::initialize();

echo "=== DEBUGGING TRIP SERIALIZATION ===\n\n";

try {
    $tripId = isset($argv[1]) ? (int)$argv[1] : 1;
    echo "Testing Trip ID: $tripId\n\n";
    
    $trip = Trip::with(['user', 'images', 'bookings'])->find($tripId);
    
    if (!$trip) {
        echo "❌ Trip not found\n";
        exit(1);
    }
    
    echo "✅ Trip found: " . $trip->title . "\n";
    echo "User: " . ($trip->user ? $trip->user->first_name . ' ' . $trip->user->last_name : 'No user') . "\n";
    echo "Images: " . ($trip->images ? $trip->images->count() : 0) . "\n\n";
    
    // Test de la sérialisation JSON
    echo "=== JSON SERIALIZATION TEST ===\n";
    
    $tripData = [
        'id' => (int) $trip->id,
        'uuid' => (string) ($trip->uuid ?? ''),
        'user_id' => (int) ($trip->user_id ?? 0),
        'title' => (string) ($trip->title ?? ''),
        'description' => (string) ($trip->description ?? ''),
        'departure_city' => (string) ($trip->departure_city ?? ''),
        'departure_country' => (string) ($trip->departure_country ?? ''),
        'arrival_city' => (string) ($trip->arrival_city ?? ''),
        'arrival_country' => (string) ($trip->arrival_country ?? ''),
        'departure_date' => $trip->departure_date ? $trip->departure_date->format('Y-m-d H:i:s') : null,
        'arrival_date' => $trip->arrival_date ? $trip->arrival_date->format('Y-m-d H:i:s') : null,
        'available_weight_kg' => (float) ($trip->available_weight_kg ?? 0),
        'price_per_kg' => (float) ($trip->price_per_kg ?? 0),
        'currency' => (string) ($trip->currency ?? 'EUR'),
        'status' => (string) ($trip->status ?? 'draft'),
        'transport_type' => (string) ($trip->transport_type ?? 'flight'),
        'user_name' => $trip->user ? trim($trip->user->first_name . ' ' . $trip->user->last_name) : 'Unknown',
        'user_email' => $trip->user ? $trip->user->email : '',
        'remaining_weight' => (float) ($trip->available_weight_kg ?? 0),
        'images' => [],
        'image_urls' => [],
        'restrictions' => $trip->restrictions ?? null,
        'special_notes' => $trip->special_notes ?? null,
        'is_domestic' => (bool) ($trip->is_domestic ?? false),
        'total_reward' => (float) ($trip->total_reward ?? 0)
    ];
    
    // Test images
    if ($trip->images && method_exists($trip->images, 'toArray')) {
        $imagesArray = $trip->images->toArray();
        foreach ($imagesArray as $image) {
            if (isset($image['url']) && !empty($image['url'])) {
                $tripData['images'][] = (string) $image['url'];
                $tripData['image_urls'][] = (string) $image['url'];
            }
        }
    }
    
    $json = json_encode([
        'success' => true,
        'message' => 'Success',
        'data' => ['trip' => $tripData],
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
    if ($json === false) {
        echo "❌ JSON encoding failed: " . json_last_error_msg() . "\n";
        echo "JSON error code: " . json_last_error() . "\n";
        
        // Debug chaque champ
        echo "\n=== FIELD BY FIELD DEBUG ===\n";
        foreach ($tripData as $key => $value) {
            $fieldJson = json_encode($value);
            if ($fieldJson === false) {
                echo "❌ Field '$key' failed: " . json_last_error_msg() . "\n";
                echo "   Value: " . var_export($value, true) . "\n";
            } else {
                echo "✅ Field '$key': OK\n";
            }
        }
    } else {
        echo "✅ JSON encoding successful\n";
        echo "JSON length: " . strlen($json) . " characters\n\n";
        
        // Validate JSON by decoding
        $decoded = json_decode($json, true);
        if ($decoded === null) {
            echo "❌ JSON validation failed: " . json_last_error_msg() . "\n";
        } else {
            echo "✅ JSON validation successful\n";
            echo "Decoded trip ID: " . ($decoded['data']['trip']['id'] ?? 'NOT_FOUND') . "\n";
        }
    }
    
    echo "\n=== COMPLETE JSON OUTPUT ===\n";
    echo $json . "\n";
    
} catch (Exception $e) {
    echo "❌ Exception: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . ":" . $e->getLine() . "\n";
    echo "Stack trace: " . $e->getTraceAsString() . "\n";
}