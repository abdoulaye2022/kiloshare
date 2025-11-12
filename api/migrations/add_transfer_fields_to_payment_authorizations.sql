-- Migration: Ajouter les champs de transfert à payment_authorizations
-- Date: 2025-01-11

ALTER TABLE payment_authorizations
ADD COLUMN transferred_at DATETIME NULL COMMENT 'Date du transfert au transporteur',
ADD COLUMN transfer_id VARCHAR(255) NULL COMMENT 'ID du transfert Stripe',
ADD INDEX idx_transferred_at (transferred_at);
