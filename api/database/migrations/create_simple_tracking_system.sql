-- Migration: Système de suivi simple pour KiloShare
-- Philosophy: Trust-based, minimal complexity, "comme BlaBlaCar pas comme DHL"

-- Table des réservations avec statuts simples
CREATE TABLE IF NOT EXISTS bookings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    sender_id INT NOT NULL,
    carrier_id INT NOT NULL,
    pickup_address TEXT NOT NULL,
    delivery_address TEXT NOT NULL,
    package_description TEXT,
    pickup_date DATE,
    pickup_time TIME,
    price DECIMAL(10,2),
    status ENUM('pending', 'confirmed', 'picked_up', 'en_route', 'delivered', 'cancelled') DEFAULT 'pending',
    
    -- Photos de protection minimale
    pickup_photo_url VARCHAR(500),
    delivery_photo_url VARCHAR(500),
    
    -- Codes optionnels (non obligatoires)
    pickup_code VARCHAR(10),
    delivery_code VARCHAR(10),
    
    -- Métadonnées
    payment_status ENUM('pending', 'paid', 'refunded') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (sender_id) REFERENCES users(id),
    FOREIGN KEY (carrier_id) REFERENCES users(id),
    INDEX idx_status (status),
    INDEX idx_sender (sender_id),
    INDEX idx_carrier (carrier_id)
);

-- Messages pour communication directe (déjà existe mais on ajoute booking_id)
ALTER TABLE messages ADD COLUMN IF NOT EXISTS booking_id INT;
ALTER TABLE messages ADD CONSTRAINT IF NOT EXISTS fk_messages_booking 
    FOREIGN KEY (booking_id) REFERENCES bookings(id);

-- Log simple des étapes importantes
CREATE TABLE IF NOT EXISTS trip_events (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    event_type ENUM('pickup_confirmed', 'en_route_started', 'delivery_confirmed', 'issue_reported') NOT NULL,
    user_id INT NOT NULL, -- Qui a déclenché l'événement
    message TEXT, -- Description optionnelle
    photo_url VARCHAR(500), -- Photo associée si applicable
    location_lat DECIMAL(10, 8), -- Position GPS optionnelle
    location_lng DECIMAL(11, 8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_booking_events (booking_id),
    INDEX idx_event_type (event_type)
);

-- Table pour les évaluations post-livraison (simple)
CREATE TABLE IF NOT EXISTS booking_reviews (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    reviewer_id INT NOT NULL, -- sender ou carrier
    reviewed_id INT NOT NULL, -- l'autre partie
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id),
    FOREIGN KEY (reviewer_id) REFERENCES users(id),
    FOREIGN KEY (reviewed_id) REFERENCES users(id),
    UNIQUE KEY unique_review (booking_id, reviewer_id)
);

-- Table pour les signalements (cas problématiques)
CREATE TABLE IF NOT EXISTS booking_reports (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    reporter_id INT NOT NULL,
    report_type ENUM('late_pickup', 'late_delivery', 'damaged_package', 'communication_issue', 'payment_issue', 'other') NOT NULL,
    description TEXT NOT NULL,
    status ENUM('open', 'investigating', 'resolved', 'closed') DEFAULT 'open',
    admin_response TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id),
    FOREIGN KEY (reporter_id) REFERENCES users(id),
    INDEX idx_report_status (status),
    INDEX idx_booking_reports (booking_id)
);

-- Trigger pour mettre à jour automatiquement le statut booking
DELIMITER //
CREATE TRIGGER IF NOT EXISTS update_booking_status_on_event
AFTER INSERT ON trip_events
FOR EACH ROW
BEGIN
    CASE NEW.event_type
        WHEN 'pickup_confirmed' THEN
            UPDATE bookings SET status = 'picked_up' WHERE id = NEW.booking_id;
        WHEN 'en_route_started' THEN
            UPDATE bookings SET status = 'en_route' WHERE id = NEW.booking_id;
        WHEN 'delivery_confirmed' THEN
            UPDATE bookings SET status = 'delivered' WHERE id = NEW.booking_id;
    END CASE;
END//
DELIMITER ;