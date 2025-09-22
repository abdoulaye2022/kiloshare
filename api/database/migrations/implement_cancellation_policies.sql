-- Migration pour implémenter les politiques d'annulation strictes de KiloShare
-- Date: 2025-09-05

USE kiloshare;

-- 1. Ajout des colonnes de tracking d'annulation dans la table users
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS cancellation_count INT DEFAULT 0 COMMENT 'Nombre total d\'annulations par le voyageur',
ADD COLUMN IF NOT EXISTS last_cancellation_date DATETIME NULL COMMENT 'Date de la dernière annulation',
ADD COLUMN IF NOT EXISTS suspension_reason VARCHAR(500) NULL COMMENT 'Raison de suspension du compte',
ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE COMMENT 'Compte suspendu pour annulations répétées';

-- 2. Amélioration de la table trips pour le tracking des annulations
ALTER TABLE trips
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT NULL COMMENT 'Raison fournie pour l\'annulation',
ADD COLUMN IF NOT EXISTS cancelled_at DATETIME NULL COMMENT 'Date et heure d\'annulation',
ADD COLUMN IF NOT EXISTS cancelled_by ENUM('traveler', 'sender') NULL COMMENT 'Qui a annulé le voyage';

-- 3. Amélioration de la table bookings pour les différents types d'annulation
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS cancelled_at DATETIME NULL COMMENT 'Date et heure d\'annulation',
ADD COLUMN IF NOT EXISTS cancellation_type ENUM('early', 'late', 'no_show', 'by_traveler', 'by_sender') NULL COMMENT 'Type d\'annulation',
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT NULL COMMENT 'Raison de l\'annulation';

-- 4. Amélioration de la table transactions pour les frais et montants nets
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS fee_amount DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Montant des frais (Stripe + KiloShare)',
ADD COLUMN IF NOT EXISTS net_amount DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Montant net après déduction des frais',
ADD COLUMN IF NOT EXISTS stripe_fee DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Frais Stripe spécifiques',
ADD COLUMN IF NOT EXISTS kiloshare_fee DECIMAL(10,2) DEFAULT 0.00 COMMENT 'Commission KiloShare';

-- 5. Table pour tracker les avis d'annulation publics
CREATE TABLE IF NOT EXISTS trip_cancellation_reports (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    user_id INT NOT NULL,
    booking_id INT NULL,
    cancellation_reason TEXT NOT NULL,
    cancellation_type ENUM('with_booking', 'without_booking') NOT NULL,
    is_public BOOLEAN DEFAULT TRUE COMMENT 'Visible sur le profil public',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL COMMENT 'Date d\'expiration de l\'affichage public (6 mois)',
    
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL,
    
    INDEX idx_user_public (user_id, is_public),
    INDEX idx_expiration (expires_at)
);

-- 6. Table pour les politiques de remboursement par type d'annulation
CREATE TABLE IF NOT EXISTS refund_policies (
    id INT PRIMARY KEY AUTO_INCREMENT,
    cancellation_type ENUM('traveler_no_booking', 'traveler_with_booking', 'sender_early', 'sender_late', 'no_show') NOT NULL,
    sender_refund_percentage DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Pourcentage de remboursement à l\'expéditeur',
    traveler_compensation_percentage DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Pourcentage de compensation au voyageur',
    deduct_stripe_fees BOOLEAN DEFAULT TRUE COMMENT 'Déduire les frais Stripe',
    deduct_kiloshare_fees BOOLEAN DEFAULT FALSE COMMENT 'Déduire les frais KiloShare',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 7. Insertion des politiques de remboursement par défaut
INSERT INTO refund_policies (cancellation_type, sender_refund_percentage, traveler_compensation_percentage, deduct_stripe_fees, deduct_kiloshare_fees) VALUES
('traveler_no_booking', 0.00, 0.00, FALSE, FALSE),
('traveler_with_booking', 100.00, 0.00, FALSE, FALSE),
('sender_early', 100.00, 0.00, TRUE, TRUE),
('sender_late', 50.00, 50.00, TRUE, FALSE),
('no_show', 0.00, 100.00, FALSE, FALSE);

-- 8. Table pour tracker les tentatives d'annulation et les vérifications
CREATE TABLE IF NOT EXISTS cancellation_attempts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    trip_id INT NULL,
    booking_id INT NULL,
    attempt_type ENUM('trip_cancel', 'booking_cancel') NOT NULL,
    is_allowed BOOLEAN NOT NULL,
    denial_reason VARCHAR(500) NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL,
    
    INDEX idx_user_attempts (user_id, created_at)
);

-- 9. Ajout de nouveaux statuts pour booking_negotiations
ALTER TABLE booking_negotiations
MODIFY COLUMN status ENUM('pending', 'accepted', 'rejected', 'cancelled_by_sender', 'expired') NOT NULL DEFAULT 'pending';

-- 10. Vues pour faciliter les requêtes de vérification d'annulation
CREATE OR REPLACE VIEW user_cancellation_summary AS
SELECT 
    u.id as user_id,
    u.cancellation_count,
    u.last_cancellation_date,
    u.is_suspended,
    CASE 
        WHEN u.last_cancellation_date IS NULL THEN TRUE
        WHEN DATEDIFF(NOW(), u.last_cancellation_date) > 90 THEN TRUE
        ELSE FALSE 
    END as can_cancel_with_booking,
    COUNT(tcr.id) as public_cancellation_reports
FROM users u
LEFT JOIN trip_cancellation_reports tcr ON u.id = tcr.user_id 
    AND tcr.is_public = TRUE 
    AND (tcr.expires_at IS NULL OR tcr.expires_at > NOW())
GROUP BY u.id;

-- 11. Index pour optimiser les requêtes de vérification
CREATE INDEX IF NOT EXISTS idx_trips_departure_status ON trips(departure_date, status);
CREATE INDEX IF NOT EXISTS idx_bookings_trip_status ON bookings(trip_id, status);
CREATE INDEX IF NOT EXISTS idx_users_cancellation_tracking ON users(last_cancellation_date, cancellation_count);

-- 12. Trigger pour mettre à jour automatiquement les compteurs d'annulation
DELIMITER //

CREATE TRIGGER IF NOT EXISTS update_user_cancellation_count
    AFTER UPDATE ON trips
    FOR EACH ROW
BEGIN
    -- Si un voyage est annulé par le voyageur avec des réservations
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' AND NEW.cancelled_by = 'traveler' THEN
        -- Vérifier s'il y avait des réservations confirmées
        IF (SELECT COUNT(*) FROM bookings WHERE trip_id = NEW.id AND status IN ('accepted', 'in_progress', 'paid')) > 0 THEN
            UPDATE users 
            SET 
                cancellation_count = cancellation_count + 1,
                last_cancellation_date = NOW()
            WHERE id = NEW.user_id;
            
            -- Créer un rapport d'annulation public
            INSERT INTO trip_cancellation_reports (trip_id, user_id, cancellation_reason, cancellation_type, expires_at)
            VALUES (NEW.id, NEW.user_id, NEW.cancellation_reason, 'with_booking', DATE_ADD(NOW(), INTERVAL 6 MONTH));
        END IF;
    END IF;
END//

DELIMITER ;

COMMIT;