-- Migration pour le système de gestion intelligente des annulations
-- KiloShare - Intelligent Cancellation System

-- 1. Table pour l'historique de fiabilité des utilisateurs
CREATE TABLE IF NOT EXISTS user_reliability_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    impact INT NOT NULL COMMENT 'Impact sur le score (-10 à +10)',
    previous_score INT NOT NULL,
    new_score INT NOT NULL,
    description TEXT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_reliability (user_id, created_at)
);

-- 2. Ajout de colonnes pour les restrictions utilisateur (vérification d'existence)
SET @exist_pub_restricted = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'publication_restricted_until'
);
SET @exist_reliability = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'reliability_score'
);
SET @exist_user_type = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'users' AND COLUMN_NAME = 'user_type'
);

SET @sql = CASE WHEN @exist_pub_restricted = 0 THEN 'ALTER TABLE users ADD COLUMN publication_restricted_until DATETIME NULL COMMENT \'Restriction de publication jusqu\\\'à\';' ELSE 'SELECT "Column publication_restricted_until already exists";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = CASE WHEN @exist_reliability = 0 THEN 'ALTER TABLE users ADD COLUMN reliability_score INT DEFAULT 100 COMMENT \'Score de fiabilité (0-100)\';' ELSE 'SELECT "Column reliability_score already exists";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = CASE WHEN @exist_user_type = 0 THEN 'ALTER TABLE users ADD COLUMN user_type ENUM(\'new\', \'confirmed\', \'expert\') DEFAULT \'new\' COMMENT \'Type d\\\'utilisateur basé sur l\\\'expérience\';' ELSE 'SELECT "Column user_type already exists";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 3. Extension de la table user_ratings pour le scoring
SET @exist_ur_reliability = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'user_ratings' AND COLUMN_NAME = 'reliability_score'
);
SET @exist_ur_updated = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'user_ratings' AND COLUMN_NAME = 'last_updated'
);

SET @sql = CASE WHEN @exist_ur_reliability = 0 THEN 'ALTER TABLE user_ratings ADD COLUMN reliability_score INT DEFAULT 100 COMMENT \'Score de fiabilité calculé\';' ELSE 'SELECT "Column reliability_score already exists in user_ratings";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = CASE WHEN @exist_ur_updated = 0 THEN 'ALTER TABLE user_ratings ADD COLUMN last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;' ELSE 'SELECT "Column last_updated already exists in user_ratings";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 4. Table pour les alternatives suggérées lors d'annulations
CREATE TABLE IF NOT EXISTS trip_alternatives (
    id INT PRIMARY KEY AUTO_INCREMENT,
    cancelled_trip_id INT NOT NULL,
    suggested_trip_id INT NOT NULL,
    affected_user_id INT NOT NULL,
    suggestion_type ENUM('automatic', 'manual', 'ai_recommended') DEFAULT 'automatic',
    relevance_score DECIMAL(3,2) DEFAULT 0.00 COMMENT 'Score de pertinence (0-1)',
    is_accepted BOOLEAN NULL COMMENT 'NULL = non répondu, TRUE = accepté, FALSE = refusé',
    suggested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    responded_at DATETIME NULL,

    FOREIGN KEY (cancelled_trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (suggested_trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (affected_user_id) REFERENCES users(id) ON DELETE CASCADE,

    INDEX idx_suggestions (cancelled_trip_id, affected_user_id),
    INDEX idx_responses (is_accepted, responded_at)
);

-- 5. Table pour les tickets de support automatiques
CREATE TABLE IF NOT EXISTS auto_support_tickets (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NULL,
    booking_id INT NULL,
    user_id INT NOT NULL,
    category ENUM('critical_cancellation', 'refund_issue', 'user_dispute', 'technical_issue') NOT NULL,
    priority ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status ENUM('open', 'in_progress', 'resolved', 'closed') DEFAULT 'open',
    assigned_to INT NULL COMMENT 'Admin user ID',
    auto_generated BOOLEAN DEFAULT TRUE,
    resolution_notes TEXT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,

    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

    INDEX idx_status_priority (status, priority),
    INDEX idx_auto_generated (auto_generated, created_at)
);

-- 6. Table pour le tracking des notifications d'annulation
CREATE TABLE IF NOT EXISTS cancellation_notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    user_id INT NOT NULL,
    notification_type ENUM('trip_cancelled', 'alternative_suggested', 'refund_processed', 'penalty_applied') NOT NULL,
    channel ENUM('email', 'push', 'in_app', 'sms') NOT NULL,
    status ENUM('pending', 'sent', 'delivered', 'failed') DEFAULT 'pending',
    content JSON NULL COMMENT 'Contenu personnalisé de la notification',
    sent_at DATETIME NULL,
    delivered_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

    INDEX idx_status_type (status, notification_type),
    INDEX idx_user_notifications (user_id, sent_at)
);

-- 7. Table pour les politiques d'annulation configurables
CREATE TABLE IF NOT EXISTS cancellation_policies (
    id INT PRIMARY KEY AUTO_INCREMENT,
    policy_name VARCHAR(100) NOT NULL,
    hours_before_departure_min INT NOT NULL,
    hours_before_departure_max INT NULL,
    has_bookings BOOLEAN NOT NULL DEFAULT FALSE,
    has_payments BOOLEAN NOT NULL DEFAULT FALSE,
    penalty_duration_days INT DEFAULT 0,
    reliability_impact INT DEFAULT 0,
    refund_percentage DECIMAL(5,2) DEFAULT 100.00,
    compensation_percentage DECIMAL(5,2) DEFAULT 0.00,
    restriction_type ENUM('none', 'warning', 'publication_restriction', 'account_suspension') DEFAULT 'none',
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY unique_policy (hours_before_departure_min, hours_before_departure_max, has_bookings, has_payments),
    INDEX idx_active_policies (is_active, hours_before_departure_min)
);

-- 8. Table pour les favoris impactés par les annulations
CREATE TABLE IF NOT EXISTS trip_favorites (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    trip_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    notified_on_cancellation BOOLEAN DEFAULT FALSE,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,

    UNIQUE KEY unique_favorite (user_id, trip_id),
    INDEX idx_trip_favorites (trip_id, notified_on_cancellation)
);

-- 9. Extension de la table transactions pour le tracking des remboursements
SET @exist_trans_refund_type = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'transactions' AND COLUMN_NAME = 'refund_type'
);
SET @exist_trans_compensation = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'transactions' AND COLUMN_NAME = 'compensation_amount'
);
SET @exist_trans_original = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'transactions' AND COLUMN_NAME = 'original_transaction_id'
);
SET @exist_trans_auto = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare' AND TABLE_NAME = 'transactions' AND COLUMN_NAME = 'auto_processed'
);

SET @sql = CASE WHEN @exist_trans_refund_type = 0 THEN 'ALTER TABLE transactions ADD COLUMN refund_type ENUM(\'full_refund\', \'partial_refund\', \'standard_refund\', \'no_refund\') NULL;' ELSE 'SELECT "Column refund_type already exists in transactions";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = CASE WHEN @exist_trans_compensation = 0 THEN 'ALTER TABLE transactions ADD COLUMN compensation_amount DECIMAL(10,2) DEFAULT 0.00;' ELSE 'SELECT "Column compensation_amount already exists in transactions";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = CASE WHEN @exist_trans_original = 0 THEN 'ALTER TABLE transactions ADD COLUMN original_transaction_id INT NULL COMMENT \'Référence à la transaction originale\';' ELSE 'SELECT "Column original_transaction_id already exists in transactions";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = CASE WHEN @exist_trans_auto = 0 THEN 'ALTER TABLE transactions ADD COLUMN auto_processed BOOLEAN DEFAULT FALSE COMMENT \'Traité automatiquement\';' ELSE 'SELECT "Column auto_processed already exists in transactions";' END;
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 10. Insertion des politiques d'annulation par défaut
INSERT INTO cancellation_policies
(policy_name, hours_before_departure_min, hours_before_departure_max, has_bookings, has_payments, penalty_duration_days, reliability_impact, refund_percentage, restriction_type)
VALUES
('Annulation libre (48h+, sans réservation)', 48, NULL, FALSE, FALSE, 0, 0, 100.00, 'none'),
('Annulation avec impact (24-48h, réservations non payées)', 24, 48, TRUE, FALSE, 7, -2, 100.00, 'publication_restriction'),
('Annulation critique (<24h, avec paiements)', 0, 24, TRUE, TRUE, 30, -5, 100.00, 'account_suspension'),
('Annulation standard (avec réservations)', 24, NULL, TRUE, FALSE, 7, -1, 100.00, 'warning');

-- 11. Trigger pour mettre à jour automatiquement le type d'utilisateur
DELIMITER //
CREATE TRIGGER IF NOT EXISTS update_user_type_on_trip_completion
AFTER UPDATE ON trips
FOR EACH ROW
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Compter les voyages complétés
        SET @completed_trips = (
            SELECT COUNT(*)
            FROM trips
            WHERE user_id = NEW.user_id AND status = 'completed'
        );

        -- Calculer l'ancienneté du compte en mois
        SET @account_age_months = (
            SELECT TIMESTAMPDIFF(MONTH, created_at, NOW())
            FROM users
            WHERE id = NEW.user_id
        );

        -- Mettre à jour le type d'utilisateur
        UPDATE users
        SET user_type = CASE
            WHEN @completed_trips >= 10 AND @account_age_months >= 6 THEN 'expert'
            WHEN @completed_trips >= 3 AND @account_age_months >= 2 THEN 'confirmed'
            ELSE 'new'
        END
        WHERE id = NEW.user_id;
    END IF;
END//
DELIMITER ;

-- 12. Trigger pour notifier les utilisateurs ayant mis en favoris lors d'annulation
DELIMITER //
CREATE TRIGGER IF NOT EXISTS notify_favorites_on_trip_cancellation
AFTER UPDATE ON trips
FOR EACH ROW
BEGIN
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        -- Marquer les favoris comme devant être notifiés
        UPDATE trip_favorites
        SET notified_on_cancellation = TRUE
        WHERE trip_id = NEW.id AND notified_on_cancellation = FALSE;

        -- Insérer les notifications pour les utilisateurs ayant mis en favoris
        INSERT INTO cancellation_notifications (trip_id, user_id, notification_type, channel, content)
        SELECT NEW.id, user_id, 'trip_cancelled', 'push',
               JSON_OBJECT('message', 'Un voyage que vous avez mis en favoris a été annulé')
        FROM trip_favorites
        WHERE trip_id = NEW.id;
    END IF;
END//
DELIMITER ;

-- 13. Vue pour les statistiques de fiabilité par utilisateur
CREATE OR REPLACE VIEW user_reliability_stats AS
SELECT
    u.id as user_id,
    u.first_name,
    u.last_name,
    u.email,
    u.user_type,
    COALESCE(ur.reliability_score, 100) as reliability_score,
    COUNT(t.id) as total_trips,
    COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed_trips,
    COUNT(CASE WHEN t.status = 'cancelled' THEN 1 END) as cancelled_trips,
    ROUND(
        CASE WHEN COUNT(t.id) > 0
        THEN (COUNT(CASE WHEN t.status = 'completed' THEN 1 END) / COUNT(t.id)) * 100
        ELSE 100 END, 2
    ) as completion_rate,
    (
        SELECT COUNT(*)
        FROM cancellation_attempts ca
        WHERE ca.user_id = u.id
        AND ca.is_allowed = TRUE
        AND ca.created_at >= DATE_SUB(NOW(), INTERVAL 3 MONTH)
    ) as recent_cancellations,
    u.created_at as member_since
FROM users u
LEFT JOIN user_ratings ur ON u.id = ur.user_id
LEFT JOIN trips t ON u.id = t.user_id
GROUP BY u.id, u.first_name, u.last_name, u.email, u.user_type, ur.reliability_score, u.created_at;

-- 14. Index pour optimiser les performances
CREATE INDEX IF NOT EXISTS idx_trips_departure_status ON trips(departure_date, status);
CREATE INDEX IF NOT EXISTS idx_bookings_trip_status ON bookings(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_users_reliability ON users(reliability_score, user_type);
CREATE INDEX IF NOT EXISTS idx_transactions_type_status ON transactions(type, status);

-- Fin de la migration