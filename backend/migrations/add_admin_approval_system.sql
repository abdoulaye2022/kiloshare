-- Migration pour ajouter le système d'approbation admin
-- Date: 2025-08-31

-- Ajouter les colonnes manquantes pour le système d'approbation
ALTER TABLE trips 
ADD COLUMN is_approved BOOLEAN DEFAULT FALSE AFTER status,
ADD COLUMN approved_by INT NULL AFTER is_approved,
ADD COLUMN approved_at TIMESTAMP NULL AFTER approved_by,
ADD COLUMN rejected_by INT NULL AFTER approved_at,
ADD COLUMN rejected_at TIMESTAMP NULL AFTER rejected_by,
ADD COLUMN rejection_reason TEXT NULL AFTER rejected_at,
ADD COLUMN deleted_at TIMESTAMP NULL AFTER rejection_reason;

-- Ajouter les contraintes de clés étrangères
ALTER TABLE trips 
ADD CONSTRAINT fk_trips_approved_by FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL,
ADD CONSTRAINT fk_trips_rejected_by FOREIGN KEY (rejected_by) REFERENCES users(id) ON DELETE SET NULL;

-- Ajouter les index pour optimiser les requêtes
ALTER TABLE trips 
ADD INDEX idx_is_approved (is_approved),
ADD INDEX idx_approved_at (approved_at),
ADD INDEX idx_deleted_at (deleted_at);

-- Mettre à jour le statut ENUM pour inclure les nouveaux statuts
ALTER TABLE trips 
MODIFY COLUMN status ENUM('draft', 'pending_approval', 'published', 'active', 'paused', 'completed', 'cancelled', 'rejected') DEFAULT 'draft';

-- Table des rapports de voyage
CREATE TABLE IF NOT EXISTS trip_reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trip_id INT NOT NULL,
    reporter_id INT NOT NULL,
    report_type ENUM('spam', 'fake', 'inappropriate', 'other') NOT NULL,
    description TEXT,
    status ENUM('pending', 'reviewed', 'resolved') DEFAULT 'pending',
    reviewed_by INT NULL,
    reviewed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL,
    
    INDEX idx_trip_id (trip_id),
    INDEX idx_reporter_id (reporter_id),
    INDEX idx_status (status)
);

-- Table des favoris
CREATE TABLE IF NOT EXISTS trip_favorites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    trip_id INT NOT NULL,
    user_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    UNIQUE KEY unique_favorite (trip_id, user_id),
    INDEX idx_user_id (user_id)
);

-- Table des brouillons de voyage
CREATE TABLE IF NOT EXISTS trip_drafts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    draft_data JSON NOT NULL,
    title VARCHAR(255),
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_last_modified (last_modified)
);

-- Mettre à jour les voyages existants pour qu'ils soient approuvés par défaut
-- (pour éviter de casser les données existantes)
UPDATE trips SET is_approved = TRUE WHERE status IN ('published', 'active', 'completed');