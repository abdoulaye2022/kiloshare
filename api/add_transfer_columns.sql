-- Migration pour ajouter les colonnes de transfert à la table transactions
-- Exécutez ce script dans votre base de données kiloshare

USE kiloshare;

ALTER TABLE transactions 
ADD COLUMN transfer_status VARCHAR(50) DEFAULT 'pending' AFTER status,
ADD COLUMN stripe_transfer_id VARCHAR(255) DEFAULT NULL AFTER stripe_payment_method_id,
ADD COLUMN transferred_at TIMESTAMP NULL DEFAULT NULL AFTER processed_at,
ADD COLUMN rejected_at TIMESTAMP NULL DEFAULT NULL AFTER transferred_at,
ADD COLUMN rejected_by INT DEFAULT NULL AFTER rejected_at;

-- Vérifier que les colonnes ont été ajoutées
DESCRIBE transactions;