-- Migration: Add Search System Tables (Simple Version)
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
    INDEX idx_city_name (city_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;