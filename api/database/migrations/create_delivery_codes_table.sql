-- Migration pour créer la table delivery_codes
-- Système de codes de livraison sécurisé
-- Date: 2025-01-XX

CREATE TABLE delivery_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    code VARCHAR(6) NOT NULL,
    status ENUM('active', 'used', 'expired', 'regenerated') DEFAULT 'active',
    attempts_count INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    used_at TIMESTAMP NULL,
    delivery_latitude DECIMAL(10, 8) NULL,
    delivery_longitude DECIMAL(11, 8) NULL,
    delivery_photos JSON NULL,
    verification_photos JSON NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Contraintes
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    UNIQUE KEY unique_active_code_per_booking (booking_id, status),
    INDEX idx_booking_id (booking_id),
    INDEX idx_code (code),
    INDEX idx_status (status),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour les tentatives de validation
CREATE TABLE delivery_code_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_code_id INT NOT NULL,
    attempted_code VARCHAR(6) NOT NULL,
    user_id INT NOT NULL,
    attempt_latitude DECIMAL(10, 8) NULL,
    attempt_longitude DECIMAL(11, 8) NULL,
    success BOOLEAN DEFAULT FALSE,
    error_message VARCHAR(255) NULL,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (delivery_code_id) REFERENCES delivery_codes(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_delivery_code_id (delivery_code_id),
    INDEX idx_user_id (user_id),
    INDEX idx_attempted_at (attempted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour l'historique des codes (pour audit)
CREATE TABLE delivery_code_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    old_code VARCHAR(6) NULL,
    new_code VARCHAR(6) NOT NULL,
    action ENUM('generated', 'regenerated', 'expired', 'used') NOT NULL,
    triggered_by_user_id INT NULL,
    reason VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (triggered_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_booking_id (booking_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ajout de colonnes aux bookings pour le suivi
ALTER TABLE bookings
ADD COLUMN delivery_code_required BOOLEAN DEFAULT FALSE COMMENT 'Indique si cette réservation nécessite un code de livraison',
ADD COLUMN delivery_confirmed_at TIMESTAMP NULL COMMENT 'Date de confirmation de livraison avec code',
ADD COLUMN delivery_confirmed_by INT NULL COMMENT 'ID de l\'utilisateur qui a confirmé la livraison',
ADD FOREIGN KEY fk_delivery_confirmed_by (delivery_confirmed_by) REFERENCES users(id) ON DELETE SET NULL;

-- Index pour optimiser les requêtes
CREATE INDEX idx_bookings_delivery_code_required ON bookings(delivery_code_required);
CREATE INDEX idx_bookings_delivery_confirmed_at ON bookings(delivery_confirmed_at);

-- Vue pour les codes actifs avec informations de réservation
CREATE VIEW active_delivery_codes AS
SELECT
    dc.id,
    dc.booking_id,
    dc.code,
    dc.status,
    dc.attempts_count,
    dc.max_attempts,
    dc.generated_at,
    dc.expires_at,
    b.sender_id,
    b.receiver_id,
    b.status as booking_status,
    u_sender.first_name as sender_name,
    u_sender.email as sender_email,
    u_receiver.first_name as receiver_name,
    u_receiver.email as receiver_email,
    t.departure_city,
    t.arrival_city,
    t.arrival_date
FROM delivery_codes dc
JOIN bookings b ON dc.booking_id = b.id
JOIN users u_sender ON b.sender_id = u_sender.id
JOIN users u_receiver ON b.receiver_id = u_receiver.id
JOIN trips t ON b.trip_id = t.id
WHERE dc.status = 'active' AND dc.expires_at > NOW();

-- Procédure stockée pour nettoyer les codes expirés
DELIMITER $$
CREATE PROCEDURE CleanExpiredDeliveryCodes()
BEGIN
    UPDATE delivery_codes
    SET status = 'expired'
    WHERE status = 'active'
    AND expires_at <= NOW();

    SELECT ROW_COUNT() as expired_codes_count;
END$$
DELIMITER ;

-- Event pour nettoyer automatiquement les codes expirés (toutes les heures)
CREATE EVENT IF NOT EXISTS cleanup_expired_delivery_codes
ON SCHEDULE EVERY 1 HOUR
DO
    CALL CleanExpiredDeliveryCodes();

-- Verification de la création des tables
SELECT
    table_name,
    table_rows,
    table_comment
FROM information_schema.tables
WHERE table_schema = DATABASE()
AND table_name IN ('delivery_codes', 'delivery_code_attempts', 'delivery_code_history');