-- Migration pour créer la table user_fcm_tokens
-- Créée le: $(date +%Y-%m-%d)

-- Créer la table des tokens FCM
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL DEFAULT 'mobile',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    device_info JSON NULL,
    app_version VARCHAR(50) NULL,
    last_used_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    
    INDEX idx_user_id (user_id),
    INDEX idx_is_active (is_active),
    INDEX idx_platform (platform),
    INDEX idx_last_used_at (last_used_at),
    INDEX idx_created_at (created_at),
    
    UNIQUE KEY unique_user_token (user_id, fcm_token(255)),
    
    CONSTRAINT fk_user_fcm_tokens_user_id
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Commenter la table
ALTER TABLE user_fcm_tokens COMMENT = 'Stockage des tokens FCM pour les notifications push des utilisateurs';

-- Ajouter des commentaires sur les colonnes
ALTER TABLE user_fcm_tokens 
    MODIFY COLUMN id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique du token FCM',
    MODIFY COLUMN user_id INT NOT NULL COMMENT 'ID de l\'utilisateur propriétaire du token',
    MODIFY COLUMN fcm_token TEXT NOT NULL COMMENT 'Token FCM généré par Firebase',
    MODIFY COLUMN platform VARCHAR(20) NOT NULL DEFAULT 'mobile' COMMENT 'Plateforme (mobile, web, etc.)',
    MODIFY COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Indique si le token est actif',
    MODIFY COLUMN device_info JSON NULL COMMENT 'Informations sur l\'appareil (modèle, version OS, etc.)',
    MODIFY COLUMN app_version VARCHAR(50) NULL COMMENT 'Version de l\'application mobile',
    MODIFY COLUMN last_used_at TIMESTAMP NULL COMMENT 'Dernière utilisation du token',
    MODIFY COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Date de création',
    MODIFY COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Date de dernière modification',
    MODIFY COLUMN deleted_at TIMESTAMP NULL COMMENT 'Date de suppression logique (soft delete)';

-- Insérer quelques tokens de test si nécessaire (optionnel)
-- INSERT INTO user_fcm_tokens (user_id, fcm_token, platform, device_info) 
-- VALUES (1, 'test_token_123', 'android', '{"model": "Pixel 7", "os_version": "13"}')
-- ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;