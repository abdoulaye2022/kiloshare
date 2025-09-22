<?php

declare(strict_types=1);

namespace KiloShare\Events;

use KiloShare\Services\SmartNotificationService;

class NotificationEvents
{
    private SmartNotificationService $notificationService;

    public function __construct()
    {
        $this->notificationService = new SmartNotificationService();
    }

    public function onTripCreated(array $trip): void
    {
        $this->notificationService->send(
            $trip['user_id'],
            'trip_published',
            ['trip_id' => $trip['id'], 'trip_title' => $trip['title']],
            ['scope' => 'trip', 'scope_id' => $trip['id']]
        );
    }

    public function onTripCancelled(array $trip): void
    {
        $this->notificationService->send(
            $trip['user_id'],
            'trip_cancelled',
            ['trip_id' => $trip['id'], 'trip_title' => $trip['title']],
            ['scope' => 'trip', 'scope_id' => $trip['id']]
        );
    }

    public function onBookingRequestReceived(array $booking): void
    {
        $this->notificationService->send(
            $booking['driver_id'],
            'booking_received',
            [
                'booking_id' => $booking['id'],
                'passenger_name' => $booking['passenger_name'],
                'trip_title' => $booking['trip_title']
            ],
            ['scope' => 'booking', 'scope_id' => $booking['id'], 'priority' => 'high']
        );
    }

    public function onBookingAccepted(array $booking): void
    {
        $this->notificationService->send(
            $booking['passenger_id'],
            'booking_accepted',
            [
                'booking_id' => $booking['id'],
                'driver_name' => $booking['driver_name'],
                'trip_title' => $booking['trip_title']
            ],
            ['scope' => 'booking', 'scope_id' => $booking['id'], 'priority' => 'high']
        );
    }

    public function onBookingRejected(array $booking): void
    {
        $this->notificationService->send(
            $booking['passenger_id'],
            'booking_rejected',
            [
                'booking_id' => $booking['id'],
                'driver_name' => $booking['driver_name'],
                'trip_title' => $booking['trip_title']
            ],
            ['scope' => 'booking', 'scope_id' => $booking['id']]
        );
    }

    public function onPaymentCompleted(array $payment): void
    {
        $this->notificationService->send(
            $payment['payer_id'],
            'payment_confirmed',
            [
                'payment_id' => $payment['id'],
                'amount' => $payment['amount'],
                'booking_id' => $payment['booking_id']
            ],
            ['scope' => 'payment', 'scope_id' => $payment['id']]
        );

        $this->notificationService->send(
            $payment['receiver_id'],
            'payment_received',
            [
                'payment_id' => $payment['id'],
                'amount' => $payment['amount'],
                'booking_id' => $payment['booking_id']
            ],
            ['scope' => 'payment', 'scope_id' => $payment['id']]
        );
    }

    public function onTripStartingSoon(array $trip): void
    {
        foreach ($trip['participants'] as $participant) {
            $this->notificationService->send(
                $participant['user_id'],
                'trip_starting_soon',
                [
                    'trip_id' => $trip['id'],
                    'trip_title' => $trip['title'],
                    'departure_time' => $trip['departure_date']
                ],
                ['scope' => 'trip', 'scope_id' => $trip['id'], 'priority' => 'high']
            );
        }
    }

    public function onDeliveryCompleted(array $booking): void
    {
        $this->notificationService->send(
            $booking['passenger_id'],
            'delivery_completed',
            [
                'booking_id' => $booking['id'],
                'driver_name' => $booking['driver_name'],
                'trip_title' => $booking['trip_title']
            ],
            ['scope' => 'booking', 'scope_id' => $booking['id']]
        );

        $this->notificationService->send(
            $booking['driver_id'],
            'delivery_confirmed',
            [
                'booking_id' => $booking['id'],
                'passenger_name' => $booking['passenger_name'],
                'trip_title' => $booking['trip_title']
            ],
            ['scope' => 'booking', 'scope_id' => $booking['id']]
        );
    }

    public function onNewMessage(array $message): void
    {
        $this->notificationService->send(
            $message['recipient_id'],
            'new_message',
            [
                'message_id' => $message['id'],
                'sender_name' => $message['sender_name'],
                'message_preview' => substr($message['content'], 0, 100),
                'booking_id' => $message['booking_id']
            ],
            ['scope' => 'message', 'scope_id' => $message['id']]
        );
    }

    public function onPriceNegotiation(array $negotiation): void
    {
        $this->notificationService->send(
            $negotiation['recipient_id'],
            'price_negotiation',
            [
                'negotiation_id' => $negotiation['id'],
                'sender_name' => $negotiation['sender_name'],
                'proposed_price' => $negotiation['proposed_price'],
                'booking_id' => $negotiation['booking_id']
            ],
            ['scope' => 'negotiation', 'scope_id' => $negotiation['id']]
        );
    }

    public function onDocumentRequired(array $booking): void
    {
        $this->notificationService->send(
            $booking['passenger_id'],
            'document_required',
            [
                'booking_id' => $booking['id'],
                'document_type' => $booking['required_document'],
                'trip_title' => $booking['trip_title']
            ],
            ['scope' => 'booking', 'scope_id' => $booking['id'], 'priority' => 'high']
        );
    }

    public function onSystemMaintenance(): void
    {
        // Send to all active users
        $this->notificationService->sendToAll(
            'system_maintenance',
            ['maintenance_date' => date('Y-m-d H:i:s', strtotime('+1 hour'))],
            ['priority' => 'high', 'channels' => ['push', 'in_app']]
        );
    }
}