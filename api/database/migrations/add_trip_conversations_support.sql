-- Add support for trip-based conversations
-- Created: 2025-09-06

-- Add trip_id column to conversations table to support direct trip messaging
ALTER TABLE conversations 
ADD COLUMN trip_id BIGINT NULL AFTER booking_id,
ADD INDEX idx_trip_id (trip_id);

-- Update the type enum to include trip_inquiry
ALTER TABLE conversations 
MODIFY COLUMN type ENUM('negotiation', 'post_payment', 'support', 'trip_inquiry') DEFAULT 'negotiation';

-- Update the role enum to include more specific roles for trip conversations
ALTER TABLE conversation_participants 
MODIFY COLUMN role ENUM('driver', 'passenger', 'admin', 'trip_owner', 'inquirer') NOT NULL;

-- Allow booking_id to be NULL since trip conversations don't necessarily have bookings yet
ALTER TABLE conversations 
MODIFY COLUMN booking_id BIGINT NULL;

-- Add a constraint to ensure either booking_id or trip_id is present
ALTER TABLE conversations 
ADD CONSTRAINT chk_conversation_reference 
CHECK (booking_id IS NOT NULL OR trip_id IS NOT NULL);