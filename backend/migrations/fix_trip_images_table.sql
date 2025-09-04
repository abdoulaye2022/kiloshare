-- Migration pour corriger la table trip_images

-- Ajouter les colonnes manquantes
ALTER TABLE trip_images 
ADD COLUMN url VARCHAR(500) NOT NULL AFTER image_path,
ADD COLUMN thumbnail VARCHAR(500) NULL AFTER url,
ADD COLUMN alt_text VARCHAR(255) NULL AFTER thumbnail,
ADD COLUMN is_primary BOOLEAN DEFAULT FALSE AFTER alt_text,
ADD COLUMN width INT NULL AFTER is_primary,
ADD COLUMN height INT NULL AFTER width;

-- Modifier la colonne order pour autoriser les valeurs nulles et changer le défaut
ALTER TABLE trip_images 
MODIFY COLUMN `order` INT DEFAULT 0;

-- Modifier la colonne file_size pour autoriser les valeurs nulles  
ALTER TABLE trip_images 
MODIFY COLUMN file_size INT NULL;

-- Ajouter les index pour optimiser les requêtes
ALTER TABLE trip_images 
ADD INDEX idx_trip_images_primary (is_primary),
ADD INDEX idx_trip_images_order (`order`);