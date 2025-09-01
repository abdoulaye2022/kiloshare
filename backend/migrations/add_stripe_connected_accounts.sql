-- Migration pour les comptes Stripe connectés
-- Date: 2025-09-01
-- Module: Stripe Connected Accounts

-- Table des comptes Stripe connectés des utilisateurs
CREATE TABLE IF NOT EXISTS user_stripe_accounts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    stripe_account_id VARCHAR(255) NOT NULL UNIQUE,
    status ENUM('pending', 'onboarding', 'active', 'restricted', 'rejected') DEFAULT 'pending',
    details_submitted BOOLEAN DEFAULT FALSE,
    charges_enabled BOOLEAN DEFAULT FALSE,
    payouts_enabled BOOLEAN DEFAULT FALSE,
    onboarding_url VARCHAR(500) DEFAULT NULL,
    requirements JSON DEFAULT NULL, -- Stockage des exigences Stripe
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_user_stripe (user_id),
    INDEX idx_stripe_account (stripe_account_id),
    INDEX idx_account_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour les tentatives de création de comptes (historique/debug)
CREATE TABLE IF NOT EXISTS stripe_account_creation_log (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    stripe_account_id VARCHAR(255) DEFAULT NULL,
    status ENUM('attempting', 'success', 'failed') DEFAULT 'attempting',
    error_message TEXT DEFAULT NULL,
    stripe_response JSON DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    INDEX idx_log_user (user_id),
    INDEX idx_log_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Mise à jour de la table users pour inclure un flag Stripe
ALTER TABLE users 
ADD COLUMN stripe_setup_completed BOOLEAN DEFAULT FALSE AFTER email_verified_at,
ADD COLUMN stripe_onboarding_completed_at TIMESTAMP NULL AFTER stripe_setup_completed;

-- Index pour les recherches rapides
CREATE INDEX idx_users_stripe_setup ON users(stripe_setup_completed);

-- Vue pour les utilisateurs avec statut Stripe complet
CREATE OR REPLACE VIEW users_with_stripe_status AS
SELECT 
    u.id,
    u.email,
    u.first_name,
    u.last_name,
    u.stripe_setup_completed,
    u.stripe_onboarding_completed_at,
    usa.stripe_account_id,
    usa.status as stripe_status,
    usa.charges_enabled,
    usa.payouts_enabled,
    usa.details_submitted,
    CASE 
        WHEN usa.charges_enabled = TRUE AND usa.payouts_enabled = TRUE THEN 'ready_for_transactions'
        WHEN usa.details_submitted = TRUE THEN 'pending_verification'
        WHEN usa.stripe_account_id IS NOT NULL THEN 'onboarding_incomplete'
        ELSE 'no_account'
    END as transaction_readiness
FROM users u
LEFT JOIN user_stripe_accounts usa ON u.id = usa.user_id;

-- Commentaires pour documentation
ALTER TABLE user_stripe_accounts COMMENT = 'Comptes Stripe Connect pour les utilisateurs transporteurs';
ALTER TABLE stripe_account_creation_log COMMENT = 'Historique des tentatives de création de comptes Stripe';

-- Données de test (optionnel pour le développement)
-- INSERT INTO user_stripe_accounts (user_id, stripe_account_id, status, charges_enabled, payouts_enabled, details_submitted)
-- VALUES (1, 'acct_dev_test_completed', 'active', TRUE, TRUE, TRUE);