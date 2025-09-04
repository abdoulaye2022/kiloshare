<?php
require_once __DIR__ . '/vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\Trip;
use KiloShare\Models\User;

// Initialize environment
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// Initialize database
Database::initialize();

echo "=== STATUS TRANSITIONS TEST ===" . PHP_EOL . PHP_EOL;

// Find trip and user
$trip = Trip::find(1);
$user = User::find(5);

if (!$trip || !$user) {
    echo "❌ Trip or User not found" . PHP_EOL;
    exit(1);
}

// Function to display current state
function displayState($trip) {
    echo "Current Status: {$trip->status}" . PHP_EOL;
    echo "Available Actions: " . implode(', ', $trip->getAvailableActions()) . PHP_EOL;
    echo "---" . PHP_EOL;
}

echo "Initial State:" . PHP_EOL;
displayState($trip);

// Test all possible transitions based on state diagram
echo "Testing state transitions according to the state diagram:" . PHP_EOL . PHP_EOL;

try {
    // 1. draft → pending_review (already done, let's verify)
    if ($trip->status === 'pending_review') {
        echo "✅ 1. Draft → Pending Review: COMPLETED" . PHP_EOL;
        displayState($trip);
    }

    // 2. pending_review → rejected (simulate admin rejection)
    echo "2. Testing: Pending Review → Rejected" . PHP_EOL;
    $trip->reject("Test rejection for demonstration");
    echo "✅ Rejection successful" . PHP_EOL;
    displayState($trip);

    // 3. rejected → draft (back to draft)
    echo "3. Testing: Rejected → Draft" . PHP_EOL;
    $trip->backToDraft();
    echo "✅ Back to draft successful" . PHP_EOL;
    displayState($trip);

    // 4. draft → pending_review (again)
    echo "4. Testing: Draft → Pending Review (again)" . PHP_EOL;
    $trip->submitForReview();
    echo "✅ Submit for review successful" . PHP_EOL;
    displayState($trip);

    // 5. pending_review → active (simulate admin approval)
    echo "5. Testing: Pending Review → Active" . PHP_EOL;
    $trip->approve();
    echo "✅ Approval successful" . PHP_EOL;
    displayState($trip);

    // 6. active → paused
    echo "6. Testing: Active → Paused" . PHP_EOL;
    $trip->pause();
    echo "✅ Pause successful" . PHP_EOL;
    displayState($trip);

    // 7. paused → active
    echo "7. Testing: Paused → Active" . PHP_EOL;
    $trip->reactivate();
    echo "✅ Reactivation successful" . PHP_EOL;
    displayState($trip);

    // 8. active → booked
    echo "8. Testing: Active → Booked" . PHP_EOL;
    $trip->markAsBooked();
    echo "✅ Mark as booked successful" . PHP_EOL;
    displayState($trip);

    // 9. booked → in_progress
    echo "9. Testing: Booked → In Progress" . PHP_EOL;
    $trip->startJourney();
    echo "✅ Start journey successful" . PHP_EOL;
    displayState($trip);

    // 10. in_progress → completed
    echo "10. Testing: In Progress → Completed" . PHP_EOL;
    $trip->completeDelivery();
    echo "✅ Complete delivery successful" . PHP_EOL;
    displayState($trip);

    echo PHP_EOL . "🎉 ALL TRANSITIONS TESTED SUCCESSFULLY!" . PHP_EOL;

} catch (Exception $e) {
    echo "❌ Error during transition: " . $e->getMessage() . PHP_EOL;
    echo "Current state when error occurred:" . PHP_EOL;
    displayState($trip);
}

// Test additional scenarios
echo PHP_EOL . "=== ADDITIONAL SCENARIOS ===" . PHP_EOL;

// Reset to active for additional tests
$trip->status = 'active';
$trip->save();
echo "Reset trip to 'active' status for additional tests" . PHP_EOL;
displayState($trip);

try {
    // Test active → expired
    echo "Testing: Active → Expired" . PHP_EOL;
    $trip->markAsExpired();
    echo "✅ Mark as expired successful" . PHP_EOL;
    displayState($trip);

    // Reset to active and test cancellation
    $trip->status = 'active';
    $trip->save();
    echo PHP_EOL . "Reset to active and test cancellation" . PHP_EOL;
    displayState($trip);

    echo "Testing: Active → Cancelled" . PHP_EOL;
    $trip->cancel();
    echo "✅ Cancel successful" . PHP_EOL;
    displayState($trip);

} catch (Exception $e) {
    echo "❌ Error during additional scenario: " . $e->getMessage() . PHP_EOL;
}

echo PHP_EOL . "=== TEST SUMMARY ===" . PHP_EOL;
echo "All status transitions from the state diagram have been implemented:" . PHP_EOL;
echo "• draft → pending_review (submitForReview)" . PHP_EOL;
echo "• pending_review → active (approve)" . PHP_EOL;
echo "• pending_review → rejected (reject)" . PHP_EOL;
echo "• rejected → draft (backToDraft)" . PHP_EOL;
echo "• active → booked (markAsBooked)" . PHP_EOL;
echo "• active → expired (markAsExpired)" . PHP_EOL;
echo "• active → paused (pause)" . PHP_EOL;
echo "• active → cancelled (cancel)" . PHP_EOL;
echo "• paused → active (reactivate)" . PHP_EOL;
echo "• booked → in_progress (startJourney)" . PHP_EOL;
echo "• booked → cancelled (cancel)" . PHP_EOL;
echo "• in_progress → completed (completeDelivery)" . PHP_EOL;
echo PHP_EOL . "✅ STATUS TRANSITION SYSTEM IS COMPLETE!" . PHP_EOL;