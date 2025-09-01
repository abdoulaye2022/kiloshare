-- Migration: Add Search System Tables
-- Created: 2025-09-01

-- Table pour l'historique des recherches
CREATE TABLE IF NOT EXISTS search_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    search_params_json JSON NOT NULL,
    searched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_searched (user_id, searched_at DESC),
    INDEX idx_searched_at (searched_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour les alertes de recherche
CREATE TABLE IF NOT EXISTS search_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    departure_city VARCHAR(255) NOT NULL,
    departure_country VARCHAR(100) NOT NULL DEFAULT 'Canada',
    arrival_city VARCHAR(255) NOT NULL,
    arrival_country VARCHAR(100) NOT NULL DEFAULT 'Canada',
    date_range_start DATE NULL,
    date_range_end DATE NULL,
    max_price DECIMAL(10,2) NULL,
    max_weight INTEGER NULL,
    transport_type ENUM('plane', 'car', 'bus', 'train') NULL,
    min_rating DECIMAL(3,2) NULL DEFAULT 0.00,
    verified_only BOOLEAN DEFAULT FALSE,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_active (user_id, active),
    INDEX idx_departure_arrival (departure_city, arrival_city),
    INDEX idx_date_range (date_range_start, date_range_end),
    INDEX idx_active_created (active, created_at DESC),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour les routes populaires (statistiques)
CREATE TABLE IF NOT EXISTS popular_routes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    departure_city VARCHAR(255) NOT NULL,
    departure_country VARCHAR(100) NOT NULL DEFAULT 'Canada',
    arrival_city VARCHAR(255) NOT NULL,
    arrival_country VARCHAR(100) NOT NULL DEFAULT 'Canada',
    search_count INT DEFAULT 1,
    last_searched TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_route (departure_city, departure_country, arrival_city, arrival_country),
    INDEX idx_search_count (search_count DESC),
    INDEX idx_departure_city (departure_city),
    INDEX idx_arrival_city (arrival_city),
    INDEX idx_last_searched (last_searched DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Index supplémentaires pour optimiser les recherches sur la table trips
ALTER TABLE trips 
ADD INDEX IF NOT EXISTS idx_search_departure (departure_city, departure_country),
ADD INDEX IF NOT EXISTS idx_search_arrival (arrival_city, arrival_country),
ADD INDEX IF NOT EXISTS idx_search_dates (departure_date, arrival_date),
ADD INDEX IF NOT EXISTS idx_search_status_date (status, departure_date),
ADD INDEX IF NOT EXISTS idx_search_price (price_per_kg),
ADD INDEX IF NOT EXISTS idx_search_weight (available_weight_kg),
ADD INDEX IF NOT EXISTS idx_search_composite (departure_city, arrival_city, departure_date, status);

-- Table pour les suggestions de villes (cache optimisé)
CREATE TABLE IF NOT EXISTS city_suggestions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    city_name VARCHAR(255) NOT NULL,
    country VARCHAR(100) NOT NULL,
    search_count INT DEFAULT 0,
    is_popular BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_city (city_name, country),
    INDEX idx_popular_count (is_popular DESC, search_count DESC),
    INDEX idx_city_name (city_name),
    FULLTEXT KEY ft_city_search (city_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insérer les villes populaires initiales (Canada)
INSERT IGNORE INTO city_suggestions (city_name, country, search_count, is_popular) VALUES
('Toronto', 'Canada', 100, TRUE),
('Vancouver', 'Canada', 95, TRUE),
('Montreal', 'Canada', 90, TRUE),
('Calgary', 'Canada', 85, TRUE),
('Edmonton', 'Canada', 80, TRUE),
('Ottawa', 'Canada', 75, TRUE),
('Winnipeg', 'Canada', 70, TRUE),
('Quebec City', 'Canada', 65, TRUE),
('Halifax', 'Canada', 60, TRUE),
('Victoria', 'Canada', 55, TRUE),
('Saskatoon', 'Canada', 50, TRUE),
('Regina', 'Canada', 45, TRUE),
('St. Johns', 'Canada', 40, TRUE),
('Fredericton', 'Canada', 35, TRUE),
('Charlottetown', 'Canada', 30, TRUE),
-- Villes internationales populaires
('Paris', 'France', 85, TRUE),
('London', 'United Kingdom', 80, TRUE),
('New York', 'United States', 75, TRUE),
('Casablanca', 'Morocco', 70, TRUE),
('Dakar', 'Senegal', 65, TRUE),
('Abidjan', 'Ivory Coast', 60, TRUE),
('Dubai', 'United Arab Emirates', 55, TRUE),
('Tokyo', 'Japan', 50, TRUE);

-- Créer une vue pour les statistiques de recherche
CREATE OR REPLACE VIEW search_statistics AS
SELECT 
    departure_city,
    departure_country,
    arrival_city, 
    arrival_country,
    COUNT(*) as total_searches,
    COUNT(DISTINCT user_id) as unique_users,
    MAX(searched_at) as last_search_date,
    AVG(JSON_EXTRACT(search_params_json, '$.max_price')) as avg_max_price_searched
FROM search_history 
WHERE searched_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY departure_city, departure_country, arrival_city, arrival_country
ORDER BY total_searches DESC;

-- Procédure stockée pour nettoyer l'historique ancien (optionnel)
DELIMITER //
CREATE PROCEDURE CleanOldSearchHistory()
BEGIN
    -- Garder seulement les 100 dernières recherches par utilisateur
    DELETE sh1 FROM search_history sh1
    INNER JOIN (
        SELECT user_id, 
               ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY searched_at DESC) as rn,
               id
        FROM search_history
    ) sh2 ON sh1.id = sh2.id
    WHERE sh2.rn > 100;
    
    -- Supprimer les recherches de plus de 6 mois
    DELETE FROM search_history 
    WHERE searched_at < DATE_SUB(NOW(), INTERVAL 6 MONTH);
END //
DELIMITER ;