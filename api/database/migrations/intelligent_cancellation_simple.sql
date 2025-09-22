-- Migration simplifiée pour le système de gestion intelligente des annulations

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

-- 2. Colonnes pour les restrictions utilisateur
ALTER TABLE users
ADD COLUMN publication_restricted_until DATETIME NULL,
ADD COLUMN reliability_score INT DEFAULT 100,
ADD COLUMN user_type ENUM('new', 'confirmed', 'expert') DEFAULT 'new';

-- 3. Extension user_ratings pour scoring
ALTER TABLE user_ratings
ADD COLUMN reliability_score INT DEFAULT 100,
ADD COLUMN last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- 4. Table alternatives de voyage
CREATE TABLE IF NOT EXISTS trip_alternatives (
    id INT PRIMARY KEY AUTO_INCREMENT,
    cancelled_trip_id INT NOT NULL,
    suggested_trip_id INT NOT NULL,
    affected_user_id INT NOT NULL,
    suggestion_type ENUM('automatic', 'manual', 'ai_recommended') DEFAULT 'automatic',
    relevance_score DECIMAL(3,2) DEFAULT 0.00,
    is_accepted BOOLEAN NULL,
    suggested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    responded_at DATETIME NULL,

    FOREIGN KEY (cancelled_trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (suggested_trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (affected_user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 5. Tickets support automatiques
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
    auto_generated BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 6. Notifications d'annulation
CREATE TABLE IF NOT EXISTS cancellation_notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    user_id INT NOT NULL,
    notification_type ENUM('trip_cancelled', 'alternative_suggested', 'refund_processed', 'penalty_applied') NOT NULL,
    channel ENUM('email', 'push', 'in_app', 'sms') NOT NULL,
    status ENUM('pending', 'sent', 'delivered', 'failed') DEFAULT 'pending',
    content JSON NULL,
    sent_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 7. Politiques d'annulation configurables
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
    restriction_type ENUM('none', 'warning', 'publication_restriction', 'account_suspension') DEFAULT 'none',
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 8. Favoris de voyage
CREATE TABLE IF NOT EXISTS trip_favorites (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    trip_id INT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    notified_on_cancellation BOOLEAN DEFAULT FALSE,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,

    UNIQUE KEY unique_favorite (user_id, trip_id)
);

-- 9. Extension transactions pour remboursements
ALTER TABLE transactions
ADD COLUMN refund_type ENUM('full_refund', 'partial_refund', 'standard_refund', 'no_refund') NULL,
ADD COLUMN compensation_amount DECIMAL(10,2) DEFAULT 0.00,
ADD COLUMN original_transaction_id INT NULL,
ADD COLUMN auto_processed BOOLEAN DEFAULT FALSE;

-- 10. Politiques par défaut
INSERT IGNORE INTO cancellation_policies
(policy_name, hours_before_departure_min, hours_before_departure_max, has_bookings, has_payments, penalty_duration_days, reliability_impact, refund_percentage, restriction_type)
VALUES
('Annulation libre (48h+, sans réservation)', 48, NULL, FALSE, FALSE, 0, 0, 100.00, 'none'),
('Annulation avec impact (24-48h)', 24, 48, TRUE, FALSE, 7, -2, 100.00, 'publication_restriction'),
('Annulation critique (<24h)', 0, 24, TRUE, TRUE, 30, -5, 100.00, 'account_suspension'),
('Annulation standard', 24, NULL, TRUE, FALSE, 7, -1, 100.00, 'warning');