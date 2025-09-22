-- Migration pour ajouter la colonne type à la table transactions
-- Fichier: 2024_add_type_to_transactions.sql

ALTER TABLE transactions
ADD COLUMN type VARCHAR(50) NULL AFTER booking_id,
ADD INDEX idx_type (type);

-- Mettre à jour les transactions existantes avec un type par défaut
UPDATE transactions
SET type = 'payment_capture'
WHERE type IS NULL;