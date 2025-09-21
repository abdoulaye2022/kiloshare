<?php

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/database.php';

use KiloShare\Models\Trip;
use KiloShare\Models\Booking;
use KiloShare\Events\NotificationEvents;

$tripModel = new Trip();
$bookingModel = new Booking();
$notificationEvents = new NotificationEvents();

echo "[" . date('Y-m-d H:i:s') . "] Starting trip reminder processor...\n";

try {
    // Get trips starting in the next 2 hours
    $upcomingTrips = $tripModel->getUpcomingTrips(2);
    $reminderCount = 0;

    foreach ($upcomingTrips as $trip) {
        // Get all bookings for this trip
        $bookings = $bookingModel->getTripBookings($trip['id']);
        
        $participants = [];
        $participants[] = ['user_id' => $trip['user_id'], 'role' => 'driver'];
        
        foreach ($bookings as $booking) {
            if ($booking['status'] === 'accepted') {
                $participants[] = ['user_id' => $booking['user_id'], 'role' => 'passenger'];
            }
        }

        if (!empty($participants)) {
            $tripData = array_merge($trip, ['participants' => $participants]);
            $notificationEvents->onTripStartingSoon($tripData);
            $reminderCount++;
            
            echo "[" . date('Y-m-d H:i:s') . "] Sent reminders for trip {$trip['id']} to " . count($participants) . " participants\n";
        }
    }

    // Get trips starting in the next 24 hours (for document reminders)
    $tripsNeedingDocs = $tripModel->getTripsNeedingDocuments(24);
    $docReminderCount = 0;

    foreach ($tripsNeedingDocs as $trip) {
        $bookings = $bookingModel->getTripBookingsNeedingDocs($trip['id']);
        
        foreach ($bookings as $booking) {
            if ($booking['status'] === 'accepted' && empty($booking['document_path'])) {
                $bookingData = array_merge($booking, [
                    'trip_title' => $trip['title'],
                    'required_document' => 'ID Card'
                ]);
                $notificationEvents->onDocumentRequired($bookingData);
                $docReminderCount++;
                
                echo "[" . date('Y-m-d H:i:s') . "] Sent document reminder for booking {$booking['id']}\n";
            }
        }
    }

    echo "[" . date('Y-m-d H:i:s') . "] Trip reminder processor completed. Trip reminders: {$reminderCount}, Document reminders: {$docReminderCount}\n";

} catch (Exception $e) {
    echo "[" . date('Y-m-d H:i:s') . "] Fatal error in trip reminder processor: " . $e->getMessage() . "\n";
    exit(1);
}