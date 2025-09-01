-- Migration pour le système de réservation et transaction KiloShare
-- Date: 2025-09-01
-- Module: Booking & Transactions

-- Table des réservations principales
CREATE TABLE IF NOT EXISTS bookings (
    id INT PRIMARY KEY AUTO_INCREMENT,
    uuid VARCHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    trip_id INT NOT NULL,
    sender_id INT NOT NULL, -- Utilisateur qui envoie le colis
    receiver_id INT NOT NULL, -- Propriétaire du voyage
    package_description TEXT NOT NULL,
    weight_kg DECIMAL(5,2) NOT NULL,
    dimensions_cm VARCHAR(20) DEFAULT NULL, -- Format: "LxlxH"
    proposed_price DECIMAL(8,2) NOT NULL,
    final_price DECIMAL(8,2) DEFAULT NULL,
    commission_rate DECIMAL(4,2) DEFAULT 15.00, -- Pourcentage commission
    commission_amount DECIMAL(8,2) DEFAULT NULL,
    status ENUM('pending', 'accepted', 'rejected', 'payment_pending', 'paid', 
               'in_transit', 'delivered', 'completed', 'cancelled', 'disputed') 
           DEFAULT 'pending',
    pickup_address TEXT DEFAULT NULL,
    delivery_address TEXT DEFAULT NULL,
    pickup_date DATETIME DEFAULT NULL,
    delivery_date DATETIME DEFAULT NULL,
    special_instructions TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL, -- Expiration de l'offre
    
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_trip_bookings (trip_id),
    INDEX idx_sender_bookings (sender_id),
    INDEX idx_receiver_bookings (receiver_id),
    INDEX idx_booking_status (status),
    INDEX idx_booking_dates (pickup_date, delivery_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des négociations de prix
CREATE TABLE IF NOT EXISTS booking_negotiations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    proposed_by INT NOT NULL, -- sender_id ou receiver_id
    amount DECIMAL(8,2) NOT NULL,
    message TEXT DEFAULT NULL,
    is_accepted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (proposed_by) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_booking_negotiations (booking_id),
    INDEX idx_negotiations_user (proposed_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des transactions et paiements
CREATE TABLE IF NOT EXISTS transactions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    uuid VARCHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    booking_id INT NOT NULL,
    stripe_payment_intent_id VARCHAR(255) DEFAULT NULL,
    stripe_payment_method_id VARCHAR(255) DEFAULT NULL,
    amount DECIMAL(8,2) NOT NULL, -- Montant total payé par le client
    commission DECIMAL(8,2) NOT NULL, -- Commission KiloShare
    receiver_amount DECIMAL(8,2) NOT NULL, -- Montant pour le transporteur
    currency VARCHAR(3) DEFAULT 'CAD',
    status ENUM('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'refunded') 
           DEFAULT 'pending',
    payment_method ENUM('stripe', 'paypal', 'bank_transfer') DEFAULT 'stripe',
    processed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    
    INDEX idx_transaction_booking (booking_id),
    INDEX idx_transaction_status (status),
    INDEX idx_transaction_stripe (stripe_payment_intent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table du système d'escrow (rétention des fonds)
CREATE TABLE IF NOT EXISTS escrow_accounts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    transaction_id INT NOT NULL,
    amount_held DECIMAL(8,2) NOT NULL,
    amount_released DECIMAL(8,2) DEFAULT 0.00,
    hold_reason ENUM('payment_security', 'delivery_confirmation', 'dispute_resolution') 
                DEFAULT 'delivery_confirmation',
    status ENUM('holding', 'partial_release', 'fully_released', 'disputed') 
           DEFAULT 'holding',
    held_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    released_at TIMESTAMP NULL,
    release_notes TEXT DEFAULT NULL,
    
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    
    INDEX idx_escrow_transaction (transaction_id),
    INDEX idx_escrow_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des photos de colis
CREATE TABLE IF NOT EXISTS booking_package_photos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    photo_url VARCHAR(500) NOT NULL,
    photo_type ENUM('package', 'dimensions', 'content', 'delivery_proof') DEFAULT 'package',
    cloudinary_public_id VARCHAR(255) DEFAULT NULL,
    uploaded_by INT NOT NULL, -- sender ou receiver
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_package_photos (booking_id),
    INDEX idx_photos_type (photo_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des contrats générés (PDF)
CREATE TABLE IF NOT EXISTS booking_contracts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    contract_number VARCHAR(50) NOT NULL UNIQUE,
    pdf_url VARCHAR(500) DEFAULT NULL,
    pdf_cloudinary_id VARCHAR(255) DEFAULT NULL,
    contract_data JSON DEFAULT NULL, -- Données utilisées pour générer le PDF
    status ENUM('draft', 'generated', 'signed', 'archived') DEFAULT 'draft',
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    signed_at TIMESTAMP NULL,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    
    INDEX idx_contract_booking (booking_id),
    INDEX idx_contract_number (contract_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des notifications de booking
CREATE TABLE IF NOT EXISTS booking_notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    user_id INT NOT NULL,
    type ENUM('new_booking', 'booking_accepted', 'booking_rejected', 'negotiation_offer', 
             'payment_required', 'payment_confirmed', 'in_transit', 'delivered', 'completed') 
         NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_booking_notifications (booking_id),
    INDEX idx_user_notifications (user_id, is_read),
    INDEX idx_notification_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Triggers pour calculer automatiquement les montants
DELIMITER $$

CREATE TRIGGER tr_bookings_calculate_commission
    BEFORE UPDATE ON bookings
    FOR EACH ROW
BEGIN
    IF NEW.final_price IS NOT NULL AND NEW.final_price > 0 THEN
        SET NEW.commission_amount = NEW.final_price * (NEW.commission_rate / 100);
    END IF;
END$$

DELIMITER ;

-- Données de test pour le développement (optionnel)
-- INSERT INTO bookings (trip_id, sender_id, receiver_id, package_description, weight_kg, proposed_price)
-- VALUES (1, 2, 1, 'Documents importants', 0.5, 25.00);

-- Vues utiles pour les rapports
CREATE OR REPLACE VIEW booking_summary AS
SELECT 
    b.id,
    b.uuid,
    b.status,
    b.package_description,
    b.weight_kg,
    b.final_price,
    b.commission_amount,
    t_sender.email as sender_email,
    t_receiver.email as receiver_email,
    tr.departure_city,
    tr.arrival_city,
    b.created_at
FROM bookings b
LEFT JOIN users t_sender ON b.sender_id = t_sender.id
LEFT JOIN users t_receiver ON b.receiver_id = t_receiver.id  
LEFT JOIN trips tr ON b.trip_id = tr.id;

-- Index pour les performances
CREATE INDEX idx_bookings_created_at ON bookings(created_at);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);

-- Commentaires pour documentation
ALTER TABLE bookings COMMENT = 'Table principale des réservations de transport de colis';
ALTER TABLE booking_negotiations COMMENT = 'Négociations de prix entre expéditeur et transporteur';
ALTER TABLE transactions COMMENT = 'Transactions financières et paiements Stripe';
ALTER TABLE escrow_accounts COMMENT = 'Système de rétention de fonds jusqu''à livraison confirmée';
ALTER TABLE booking_package_photos COMMENT = 'Photos des colis pour les réservations';
ALTER TABLE booking_contracts COMMENT = 'Contrats PDF générés pour les réservations';
ALTER TABLE booking_notifications COMMENT = 'Notifications liées aux réservations';