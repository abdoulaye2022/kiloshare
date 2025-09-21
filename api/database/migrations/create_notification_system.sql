-- =====================================================
-- SYSTÈME COMPLET DE NOTIFICATIONS KILOSHARE
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
    recipient VARCHAR(255) NOT NULL, -- email, phone, ou FCM token
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
    provider VARCHAR(50) NULL, -- firebase, sendgrid, twilio, etc.
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
    subject VARCHAR(255) NULL, -- pour email
    title VARCHAR(255) NULL, -- pour push/in-app
    message TEXT NOT NULL,
    html_content TEXT NULL, -- pour email HTML
    
    -- Variables supportées (JSON array)
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

-- 6. Table des événements système pour debug
CREATE TABLE IF NOT EXISTS notification_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL, -- trip, booking, user, payment
    entity_id INT NOT NULL,
    user_id INT NULL, -- utilisateur concerné
    
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

-- 7. Extension de la table user_fcm_tokens (déjà existante, ajout d'index si nécessaire)
-- Vérifier si les index existent et les créer si nécessaire

-- =====================================================
-- INSERTION DES TEMPLATES PAR DÉFAUT
-- =====================================================

-- Templates pour les annonces
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('trip_submitted', 'push', 'fr', 'Annonce soumise', 'Votre annonce est en cours de validation', '["trip_title", "departure_city", "arrival_city"]'),
('trip_approved', 'push', 'fr', 'Annonce approuvée', 'Votre annonce {{trip_title}} est maintenant visible', '["trip_title", "trip_url"]'),
('trip_rejected', 'push', 'fr', 'Annonce rejetée', 'Votre annonce a été rejetée : {{reason}}', '["trip_title", "reason"]'),
('trip_expires_soon', 'push', 'fr', 'Voyage expire demain', 'Votre voyage du {{departure_date}} expire demain', '["trip_title", "departure_date"]');

-- Templates pour les négociations
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('new_booking_request', 'push', 'fr', 'Nouvelle demande', '{{sender_name}} veut envoyer {{weight}}kg pour {{price}}€', '["sender_name", "weight", "price", "package_description"]'),
('booking_accepted', 'push', 'fr', 'Demande acceptée', 'Votre demande a été acceptée - Procédez au paiement', '["trip_title", "total_amount"]'),
('booking_rejected', 'push', 'fr', 'Demande refusée', '{{traveler_name}} a décliné votre demande', '["traveler_name", "trip_title"]'),
('negotiation_message', 'push', 'fr', 'Nouveau message', 'Nouveau message de {{sender_name}}', '["sender_name", "message_preview"]');

-- Templates pour les paiements
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('payment_received', 'push', 'fr', 'Paiement reçu', 'Paiement de {{amount}}€ reçu - En attente de confirmation', '["amount", "sender_name"]'),
('payment_confirmed', 'push', 'fr', 'Paiement confirmé', 'Paiement confirmé - Code pickup: {{pickup_code}}', '["amount", "pickup_code"]'),
('payment_released', 'push', 'fr', 'Paiement versé', '{{amount}}€ versé sur votre compte', '["amount", "commission_amount"]');

-- Templates pour le jour J
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('departure_reminder', 'push', 'fr', 'C\'est aujourd\'hui !', 'Départ à {{departure_time}} - {{departure_address}}', '["departure_time", "departure_address", "contact_info"]'),
('pickup_reminder', 'push', 'fr', 'RDV dans 2h', 'RDV avec {{contact_name}} à {{pickup_address}}', '["contact_name", "pickup_address", "contact_phone"]'),
('package_picked_up', 'push', 'fr', 'Colis récupéré', '{{traveler_name}} a récupéré votre colis', '["traveler_name", "pickup_time"]');

-- Templates pour le voyage
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('trip_started', 'push', 'fr', 'Voyage démarré', 'Votre colis est en route vers {{destination}}', '["destination", "estimated_arrival"]'),
('trip_location_update', 'push', 'fr', 'Mise à jour position', 'Votre colis est à {{current_location}}', '["current_location", "estimated_arrival"]'),
('delivery_imminent', 'push', 'fr', 'Livraison imminente', 'Livraison prévue dans ~2h', '["estimated_delivery_time", "delivery_address"]');

-- Templates pour la livraison
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('package_delivered', 'push', 'fr', 'Colis livré', 'Colis livré avec succès !', '["delivery_time", "recipient_name"]'),
('review_request', 'push', 'fr', 'Évaluation', 'Comment s\'est passée la livraison ?', '["partner_name", "trip_title"]');

-- Templates pour les annulations
INSERT IGNORE INTO notification_templates (type, channel, language, title, message, variables) VALUES
('trip_cancelled', 'push', 'fr', 'Voyage annulé', 'Voyage annulé - Remboursement en cours', '["trip_title", "refund_amount"]'),
('booking_cancelled_early', 'push', 'fr', 'Réservation annulée', '{{sender_name}} a annulé sa réservation', '["sender_name", "trip_title"]'),
('booking_cancelled_late', 'push', 'fr', 'Annulation tardive', '{{sender_name}} annule - Compensation: {{amount}}€', '["sender_name", "amount"]');

-- Templates email (quelques exemples)
INSERT IGNORE INTO notification_templates (type, channel, language, subject, message, html_content, variables) VALUES
('booking_accepted', 'email', 'fr', 'Demande acceptée - KiloShare', 
'Bonjour {{sender_name}},

Excellente nouvelle ! {{traveler_name}} a accepté votre demande pour le voyage {{trip_title}}.

Détails de la réservation :
- Poids : {{weight}}kg
- Prix : {{price}}€
- Date de départ : {{departure_date}}

Procédez maintenant au paiement pour confirmer votre réservation.

Cordialement,
L\'équipe KiloShare',
'<h2>Demande acceptée</h2><p>Bonjour {{sender_name}},</p><p>Excellente nouvelle ! <strong>{{traveler_name}}</strong> a accepté votre demande.</p><a href="{{payment_url}}" class="btn">Procéder au paiement</a>',
'["sender_name", "traveler_name", "trip_title", "weight", "price", "departure_date", "payment_url"]');

-- =====================================================
-- CRÉATION DES INDEX MANQUANTS SUR TABLES EXISTANTES
-- =====================================================

-- Index sur user_fcm_tokens pour optimiser les requêtes
CREATE INDEX idx_user_fcm_tokens_active ON user_fcm_tokens(user_id, is_active);
CREATE INDEX idx_user_fcm_tokens_platform ON user_fcm_tokens(platform, is_active);

-- =====================================================
-- VUES UTILES POUR LES STATISTIQUES
-- =====================================================

-- Vue des notifications non lues par utilisateur
CREATE OR REPLACE VIEW user_unread_notifications AS
SELECT 
    user_id,
    COUNT(*) as unread_count,
    COUNT(CASE WHEN priority = 'critical' THEN 1 END) as critical_count,
    COUNT(CASE WHEN priority = 'high' THEN 1 END) as high_count,
    MAX(created_at) as latest_notification
FROM notifications 
WHERE is_read = FALSE 
  AND deleted_at IS NULL 
  AND (expires_at IS NULL OR expires_at > NOW())
GROUP BY user_id;

-- Vue des statistiques d'envoi par canal
CREATE OR REPLACE VIEW notification_stats_by_channel AS
SELECT 
    channel,
    DATE(sent_at) as date,
    COUNT(*) as total_sent,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as delivered,
    COUNT(CASE WHEN status = 'opened' THEN 1 END) as opened,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
    ROUND(COUNT(CASE WHEN status = 'delivered' THEN 1 END) * 100.0 / COUNT(*), 2) as delivery_rate,
    ROUND(COUNT(CASE WHEN status = 'opened' THEN 1 END) * 100.0 / COUNT(CASE WHEN status = 'delivered' THEN 1 END), 2) as open_rate
FROM notification_logs 
WHERE sent_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY channel, DATE(sent_at)
ORDER BY date DESC, channel;

-- =====================================================
-- PROCÉDURES STOCKÉES UTILES
-- =====================================================

DELIMITER //

-- Procédure pour nettoyer les anciennes notifications
CREATE PROCEDURE IF NOT EXISTS CleanupOldNotifications()
BEGIN
    DECLARE rows_affected INT DEFAULT 0;
    
    -- Supprimer les notifications expirées
    DELETE FROM notifications 
    WHERE expires_at IS NOT NULL 
      AND expires_at < NOW() 
      AND deleted_at IS NULL;
    
    SET rows_affected = ROW_COUNT();
    
    -- Marquer comme supprimées les notifications lues de plus de 30 jours
    UPDATE notifications 
    SET deleted_at = NOW() 
    WHERE is_read = TRUE 
      AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
      AND deleted_at IS NULL;
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- Supprimer les logs de plus de 90 jours (sauf les erreurs)
    DELETE FROM notification_logs 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY)
      AND status != 'failed';
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    SELECT CONCAT('Cleaned up ', rows_affected, ' records') as result;
END //

-- Fonction pour vérifier si un utilisateur peut recevoir une notification
CREATE FUNCTION IF NOT EXISTS CanReceiveNotification(
    p_user_id INT, 
    p_type VARCHAR(50), 
    p_channel VARCHAR(20)
) RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE can_receive BOOLEAN DEFAULT TRUE;
    DECLARE quiet_hours_enabled BOOLEAN DEFAULT FALSE;
    DECLARE quiet_start TIME;
    DECLARE quiet_end TIME;
    DECLARE current_time TIME;
    
    -- Vérifier les préférences globales
    SELECT 
        CASE 
            WHEN p_channel = 'push' THEN push_enabled
            WHEN p_channel = 'email' THEN email_enabled
            WHEN p_channel = 'sms' THEN sms_enabled
            ELSE in_app_enabled
        END,
        quiet_hours_enabled,
        quiet_hours_start,
        quiet_hours_end
    INTO can_receive, quiet_hours_enabled, quiet_start, quiet_end
    FROM user_notification_preferences 
    WHERE user_id = p_user_id;
    
    -- Si pas de préférences, utiliser les défauts
    IF can_receive IS NULL THEN
        SET can_receive = TRUE;
    END IF;
    
    -- Vérifier les heures silencieuses (sauf pour les critiques)
    IF can_receive = TRUE AND quiet_hours_enabled = TRUE AND p_type NOT LIKE '%critical%' THEN
        SET current_time = TIME(NOW());
        
        IF quiet_start <= quiet_end THEN
            -- Heures normales (ex: 22:00 - 08:00 le lendemain)
            SET can_receive = NOT (current_time >= quiet_start AND current_time <= quiet_end);
        ELSE
            -- Heures qui chevauchent minuit (ex: 22:00 - 08:00)
            SET can_receive = NOT (current_time >= quiet_start OR current_time <= quiet_end);
        END IF;
    END IF;
    
    RETURN can_receive;
END //

DELIMITER ;