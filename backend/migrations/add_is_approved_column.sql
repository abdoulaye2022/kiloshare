-- Migration pour ajouter uniquement la colonne is_approved manquante
-- Date: 2025-08-31

-- Ajouter la colonne is_approved si elle n'existe pas
ALTER TABLE trips 
ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE AFTER status;

-- Ajouter l'index pour optimiser les requêtes
ALTER TABLE trips 
ADD INDEX IF NOT EXISTS idx_is_approved (is_approved);

-- Mettre à jour les voyages existants pour qu'ils soient approuvés par défaut
-- (pour éviter de casser les données existantes)
UPDATE trips SET is_approved = TRUE WHERE status IN ('active', 'completed');

-- Mettre à jour le statut ENUM pour inclure 'published' s'il n'existe pas déjà
ALTER TABLE trips 
MODIFY COLUMN status ENUM('draft','pending_review','published','active','rejected','paused','booked','in_progress','completed','cancelled','expired') DEFAULT 'draft';