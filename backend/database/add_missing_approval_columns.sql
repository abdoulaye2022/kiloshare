-- =====================================================
-- AJOUTER LES COLONNES MANQUANTES POUR L'APPROBATION
-- =====================================================

USE kiloshare;

-- Ajouter les colonnes manquantes pour le processus d'approbation
ALTER TABLE trips 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP NULL AFTER published_at,
ADD COLUMN IF NOT EXISTS approved_by INT NULL AFTER approved_at,
ADD CONSTRAINT fk_trips_approved_by FOREIGN KEY (approved_by) REFERENCES users(id) ON DELETE SET NULL;

-- Ajouter un index pour les requêtes d'approbation
ALTER TABLE trips 
ADD INDEX IF NOT EXISTS idx_trips_approved_at (approved_at),
ADD INDEX IF NOT EXISTS idx_trips_approved_by (approved_by);

-- Vérifier que les colonnes ont été ajoutées
SELECT 'Colonnes ajoutées avec succès' as status;
DESCRIBE trips;