-- Migration: Système de favoris pour les voyages
-- Date: 2025-09-01
-- Description: Table pour stocker les voyages favoris des utilisateurs

CREATE TABLE IF NOT EXISTS user_trip_favorites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    trip_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Index pour performance
    INDEX idx_user_favorites (user_id, created_at DESC),
    INDEX idx_trip_favorites (trip_id),
    UNIQUE KEY uk_user_trip (user_id, trip_id),
    
    -- Foreign keys
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;