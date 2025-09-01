<?php
require_once __DIR__ . '/vendor/autoload.php';

use src\modules\trips\Models\Trip;

echo "=== Test des règles de transport aérien ===\n\n";

// Créer une instance de Trip pour tester les validations
$trip = new Trip();

// Test 1: Vol domestique canadien (devrait maintenant être AUTORISÉ)
echo "1. Test vol domestique canadien...\n";
$trip->setDepartureCountry('Canada')
     ->setArrivalCountry('Canada')
     ->setFlightNumber('AC123')
     ->setAirline('Air Canada')
     ->setDepartureCity('Toronto')
     ->setArrivalCity('Vancouver')
     ->setDepartureDate('2025-12-25 10:00:00')
     ->setArrivalDate('2025-12-25 15:00:00')
     ->setAvailableWeightKg(10)
     ->setPricePerKg(25)
     ->setCurrency('CAD')
     ->setDescription('Test vol domestique');

$errors = $trip->validate();
echo "Erreurs: " . (empty($errors) ? "AUCUNE ✅" : implode(', ', $errors)) . "\n\n";

// Test 2: Vol international Canada -> Étranger (devrait être AUTORISÉ)
echo "2. Test vol international Canada -> Étranger...\n";
$trip->setDepartureCountry('Canada')
     ->setArrivalCountry('France')
     ->setFlightNumber('AC870')
     ->setAirline('Air Canada')
     ->setDepartureCity('Montreal')
     ->setArrivalCity('Paris');

$errors = $trip->validate();
echo "Erreurs: " . (empty($errors) ? "AUCUNE ✅" : implode(', ', $errors)) . "\n\n";

// Test 3: Vol international Étranger -> Canada (devrait être AUTORISÉ)
echo "3. Test vol international Étranger -> Canada...\n";
$trip->setDepartureCountry('France')
     ->setArrivalCountry('Canada')
     ->setDepartureCity('Paris')
     ->setArrivalCity('Montreal');

$errors = $trip->validate();
echo "Erreurs: " . (empty($errors) ? "AUCUNE ✅" : implode(', ', $errors)) . "\n\n";

// Test 4: Vol étranger -> étranger (devrait être INTERDIT)
echo "4. Test vol étranger -> étranger...\n";
$trip->setDepartureCountry('France')
     ->setArrivalCountry('UK')
     ->setDepartureCity('Paris')
     ->setArrivalCity('London');

$errors = $trip->validate();
echo "Erreurs: " . (empty($errors) ? "AUCUNE" : implode(', ', $errors)) . " ❌ (attendu)\n\n";

// Test 5: Transport terrestre domestique canadien (devrait être AUTORISÉ)
echo "5. Test transport terrestre domestique canadien...\n";
$trip->setDepartureCountry('Canada')
     ->setArrivalCountry('Canada')
     ->setFlightNumber(null)  // Pas de vol
     ->setAirline(null)
     ->setDepartureAirportCode(null)
     ->setArrivalAirportCode(null)
     ->setDepartureCity('Toronto')
     ->setArrivalCity('Ottawa')
     ->setTransportType('car');

$errors = $trip->validate();
echo "Erreurs: " . (empty($errors) ? "AUCUNE ✅" : implode(', ', $errors)) . "\n\n";

// Test 6: Transport terrestre international (devrait être INTERDIT)
echo "6. Test transport terrestre international...\n";
$trip->setDepartureCountry('Canada')
     ->setArrivalCountry('USA')
     ->setDepartureCity('Toronto')
     ->setArrivalCity('New York');

$errors = $trip->validate();
echo "Erreurs: " . (empty($errors) ? "AUCUNE" : implode(', ', $errors)) . " ❌ (attendu)\n\n";

echo "=== Résumé des nouvelles règles ===\n";
echo "✅ Vol domestique canadien: AUTORISÉ\n";
echo "✅ Vol international depuis/vers Canada: AUTORISÉ\n"; 
echo "❌ Vol étranger vers étranger: INTERDIT\n";
echo "✅ Transport terrestre domestique canadien: AUTORISÉ\n";
echo "❌ Transport terrestre international: INTERDIT\n";
echo "\nTest terminé!\n";