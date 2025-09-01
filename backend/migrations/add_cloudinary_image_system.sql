-- Migration: Système complet de gestion d'images Cloudinary pour KiloShare
-- Date: 2025-09-01
-- Description: Tables pour la gestion optimisée des images avec monitoring et nettoyage automatique

-- Table principale pour stocker les métadonnées de toutes les images
CREATE TABLE IF NOT EXISTS image_uploads (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL UNIQUE DEFAULT (UUID()),
    user_id INT NOT NULL,
    
    -- Informations Cloudinary
    cloudinary_public_id VARCHAR(255) NOT NULL UNIQUE,
    cloudinary_url VARCHAR(500) NOT NULL,
    cloudinary_secure_url VARCHAR(500) NOT NULL,
    cloudinary_version VARCHAR(50) NOT NULL,
    cloudinary_signature VARCHAR(100) NOT NULL,
    
    -- Métadonnées de l'image
    original_filename VARCHAR(255) NOT NULL,
    file_size INT NOT NULL COMMENT 'Taille en bytes',
    width INT NOT NULL,
    height INT NOT NULL,
    format VARCHAR(10) NOT NULL,
    
    -- Catégorisation et organisation
    image_type ENUM('avatar', 'kyc_document', 'trip_photo', 'package_photo', 'delivery_proof') NOT NULL,
    image_category VARCHAR(50) NULL COMMENT 'Sous-catégorie (ex: passport, id_card, front, back)',
    
    -- Association aux entités métier
    related_entity_type ENUM('user', 'trip', 'package', 'delivery') NULL,
    related_entity_id INT NULL,
    
    -- Paramètres de compression et transformation
    compression_quality INT NOT NULL DEFAULT 80 COMMENT 'Qualité de compression appliquée (0-100)',
    transformations JSON NULL COMMENT 'Transformations Cloudinary appliquées',
    
    -- Gestion du cycle de vie
    is_temporary BOOLEAN NOT NULL DEFAULT FALSE,
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at DATETIME NULL COMMENT 'Date d\'expiration pour nettoyage automatique',
    
    -- Statistiques d\'usage
    download_count INT NOT NULL DEFAULT 0,
    last_accessed_at DATETIME NULL,
    
    -- Tags pour faciliter la gestion
    tags JSON NULL COMMENT 'Tags Cloudinary pour catégorisation',
    
    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    
    -- Index pour performance
    INDEX idx_user_type (user_id, image_type),
    INDEX idx_public_id (cloudinary_public_id),
    INDEX idx_entity (related_entity_type, related_entity_id),
    INDEX idx_cleanup (expires_at, is_temporary, deleted_at),
    INDEX idx_stats (last_accessed_at, download_count),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour le tracking quotidien de l'usage Cloudinary
CREATE TABLE IF NOT EXISTS cloudinary_usage_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    
    -- Statistiques de stockage (en bytes)
    storage_used BIGINT NOT NULL DEFAULT 0,
    storage_limit BIGINT NOT NULL DEFAULT 26843545600 COMMENT '25GB en bytes',
    
    -- Statistiques de bande passante (en bytes)
    bandwidth_used BIGINT NOT NULL DEFAULT 0,
    bandwidth_limit BIGINT NOT NULL DEFAULT 26843545600 COMMENT '25GB en bytes',
    
    -- Compteurs par type d'image
    avatars_count INT NOT NULL DEFAULT 0,
    avatars_size BIGINT NOT NULL DEFAULT 0,
    kyc_documents_count INT NOT NULL DEFAULT 0,
    kyc_documents_size BIGINT NOT NULL DEFAULT 0,
    trip_photos_count INT NOT NULL DEFAULT 0,
    trip_photos_size BIGINT NOT NULL DEFAULT 0,
    package_photos_count INT NOT NULL DEFAULT 0,
    package_photos_size BIGINT NOT NULL DEFAULT 0,
    delivery_proofs_count INT NOT NULL DEFAULT 0,
    delivery_proofs_size BIGINT NOT NULL DEFAULT 0,
    
    -- Statistiques d'upload
    uploads_count INT NOT NULL DEFAULT 0,
    uploads_size BIGINT NOT NULL DEFAULT 0,
    downloads_count INT NOT NULL DEFAULT 0,
    downloads_size BIGINT NOT NULL DEFAULT 0,
    
    -- Transformations et optimisations
    transformations_count INT NOT NULL DEFAULT 0,
    compression_savings BIGINT NOT NULL DEFAULT 0 COMMENT 'Espace économisé par compression',
    
    -- Métriques de performance
    avg_upload_time DECIMAL(5,2) NULL COMMENT 'Temps moyen upload en secondes',
    avg_download_time DECIMAL(5,2) NULL COMMENT 'Temps moyen download en secondes',
    
    -- Alertes déclenchées
    alerts_triggered JSON NULL COMMENT 'Alertes déclenchées ce jour',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_date (date),
    INDEX idx_usage (storage_used, bandwidth_used)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour l'historique des nettoyages automatiques
CREATE TABLE IF NOT EXISTS cloudinary_cleanup_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Informations sur l'opération de nettoyage
    cleanup_type ENUM('scheduled', 'manual', 'emergency') NOT NULL,
    cleanup_rule VARCHAR(100) NOT NULL COMMENT 'Règle appliquée (ex: expired_trips, unclaimed_packages)',
    
    -- Statistiques du nettoyage
    images_processed INT NOT NULL DEFAULT 0,
    images_deleted INT NOT NULL DEFAULT 0,
    images_failed INT NOT NULL DEFAULT 0,
    
    -- Espace libéré
    space_freed BIGINT NOT NULL DEFAULT 0 COMMENT 'Espace libéré en bytes',
    
    -- Détails de l'opération
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    duration_seconds INT GENERATED ALWAYS AS (TIMESTAMPDIFF(SECOND, start_time, end_time)) STORED,
    
    -- Résultats et erreurs
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT NULL,
    deleted_images JSON NULL COMMENT 'Liste des images supprimées avec détails',
    failed_images JSON NULL COMMENT 'Liste des images en échec avec erreurs',
    
    -- Conditions de déclenchement
    triggered_by ENUM('cron', 'admin', 'quota_alert', 'user_request') NOT NULL,
    trigger_details JSON NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_cleanup_type (cleanup_type),
    INDEX idx_date (created_at),
    INDEX idx_rule (cleanup_rule)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour les alertes de quota et notifications
CREATE TABLE IF NOT EXISTS cloudinary_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Type d'alerte
    alert_type ENUM('storage_warning', 'bandwidth_warning', 'storage_critical', 'bandwidth_critical', 'quota_exceeded', 'cleanup_failed') NOT NULL,
    alert_level ENUM('info', 'warning', 'critical', 'emergency') NOT NULL,
    
    -- Métriques au moment de l'alerte
    current_storage_usage BIGINT NOT NULL,
    current_bandwidth_usage BIGINT NOT NULL,
    storage_percentage DECIMAL(5,2) GENERATED ALWAYS AS ((current_storage_usage / 26843545600) * 100) STORED,
    bandwidth_percentage DECIMAL(5,2) GENERATED ALWAYS AS ((current_bandwidth_usage / 26843545600) * 100) STORED,
    
    -- Message et détails
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    details JSON NULL,
    
    -- Actions recommandées
    recommended_actions JSON NULL,
    
    -- Gestion des notifications
    notification_sent BOOLEAN NOT NULL DEFAULT FALSE,
    notification_channels JSON NULL COMMENT 'Canaux utilisés (email, push, sms)',
    
    -- Résolution
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at TIMESTAMP NULL,
    resolution_notes TEXT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_alert_type (alert_type, alert_level),
    INDEX idx_resolved (is_resolved, created_at),
    INDEX idx_notification (notification_sent)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour la configuration des règles de nettoyage
CREATE TABLE IF NOT EXISTS cloudinary_cleanup_rules (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Identification de la règle
    rule_name VARCHAR(100) NOT NULL UNIQUE,
    rule_description TEXT NOT NULL,
    
    -- Configuration de la règle
    image_type ENUM('avatar', 'kyc_document', 'trip_photo', 'package_photo', 'delivery_proof') NULL,
    conditions JSON NOT NULL COMMENT 'Conditions SQL pour sélectionner les images à nettoyer',
    
    -- Paramètres temporels
    retention_days INT NULL COMMENT 'Nombre de jours de rétention',
    
    -- Activation et scheduling
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    run_frequency ENUM('daily', 'weekly', 'monthly') NOT NULL DEFAULT 'daily',
    next_run_at DATETIME NULL,
    last_run_at DATETIME NULL,
    
    -- Statistiques
    total_runs INT NOT NULL DEFAULT 0,
    total_images_deleted INT NOT NULL DEFAULT 0,
    total_space_freed BIGINT NOT NULL DEFAULT 0,
    
    -- Contraintes de sécurité
    max_images_per_run INT NOT NULL DEFAULT 1000 COMMENT 'Limite sécuritaire par exécution',
    requires_confirmation BOOLEAN NOT NULL DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_active_rules (is_active, next_run_at),
    INDEX idx_image_type (image_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion des règles de nettoyage par défaut
INSERT INTO cloudinary_cleanup_rules (rule_name, rule_description, image_type, conditions, retention_days, run_frequency) VALUES
(
    'unclaimed_packages',
    'Supprime les photos de colis non réclamés après 7 jours',
    'package_photo',
    '{"where": "related_entity_type = \\"package\\" AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY) AND related_entity_id NOT IN (SELECT id FROM packages WHERE status IN (\\"claimed\\", \\"delivered\\"))"}',
    7,
    'daily'
),
(
    'expired_trips',
    'Supprime les photos d\'annonces de voyages expirés après 30 jours',
    'trip_photo',
    '{"where": "related_entity_type = \\"trip\\" AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY) AND related_entity_id IN (SELECT id FROM trips WHERE departure_date < DATE_SUB(NOW(), INTERVAL 30 DAY))"}',
    30,
    'weekly'
),
(
    'rejected_kyc',
    'Supprime les documents KYC rejetés après 60 jours',
    'kyc_document',
    '{"where": "image_type = \\"kyc_document\\" AND created_at < DATE_SUB(NOW(), INTERVAL 60 DAY) AND user_id IN (SELECT user_id FROM kyc_verifications WHERE status = \\"rejected\\" AND updated_at < DATE_SUB(NOW(), INTERVAL 60 DAY))"}',
    60,
    'weekly'
),
(
    'inactive_user_avatars',
    'Compresse davantage les avatars d\'utilisateurs inactifs après 90 jours',
    'avatar',
    '{"where": "image_type = \\"avatar\\" AND compression_quality > 60 AND user_id IN (SELECT id FROM users WHERE last_login_at < DATE_SUB(NOW(), INTERVAL 90 DAY))"}',
    90,
    'monthly'
);

-- Vues pour faciliter les requêtes communes
CREATE OR REPLACE VIEW v_cloudinary_usage_summary AS
SELECT 
    DATE(created_at) as date,
    image_type,
    COUNT(*) as image_count,
    SUM(file_size) as total_size,
    AVG(file_size) as avg_size,
    SUM(download_count) as total_downloads
FROM image_uploads 
WHERE deleted_at IS NULL
GROUP BY DATE(created_at), image_type;

CREATE OR REPLACE VIEW v_cloudinary_current_usage AS
SELECT 
    image_type,
    COUNT(*) as image_count,
    SUM(file_size) as total_size,
    AVG(compression_quality) as avg_compression,
    COUNT(CASE WHEN is_temporary = 1 THEN 1 END) as temporary_count,
    COUNT(CASE WHEN expires_at IS NOT NULL AND expires_at < NOW() THEN 1 END) as expired_count
FROM image_uploads 
WHERE deleted_at IS NULL
GROUP BY image_type;

-- Triggers pour maintenir les statistiques automatiquement
DELIMITER $$

CREATE TRIGGER tr_image_uploads_after_insert
AFTER INSERT ON image_uploads
FOR EACH ROW
BEGIN
    INSERT INTO cloudinary_usage_stats (date, uploads_count, uploads_size)
    VALUES (CURDATE(), 1, NEW.file_size)
    ON DUPLICATE KEY UPDATE
        uploads_count = uploads_count + 1,
        uploads_size = uploads_size + NEW.file_size;
        
    -- Mise à jour des compteurs spécifiques par type
    CASE NEW.image_type
        WHEN 'avatar' THEN
            UPDATE cloudinary_usage_stats 
            SET avatars_count = avatars_count + 1, avatars_size = avatars_size + NEW.file_size 
            WHERE date = CURDATE();
        WHEN 'kyc_document' THEN
            UPDATE cloudinary_usage_stats 
            SET kyc_documents_count = kyc_documents_count + 1, kyc_documents_size = kyc_documents_size + NEW.file_size 
            WHERE date = CURDATE();
        WHEN 'trip_photo' THEN
            UPDATE cloudinary_usage_stats 
            SET trip_photos_count = trip_photos_count + 1, trip_photos_size = trip_photos_size + NEW.file_size 
            WHERE date = CURDATE();
        WHEN 'package_photo' THEN
            UPDATE cloudinary_usage_stats 
            SET package_photos_count = package_photos_count + 1, package_photos_size = package_photos_size + NEW.file_size 
            WHERE date = CURDATE();
        WHEN 'delivery_proof' THEN
            UPDATE cloudinary_usage_stats 
            SET delivery_proofs_count = delivery_proofs_count + 1, delivery_proofs_size = delivery_proofs_size + NEW.file_size 
            WHERE date = CURDATE();
    END CASE;
END$$

CREATE TRIGGER tr_image_uploads_after_update
AFTER UPDATE ON image_uploads
FOR EACH ROW
BEGIN
    -- Incrémenter le compteur de téléchargements si download_count a augmenté
    IF NEW.download_count > OLD.download_count THEN
        INSERT INTO cloudinary_usage_stats (date, downloads_count, downloads_size)
        VALUES (CURDATE(), NEW.download_count - OLD.download_count, NEW.file_size * (NEW.download_count - OLD.download_count))
        ON DUPLICATE KEY UPDATE
            downloads_count = downloads_count + (NEW.download_count - OLD.download_count),
            downloads_size = downloads_size + (NEW.file_size * (NEW.download_count - OLD.download_count));
    END IF;
    
    -- Mettre à jour last_accessed_at
    IF NEW.download_count > OLD.download_count OR NEW.last_accessed_at != OLD.last_accessed_at THEN
        UPDATE image_uploads SET last_accessed_at = NOW() WHERE id = NEW.id;
    END IF;
END$$

DELIMITER ;

-- Procédure stockée pour vérifier les quotas et déclencher des alertes
DELIMITER $$

CREATE PROCEDURE CheckCloudinaryQuotas()
BEGIN
    DECLARE storage_used BIGINT DEFAULT 0;
    DECLARE bandwidth_used BIGINT DEFAULT 0;
    DECLARE storage_percentage DECIMAL(5,2) DEFAULT 0;
    DECLARE bandwidth_percentage DECIMAL(5,2) DEFAULT 0;
    
    -- Calculer l'usage actuel du stockage
    SELECT COALESCE(SUM(file_size), 0) INTO storage_used 
    FROM image_uploads 
    WHERE deleted_at IS NULL;
    
    -- Calculer l'usage actuel de la bande passante (approximation basée sur les downloads)
    SELECT COALESCE(SUM(file_size * download_count), 0) INTO bandwidth_used 
    FROM image_uploads 
    WHERE deleted_at IS NULL 
    AND MONTH(last_accessed_at) = MONTH(NOW()) 
    AND YEAR(last_accessed_at) = YEAR(NOW());
    
    -- Calculer les pourcentages
    SET storage_percentage = (storage_used / 26843545600) * 100;
    SET bandwidth_percentage = (bandwidth_used / 26843545600) * 100;
    
    -- Déclencher des alertes selon les seuils
    IF storage_percentage >= 95 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message, recommended_actions)
        VALUES ('storage_critical', 'emergency', storage_used, bandwidth_used, 
                'Quota de stockage critique (95%+)', 
                CONCAT('Le stockage Cloudinary a atteint ', ROUND(storage_percentage, 2), '% de la limite.'),
                '["Activer le nettoyage d\'urgence", "Supprimer les images temporaires", "Augmenter la compression"]');
                
    ELSEIF storage_percentage >= 85 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message, recommended_actions)
        VALUES ('storage_warning', 'critical', storage_used, bandwidth_used,
                'Quota de stockage élevé (85%+)', 
                CONCAT('Le stockage Cloudinary a atteint ', ROUND(storage_percentage, 2), '% de la limite.'),
                '["Programmer le nettoyage", "Réviser les règles de rétention"]');
                
    ELSEIF storage_percentage >= 70 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message)
        VALUES ('storage_warning', 'warning', storage_used, bandwidth_used,
                'Quota de stockage modéré (70%+)', 
                CONCAT('Le stockage Cloudinary a atteint ', ROUND(storage_percentage, 2), '% de la limite.'));
    END IF;
    
    -- Alertes similaires pour la bande passante
    IF bandwidth_percentage >= 95 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message, recommended_actions)
        VALUES ('bandwidth_critical', 'emergency', storage_used, bandwidth_used,
                'Quota de bande passante critique (95%+)', 
                CONCAT('La bande passante Cloudinary a atteint ', ROUND(bandwidth_percentage, 2), '% de la limite mensuelle.'),
                '["Réduire la qualité des images", "Implémenter plus de cache", "Optimiser les transformations"]');
    END IF;
    
    -- Mettre à jour les statistiques du jour
    INSERT INTO cloudinary_usage_stats (date, storage_used, bandwidth_used)
    VALUES (CURDATE(), storage_used, bandwidth_used)
    ON DUPLICATE KEY UPDATE
        storage_used = VALUES(storage_used),
        bandwidth_used = VALUES(bandwidth_used),
        updated_at = NOW();
        
END$$

DELIMITER ;

-- Événement pour vérifier les quotas automatiquement chaque heure
CREATE EVENT IF NOT EXISTS ev_check_cloudinary_quotas
ON SCHEDULE EVERY 1 HOUR
STARTS NOW()
DO CALL CheckCloudinaryQuotas();

-- Activer l'événement scheduler si ce n'est pas déjà fait
SET GLOBAL event_scheduler = ON;