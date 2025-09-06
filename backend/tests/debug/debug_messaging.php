<?php

require 'vendor/autoload.php';

$config = require 'config/database.php';
$capsule = new Illuminate\Database\Capsule\Manager;
$capsule->addConnection($config['connections']['mysql']);
$capsule->setAsGlobal();
$capsule->bootEloquent();

use KiloShare\Models\User;
use KiloShare\Models\Conversation;
use KiloShare\Models\ConversationModel;
use KiloShare\Models\MessageModel;
use KiloShare\Models\Trip;

echo "=== DEBUGGING MESSAGING SYSTEM ===\n";

// 1. Check users
echo "\n1. CHECKING USERS:\n";
$users = User::all();
echo "Total users: " . $users->count() . "\n";
foreach ($users as $user) {
    echo "  - ID: {$user->id}, Name: {$user->first_name} {$user->last_name}, Email: {$user->email}\n";
}

// 2. Check trips  
echo "\n2. CHECKING TRIPS:\n";
$trips = Trip::all();
echo "Total trips: " . $trips->count() . "\n";
foreach ($trips as $trip) {
    echo "  - ID: {$trip->id}, Owner: {$trip->user_id}, Route: {$trip->departure_city} -> {$trip->arrival_city}, Status: {$trip->status}\n";
}

// 3. Check conversations
echo "\n3. CHECKING CONVERSATIONS:\n";
$conversations = \KiloShare\Models\Conversation::all();
echo "Total conversations: " . $conversations->count() . "\n";
foreach ($conversations as $conv) {
    echo "  - ID: {$conv->id}, Trip: {$conv->trip_id}, Status: {$conv->status}\n";
}

// 4. Check messages
echo "\n4. CHECKING MESSAGES:\n";
$messages = \KiloShare\Models\Message::all();
echo "Total messages: " . $messages->count() . "\n";
foreach ($messages->take(5) as $msg) {
    echo "  - ID: {$msg->id}, Conv: {$msg->conversation_id}, Sender: {$msg->sender_id}, Content: " . substr($msg->content, 0, 50) . "...\n";
}

// 5. Test conversation creation logic
echo "\n5. TESTING CONVERSATION CREATION LOGIC:\n";
try {
    $conversationModel = new ConversationModel();
    
    // Test if we can create/get a conversation between user 1 and user 1 (should fail)
    $result = $conversationModel->getOrCreateForTrip(1, 1, 1);
    echo "Same user conversation result: " . ($result ? "SUCCESS" : "FAILED") . "\n";
    
    // Get any user IDs to test with
    if ($users->count() >= 2) {
        $user1Id = $users->first()->id;
        $user2Id = $users->skip(1)->first()->id;
        echo "Testing with User1: $user1Id, User2: $user2Id\n";
        
        $result = $conversationModel->getOrCreateForTrip(1, $user1Id, $user2Id);
        if ($result) {
            echo "Different users conversation: SUCCESS (Conv ID: {$result['id']})\n";
        } else {
            echo "Different users conversation: FAILED\n";
        }
    }
    
} catch (\Exception $e) {
    echo "Error in conversation test: " . $e->getMessage() . "\n";
}

// 6. Test message creation
echo "\n6. TESTING MESSAGE CREATION:\n";
try {
    $messageModel = new MessageModel();
    
    // Get first conversation if exists
    $firstConv = \KiloShare\Models\Conversation::first();
    if ($firstConv && $users->count() > 0) {
        $testContent = "Test message " . date('Y-m-d H:i:s');
        $result = $messageModel->createMessage($firstConv->id, $users->first()->id, 'text', $testContent);
        
        if ($result) {
            echo "Message creation: SUCCESS\n";
            echo "Message ID: {$result['id']}\n";
            echo "Content: {$result['content']}\n";
        } else {
            echo "Message creation: FAILED\n";
        }
    } else {
        echo "No conversation or users available for testing\n";
    }
    
} catch (\Exception $e) {
    echo "Error in message test: " . $e->getMessage() . "\n";
}

echo "\n=== DEBUG COMPLETED ===\n";
?>