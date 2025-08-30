-- Extensions pour l'authentification sociale
-- Ajouter ces colonnes à la table users existante

ALTER TABLE users 
ADD COLUMN social_provider VARCHAR(20) NULL DEFAULT NULL COMMENT 'google, facebook, apple',
ADD COLUMN social_id VARCHAR(255) NULL DEFAULT NULL COMMENT 'ID from social provider',
ADD COLUMN provider_data JSON NULL DEFAULT NULL COMMENT 'Additional data from provider',
ADD INDEX idx_social_provider (social_provider),
ADD INDEX idx_social_id (social_id),
ADD UNIQUE INDEX unique_social_account (social_provider, social_id);

-- Table pour gérer les comptes sociaux multiples (optionnel)
CREATE TABLE user_social_accounts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    provider VARCHAR(20) NOT NULL COMMENT 'google, facebook, apple',
    provider_id VARCHAR(255) NOT NULL COMMENT 'ID from social provider',
    provider_email VARCHAR(255) NULL,
    provider_name VARCHAR(255) NULL,
    profile_picture_url TEXT NULL,
    access_token TEXT NULL COMMENT 'For API calls (encrypted)',
    refresh_token TEXT NULL COMMENT 'For token refresh (encrypted)',
    token_expires_at TIMESTAMP NULL,
    provider_data JSON NULL COMMENT 'Additional provider data',
    is_primary BOOLEAN DEFAULT FALSE COMMENT 'Primary social account',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_provider_account (provider, provider_id),
    INDEX idx_user_provider (user_id, provider),
    INDEX idx_provider_id (provider, provider_id)
);

-- Table pour les tentatives d'authentification sociale (logging)
CREATE TABLE social_auth_attempts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    provider VARCHAR(20) NOT NULL,
    provider_id VARCHAR(255) NULL,
    email VARCHAR(255) NULL,
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,
    success BOOLEAN NOT NULL DEFAULT FALSE,
    error_message TEXT NULL,
    user_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_provider_attempt (provider, created_at),
    INDEX idx_user_attempt (user_id, created_at),
    INDEX idx_ip_attempt (ip_address, created_at)
);

-- Modifier la colonne password_hash pour permettre NULL (pour les utilisateurs sociaux)
ALTER TABLE users 
MODIFY COLUMN password_hash VARCHAR(255) NULL DEFAULT NULL;