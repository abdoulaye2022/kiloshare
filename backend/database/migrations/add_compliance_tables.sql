-- =====================================================
-- TABLES POUR CONFORMITÉ COMPLÈTE KILOSHARE
-- =====================================================

-- 1. COMPTES SÉQUESTRES (Escrow Accounts)
CREATE TABLE escrow_accounts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    booking_id INT,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'CAD',
    status ENUM('pending', 'held', 'released', 'refunded', 'disputed') DEFAULT 'pending',
    stripe_payment_intent_id VARCHAR(255),
    held_at TIMESTAMP NULL,
    released_at TIMESTAMP NULL,
    release_reason ENUM('delivery_completed', 'admin_action', 'dispute_resolved') NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL,
    INDEX idx_trip_escrow (trip_id),
    INDEX idx_status_escrow (status)
);

-- 2. TRANSACTIONS FINANCIÈRES
CREATE TABLE transactions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    escrow_account_id INT NOT NULL,
    type ENUM('hold', 'release', 'refund', 'fee_deduction') NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'CAD',
    stripe_transaction_id VARCHAR(255),
    description TEXT,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (escrow_account_id) REFERENCES escrow_accounts(id) ON DELETE CASCADE,
    INDEX idx_escrow_transactions (escrow_account_id),
    INDEX idx_transaction_type (type)
);

-- 3. ACTIONS ADMINISTRATEUR (Audit Trail)
CREATE TABLE admin_actions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    admin_id INT NOT NULL,
    target_type ENUM('trip', 'user', 'booking', 'payment') NOT NULL,
    target_id INT NOT NULL,
    action ENUM('approve', 'reject', 'suspend', 'activate', 'manual_release', 'flag_suspicious') NOT NULL,
    reason TEXT,
    metadata JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_admin_actions (admin_id),
    INDEX idx_target_actions (target_type, target_id),
    INDEX idx_action_date (created_at)
);

-- 4. HISTORIQUE DES CHANGEMENTS D'ÉTAT
CREATE TABLE trip_action_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    user_id INT,
    admin_id INT,
    previous_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    action ENUM('submit', 'approve', 'reject', 'activate', 'pause', 'book', 'start', 'complete', 'cancel') NOT NULL,
    reason TEXT,
    automatic BOOLEAN DEFAULT FALSE,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (admin_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_trip_logs (trip_id),
    INDEX idx_status_changes (previous_status, new_status),
    INDEX idx_action_date (created_at)
);

-- 5. NÉGOCIATIONS DE RÉSERVATION
CREATE TABLE booking_negotiations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    message TEXT NOT NULL,
    proposed_price DECIMAL(10,2),
    proposed_weight DECIMAL(5,2),
    status ENUM('pending', 'accepted', 'rejected', 'countered') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_booking_negotiations (booking_id),
    INDEX idx_negotiation_status (status)
);

-- 6. SUIVI GPS
CREATE TABLE gps_tracking (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    user_id INT NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    altitude DECIMAL(8, 2),
    accuracy DECIMAL(6, 2),
    speed DECIMAL(6, 2),
    heading DECIMAL(6, 2),
    checkpoint_type ENUM('departure', 'transit', 'arrival', 'manual') DEFAULT 'manual',
    notes TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_trip_gps (trip_id, timestamp),
    INDEX idx_user_tracking (user_id, timestamp)
);

-- 7. PHOTOS DES COLIS (Preuve de réception/livraison)
CREATE TABLE booking_package_photos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    uploader_id INT NOT NULL,
    photo_url VARCHAR(500) NOT NULL,
    photo_type ENUM('pickup_proof', 'transit_update', 'delivery_proof', 'damage_report') NOT NULL,
    description TEXT,
    cloudinary_public_id VARCHAR(255),
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (uploader_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_booking_photos (booking_id, photo_type)
);

-- 8. RÈGLES DE VALIDATION AUTOMATIQUE
CREATE TABLE validation_rules (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    type ENUM('price_limit', 'route_validation', 'user_limit', 'spam_detection') NOT NULL,
    criteria JSON NOT NULL,
    action ENUM('auto_approve', 'auto_reject', 'flag_for_review') NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    priority INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_rule_type (type, is_active)
);

-- 9. RÉSULTATS DE VALIDATION
CREATE TABLE validation_results (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    rule_id INT NOT NULL,
    passed BOOLEAN NOT NULL,
    details JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (rule_id) REFERENCES validation_rules(id) ON DELETE CASCADE,
    INDEX idx_trip_validation (trip_id),
    INDEX idx_validation_results (passed, created_at)
);

-- 10. DISPUTES ET RÉSOLUTIONS
CREATE TABLE disputes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    complainant_id INT NOT NULL,
    respondent_id INT NOT NULL,
    type ENUM('delivery_issue', 'payment_issue', 'damaged_package', 'other') NOT NULL,
    description TEXT NOT NULL,
    status ENUM('open', 'investigating', 'resolved', 'closed') DEFAULT 'open',
    resolution TEXT,
    resolved_by INT,
    escrow_action ENUM('release_to_traveler', 'refund_to_sender', 'partial_refund', 'hold_pending') NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (complainant_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (respondent_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_booking_disputes (booking_id),
    INDEX idx_dispute_status (status)
);

-- =====================================================
-- INSERTION DES RÈGLES DE VALIDATION PAR DÉFAUT
-- =====================================================

INSERT INTO validation_rules (name, type, criteria, action, priority) VALUES
('Prix minimum', 'price_limit', '{"min_price": 2.0, "currency": "CAD"}', 'auto_reject', 1),
('Prix maximum', 'price_limit', '{"max_price": 50.0, "currency": "CAD"}', 'flag_for_review', 2),
('Route impossible voiture', 'route_validation', '{"transport": "car", "international": false}', 'auto_reject', 3),
('Limite voyages actifs', 'user_limit', '{"max_active_trips": 5}', 'auto_reject', 4),
('Utilisateur vérifié auto-approve', 'user_limit', '{"min_completed_trips": 10, "min_rating": 4.5}', 'auto_approve', 5);

-- =====================================================
-- AJOUT DE COLONNES MANQUANTES À LA TABLE TRIPS
-- =====================================================

ALTER TABLE trips 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS paused_at TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS validation_score INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS auto_validated BOOLEAN DEFAULT FALSE;

-- =====================================================
-- AJOUT DE COLONNES POUR SUIVI UTILISATEUR
-- =====================================================

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS completed_trips_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS average_rating DECIMAL(3,2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS trust_score INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP NULL;