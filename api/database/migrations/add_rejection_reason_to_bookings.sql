-- Migration pour ajouter la colonne rejection_reason à la table bookings
-- Date: 2025-01-XX

-- Ajouter la colonne rejection_reason
ALTER TABLE bookings
ADD COLUMN rejection_reason TEXT NULL
COMMENT 'Raison optionnelle fournie lors du rejet d\'une réservation';

-- Index pour optimiser les requêtes sur les rejets avec raison
CREATE INDEX idx_bookings_rejection_reason ON bookings(rejection_reason(255));

-- Vérification que la colonne a été ajoutée
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'bookings'
  AND TABLE_SCHEMA = DATABASE()
  AND COLUMN_NAME = 'rejection_reason';