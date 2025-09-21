-- Migration pour ajouter les colonnes manquantes à la table trips

-- Ajouter la colonne is_domestic
ALTER TABLE trips 
ADD COLUMN is_domestic BOOLEAN NOT NULL DEFAULT FALSE AFTER currency;

-- Ajouter la colonne restrictions (JSON pour stocker les restrictions)
ALTER TABLE trips 
ADD COLUMN restrictions JSON NULL AFTER is_domestic;

-- Ajouter la colonne special_instructions (alias de special_notes)
ALTER TABLE trips 
ADD COLUMN special_instructions TEXT NULL AFTER restrictions;

-- Ajouter des index pour optimiser les requêtes
ALTER TABLE trips 
ADD INDEX idx_trips_is_domestic (is_domestic);