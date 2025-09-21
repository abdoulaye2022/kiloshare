-- Script pour créer les tables de messagerie
USE kiloshare;

-- Table des conversations
CREATE TABLE IF NOT EXISTS conversations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    trip_id BIGINT UNSIGNED NOT NULL,
    type ENUM('trip_inquiry', 'negotiation', 'post_payment') DEFAULT 'trip_inquiry',
    status ENUM('active', 'archived', 'blocked') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_conversations_trip (trip_id),
    INDEX idx_conversations_status (status),
    INDEX idx_conversations_created (created_at)
);

-- Table des participants aux conversations
CREATE TABLE IF NOT EXISTS conversation_participants (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    role ENUM('participant', 'observer') DEFAULT 'participant',
    is_active BOOLEAN DEFAULT TRUE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP NULL,
    
    UNIQUE KEY unique_participant (conversation_id, user_id),
    INDEX idx_participants_conversation (conversation_id),
    INDEX idx_participants_user (user_id),
    INDEX idx_participants_active (is_active)
);

-- Table des messages
CREATE TABLE IF NOT EXISTS messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    conversation_id BIGINT UNSIGNED NOT NULL,
    sender_id BIGINT UNSIGNED NOT NULL,
    message_type ENUM('text', 'image', 'location', 'system') DEFAULT 'text',
    content TEXT NOT NULL,
    metadata JSON DEFAULT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_messages_conversation (conversation_id),
    INDEX idx_messages_sender (sender_id),
    INDEX idx_messages_type (message_type),
    INDEX idx_messages_created (created_at),
    INDEX idx_messages_deleted (is_deleted)
);

-- Table des lectures de messages
CREATE TABLE IF NOT EXISTS message_reads (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    message_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_read (message_id, user_id),
    INDEX idx_reads_message (message_id),
    INDEX idx_reads_user (user_id),
    INDEX idx_reads_date (read_at)
);

-- Vérifier que les tables ont été créées
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    CREATE_TIME,
    'Table created successfully' as status
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'kiloshare' 
AND TABLE_NAME IN ('conversations', 'conversation_participants', 'messages', 'message_reads')
ORDER BY TABLE_NAME;