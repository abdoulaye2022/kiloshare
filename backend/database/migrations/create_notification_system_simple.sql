-- =====================================================
-- SYSTÈME COMPLET DE NOTIFICATIONS KILOSHARE - VERSION SIMPLE
-- =====================================================

-- 1. Table des notifications générales
CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSON DEFAULT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    priority ENUM('low', 'normal', 'high', 'critical') DEFAULT 'normal',
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    
    INDEX idx_user_type (user_id, type),
    INDEX idx_user_read (user_id, is_read),
    INDEX idx_priority (priority),
    INDEX idx_created_at (created_at),
    INDEX idx_expires_at (expires_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 2. Table des préférences de notification par utilisateur
CREATE TABLE IF NOT EXISTS user_notification_preferences (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    
    -- Canaux globaux
    push_enabled BOOLEAN DEFAULT TRUE,
    email_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT TRUE,
    in_app_enabled BOOLEAN DEFAULT TRUE,
    marketing_enabled BOOLEAN DEFAULT FALSE,
    
    -- Heures silencieuses
    quiet_hours_enabled BOOLEAN DEFAULT TRUE,
    quiet_hours_start TIME DEFAULT '22:00:00',
    quiet_hours_end TIME DEFAULT '08:00:00',
    timezone VARCHAR(50) DEFAULT 'Europe/Paris',
    
    -- Préférences par type de notification
    trip_updates_push BOOLEAN DEFAULT TRUE,
    trip_updates_email BOOLEAN DEFAULT TRUE,
    booking_updates_push BOOLEAN DEFAULT TRUE,
    booking_updates_email BOOLEAN DEFAULT TRUE,
    payment_updates_push BOOLEAN DEFAULT TRUE,
    payment_updates_email BOOLEAN DEFAULT TRUE,
    security_alerts_push BOOLEAN DEFAULT TRUE,
    security_alerts_email BOOLEAN DEFAULT TRUE,
    
    language VARCHAR(5) DEFAULT 'fr',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 3. Table des logs de notifications
CREATE TABLE IF NOT EXISTS notification_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    notification_id BIGINT UNSIGNED NULL,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    channel ENUM('push', 'email', 'sms', 'in_app') NOT NULL,
    
    -- Contenu
    recipient VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSON DEFAULT NULL,
    
    -- Statut
    status ENUM('pending', 'sent', 'delivered', 'opened', 'failed', 'cancelled') DEFAULT 'pending',
    sent_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    opened_at TIMESTAMP NULL,
    failed_at TIMESTAMP NULL,
    
    -- Erreur
    error_message TEXT NULL,
    retry_count INT DEFAULT 0,
    retry_after TIMESTAMP NULL,
    
    -- Métadonnées
    provider VARCHAR(50) NULL,
    provider_message_id VARCHAR(255) NULL,
    cost_cents INT DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_user_channel (user_id, channel),
    INDEX idx_type_status (type, status),
    INDEX idx_sent_at (sent_at),
    INDEX idx_retry_after (retry_after),
    INDEX idx_provider_message_id (provider_message_id),
    
    FOREIGN KEY (notification_id) REFERENCES notifications(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 4. Table des templates de notification
CREATE TABLE IF NOT EXISTS notification_templates (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    channel ENUM('push', 'email', 'sms', 'in_app') NOT NULL,
    language VARCHAR(5) DEFAULT 'fr',
    
    -- Contenu du template
    subject VARCHAR(255) NULL,
    title VARCHAR(255) NULL,
    message TEXT NOT NULL,
    html_content TEXT NULL,
    
    -- Variables supportées
    variables JSON DEFAULT NULL,
    
    -- Métadonnées
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_template (type, channel, language),
    INDEX idx_type (type),
    INDEX idx_channel (channel),
    INDEX idx_language (language),
    INDEX idx_active (is_active)
);

-- 5. Table des notifications en queue
CREATE TABLE IF NOT EXISTS notification_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    type VARCHAR(50) NOT NULL,
    channel ENUM('push', 'email', 'sms', 'in_app') NOT NULL,
    
    -- Priorité et timing
    priority ENUM('low', 'normal', 'high', 'critical') DEFAULT 'normal',
    scheduled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    
    -- Contenu
    recipient VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSON DEFAULT NULL,
    
    -- Statut
    status ENUM('pending', 'processing', 'sent', 'failed', 'cancelled', 'expired') DEFAULT 'pending',
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    last_attempt_at TIMESTAMP NULL,
    next_attempt_at TIMESTAMP NULL,
    error_message TEXT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_status_priority (status, priority),
    INDEX idx_scheduled_at (scheduled_at),
    INDEX idx_next_attempt (next_attempt_at),
    INDEX idx_expires_at (expires_at),
    INDEX idx_user_type (user_id, type),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 6. Table des événements système
CREATE TABLE IF NOT EXISTS notification_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INT NOT NULL,
    user_id INT NULL,
    
    -- Données de l'événement
    event_data JSON DEFAULT NULL,
    
    -- Notifications générées
    notifications_created INT DEFAULT 0,
    notifications_sent INT DEFAULT 0,
    notifications_failed INT DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_event_type (event_type),
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Index sur user_fcm_tokens pour optimiser les requêtes (ignorer erreurs si existe déjà)
CREATE INDEX idx_user_fcm_active ON user_fcm_tokens(user_id, is_active);
CREATE INDEX idx_platform_active ON user_fcm_tokens(platform, is_active);