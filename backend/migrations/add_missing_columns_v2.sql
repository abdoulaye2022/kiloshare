-- Script de migration pour ajouter les colonnes manquantes (compatible MySQL)

-- Ajouter les colonnes manquantes à la table trips
ALTER TABLE trips 
ADD COLUMN uuid VARCHAR(36) UNIQUE AFTER id,
ADD COLUMN published_at TIMESTAMP NULL AFTER status,
ADD COLUMN expires_at TIMESTAMP NULL AFTER published_at,
ADD COLUMN deleted_at TIMESTAMP NULL AFTER updated_at;

-- Ajouter les colonnes manquantes à la table users
ALTER TABLE users 
ADD COLUMN uuid VARCHAR(36) UNIQUE AFTER id,
ADD COLUMN social_provider VARCHAR(50) NULL AFTER last_login_at,
ADD COLUMN social_id VARCHAR(255) NULL AFTER social_provider,
ADD COLUMN deleted_at TIMESTAMP NULL AFTER updated_at;

-- Ajouter les colonnes manquantes à la table bookings
ALTER TABLE bookings 
ADD COLUMN uuid VARCHAR(36) UNIQUE AFTER id,
ADD COLUMN commission_rate DECIMAL(6,4) DEFAULT 0.05 AFTER payment_intent_id,
ADD COLUMN commission_amount DECIMAL(10,2) DEFAULT 0.00 AFTER commission_rate,
ADD COLUMN traveler_amount DECIMAL(10,2) DEFAULT 0.00 AFTER commission_amount;