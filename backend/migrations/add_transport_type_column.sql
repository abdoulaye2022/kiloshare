-- Migration pour ajouter la colonne transport_type à la table trips

-- Ajouter la colonne transport_type
ALTER TABLE trips 
ADD COLUMN transport_type VARCHAR(50) NOT NULL DEFAULT 'car' AFTER arrival_date;

-- Ajouter un index pour optimiser les requêtes par type de transport
ALTER TABLE trips 
ADD INDEX idx_trips_transport_type (transport_type);