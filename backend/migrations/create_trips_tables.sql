-- Migration pour le module des annonces de voyage
-- Date: 2025-08-30

-- Table principale des voyages
CREATE TABLE trips (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    user_id INT NOT NULL,
    
    -- Informations de départ
    departure_city VARCHAR(100) NOT NULL,
    departure_country VARCHAR(100) NOT NULL,
    departure_airport_code VARCHAR(10),
    departure_date DATETIME NOT NULL,
    
    -- Informations d'arrivée
    arrival_city VARCHAR(100) NOT NULL,
    arrival_country VARCHAR(100) NOT NULL,
    arrival_airport_code VARCHAR(10),
    arrival_date DATETIME NOT NULL,
    
    -- Capacité et prix
    available_weight_kg DECIMAL(5,2) NOT NULL DEFAULT 23.00,
    price_per_kg DECIMAL(8,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    
    -- Informations vol (optionnel)
    flight_number VARCHAR(20),
    airline VARCHAR(100),
    ticket_verified BOOLEAN DEFAULT FALSE,
    ticket_verification_date DATETIME NULL,
    
    -- Statut et métadonnées
    status ENUM('draft', 'published', 'completed', 'cancelled') DEFAULT 'draft',
    view_count INT DEFAULT 0,
    booking_count INT DEFAULT 0,
    
    -- Description et notes
    description TEXT,
    special_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Index et contraintes
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_departure_date (departure_date),
    INDEX idx_departure_city (departure_city),
    INDEX idx_arrival_city (arrival_city),
    INDEX idx_status (status),
    INDEX idx_user_id (user_id)
);

-- Table des restrictions d'objets pour chaque voyage
CREATE TABLE trip_restrictions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trip_id INT NOT NULL,
    
    -- Catégories d'objets interdits (stockées en JSON pour flexibilité)
    restricted_categories JSON,
    
    -- Liste détaillée d'objets spécifiques interdits
    restricted_items JSON,
    
    -- Notes sur les restrictions
    restriction_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    INDEX idx_trip_id (trip_id)
);

-- Table pour tracker les vues des annonces
CREATE TABLE trip_views (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trip_id INT NOT NULL,
    viewer_id INT NULL, -- NULL pour les utilisateurs non connectés
    viewer_ip VARCHAR(45), -- Support IPv4 et IPv6
    user_agent TEXT,
    
    -- Métadonnées de la vue
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    view_duration_seconds INT DEFAULT 0,
    
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE SET NULL,
    
    INDEX idx_trip_id (trip_id),
    INDEX idx_viewer_id (viewer_id),
    INDEX idx_viewed_at (viewed_at),
    
    -- Éviter les doublons de vues rapprochées (index simple)
    INDEX idx_view_dedup (trip_id, viewer_id, viewer_ip)
);

-- Table pour les images des voyages (optionnel)
CREATE TABLE trip_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trip_id INT NOT NULL,
    
    image_url VARCHAR(500) NOT NULL,
    image_type ENUM('ticket', 'baggage', 'other') DEFAULT 'other',
    is_primary BOOLEAN DEFAULT FALSE,
    
    -- Métadonnées image
    file_size_kb INT,
    width INT,
    height INT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    INDEX idx_trip_id (trip_id),
    INDEX idx_image_type (image_type)
);

-- Table des calculs de prix suggérés (cache)
CREATE TABLE trip_price_calculations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Route
    departure_city VARCHAR(100) NOT NULL,
    departure_country VARCHAR(100) NOT NULL,
    arrival_city VARCHAR(100) NOT NULL,
    arrival_country VARCHAR(100) NOT NULL,
    
    -- Distance et calculs
    distance_km INT,
    base_price_per_kg DECIMAL(8,2),
    commission_rate DECIMAL(4,2) DEFAULT 15.00, -- 15% par défaut
    suggested_price_per_kg DECIMAL(8,2),
    
    -- Devise et conversion
    base_currency VARCHAR(3) DEFAULT 'EUR',
    exchange_rates JSON, -- Taux de change vers CAD, USD, EUR
    
    -- Cache validity
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    INDEX idx_route (departure_city, arrival_city),
    INDEX idx_expires_at (expires_at)
);

-- Vues pour faciliter les requêtes

-- Vue des voyages actifs avec informations utilisateur
CREATE VIEW active_trips_view AS
SELECT 
    t.*,
    u.first_name,
    u.last_name,
    u.profile_picture,
    u.is_verified,
    COUNT(tv.id) as total_views
FROM trips t
JOIN users u ON t.user_id = u.id
LEFT JOIN trip_views tv ON t.id = tv.trip_id
WHERE t.status = 'published' 
  AND t.departure_date > NOW()
GROUP BY t.id, u.id;

-- Vue des statistiques par utilisateur
CREATE VIEW user_trip_stats AS
SELECT 
    user_id,
    COUNT(*) as total_trips,
    COUNT(CASE WHEN status = 'published' THEN 1 END) as published_trips,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_trips,
    SUM(view_count) as total_views,
    SUM(booking_count) as total_bookings,
    AVG(price_per_kg) as avg_price_per_kg
FROM trips
GROUP BY user_id;