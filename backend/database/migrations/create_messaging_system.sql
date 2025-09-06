-- KiloShare Messaging System Database Schema
-- Created: 2025-09-06

-- Conversations table - Links users and bookings
CREATE TABLE conversations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    booking_id BIGINT NOT NULL,
    type ENUM('negotiation', 'post_payment', 'support') DEFAULT 'negotiation',
    status ENUM('active', 'archived', 'blocked') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_message_at TIMESTAMP NULL,
    archived_at TIMESTAMP NULL,
    
    INDEX idx_booking_id (booking_id),
    INDEX idx_status (status),
    INDEX idx_last_message (last_message_at)
);

-- Conversation participants - Who can access each conversation
CREATE TABLE conversation_participants (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role ENUM('driver', 'passenger', 'admin') NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    
    UNIQUE KEY unique_participant (conversation_id, user_id),
    INDEX idx_conversation_user (conversation_id, user_id),
    INDEX idx_user_active (user_id, is_active),
    
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);

-- Messages table - Individual messages
CREATE TABLE messages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    sender_id BIGINT NOT NULL,
    message_type ENUM('text', 'image', 'location', 'system', 'action') DEFAULT 'text',
    content TEXT,
    metadata JSON NULL, -- For attachments, coordinates, action data
    
    -- Security and moderation
    is_masked BOOLEAN DEFAULT FALSE,
    masking_reason VARCHAR(100) NULL,
    original_content TEXT NULL, -- Stores original before masking
    moderation_status ENUM('pending', 'approved', 'flagged', 'blocked') DEFAULT 'approved',
    moderation_flags JSON NULL,
    
    -- System messages
    system_action VARCHAR(50) NULL, -- 'booking_accepted', 'payment_confirmed', etc.
    system_data JSON NULL,
    
    -- Message state
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    deleted_by BIGINT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_conversation_created (conversation_id, created_at),
    INDEX idx_sender (sender_id),
    INDEX idx_type (message_type),
    INDEX idx_moderation (moderation_status),
    INDEX idx_system_action (system_action),
    
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);

-- Message reads - Track who read what messages
CREATE TABLE message_reads (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    message_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_read (message_id, user_id),
    INDEX idx_user_read (user_id, read_at),
    INDEX idx_message (message_id),
    
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Message attachments - Files, photos, documents
CREATE TABLE message_attachments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    message_id BIGINT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(100) NOT NULL, -- 'image/jpeg', 'application/pdf', etc.
    file_size BIGINT NOT NULL,
    
    -- Image-specific metadata
    image_width INT NULL,
    image_height INT NULL,
    thumbnail_path VARCHAR(500) NULL,
    
    -- Security
    is_scanned BOOLEAN DEFAULT FALSE,
    scan_status ENUM('pending', 'clean', 'malware', 'suspicious') DEFAULT 'pending',
    
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_message (message_id),
    INDEX idx_type (file_type),
    INDEX idx_scan_status (scan_status),
    
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Quick actions - Booking actions within chat
CREATE TABLE message_quick_actions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    message_id BIGINT NOT NULL,
    action_type ENUM('accept_booking', 'reject_booking', 'counter_offer', 'accept_price', 'reject_price') NOT NULL,
    action_data JSON NOT NULL, -- Price, terms, etc.
    expires_at TIMESTAMP NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP NULL,
    used_by BIGINT NULL,
    
    INDEX idx_message (message_id),
    INDEX idx_action_type (action_type),
    INDEX idx_expires (expires_at),
    
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Contact revelation tracking - When contacts are revealed
CREATE TABLE contact_revelations (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT NOT NULL,
    booking_id BIGINT NOT NULL,
    payment_id BIGINT NULL,
    revealed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revealed_by_system BOOLEAN DEFAULT TRUE,
    
    -- What was revealed
    phone_revealed BOOLEAN DEFAULT FALSE,
    email_revealed BOOLEAN DEFAULT FALSE,
    full_name_revealed BOOLEAN DEFAULT FALSE,
    
    INDEX idx_conversation (conversation_id),
    INDEX idx_booking (booking_id),
    INDEX idx_payment (payment_id),
    
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);

-- Message moderation logs
CREATE TABLE message_moderation_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    message_id BIGINT NOT NULL,
    action ENUM('flagged', 'approved', 'blocked', 'masked') NOT NULL,
    reason VARCHAR(255),
    detected_patterns JSON NULL, -- What patterns were detected
    moderator_id BIGINT NULL, -- NULL for auto-moderation
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_message (message_id),
    INDEX idx_action (action),
    INDEX idx_moderator (moderator_id),
    
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Rate limiting for spam protection
CREATE TABLE message_rate_limits (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    conversation_id BIGINT NOT NULL,
    message_count INT DEFAULT 0,
    window_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_limited BOOLEAN DEFAULT FALSE,
    limited_until TIMESTAMP NULL,
    
    UNIQUE KEY unique_user_conversation (user_id, conversation_id),
    INDEX idx_user (user_id),
    INDEX idx_limited_until (limited_until),
    
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);

-- Insert initial data and triggers

-- System message templates
INSERT INTO message_moderation_logs (message_id, action, reason, created_at) VALUES 
(0, 'approved', 'System initialization', NOW());

-- Create triggers for automatic conversation updates
DELIMITER //

CREATE TRIGGER update_conversation_last_message 
AFTER INSERT ON messages
FOR EACH ROW
BEGIN
    UPDATE conversations 
    SET last_message_at = NEW.created_at,
        updated_at = NEW.created_at
    WHERE id = NEW.conversation_id;
END//

CREATE TRIGGER update_conversation_on_message_update
AFTER UPDATE ON messages
FOR EACH ROW
BEGIN
    IF NEW.updated_at != OLD.updated_at THEN
        UPDATE conversations 
        SET updated_at = NEW.updated_at
        WHERE id = NEW.conversation_id;
    END IF;
END//

DELIMITER ;

-- Create indexes for optimal performance
CREATE INDEX idx_conversations_booking_status ON conversations (booking_id, status);
CREATE INDEX idx_messages_conversation_type_created ON messages (conversation_id, message_type, created_at);
CREATE INDEX idx_participants_user_active_joined ON conversation_participants (user_id, is_active, joined_at);
CREATE INDEX idx_reads_user_created ON message_reads (user_id, read_at DESC);
CREATE INDEX idx_attachments_message_type ON message_attachments (message_id, file_type);