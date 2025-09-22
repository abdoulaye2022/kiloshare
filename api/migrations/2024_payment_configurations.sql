-- Migration pour la table payment_configurations
-- Fichier: 2024_payment_configurations.sql

CREATE TABLE IF NOT EXISTS payment_configurations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    value_type ENUM('string', 'integer', 'float', 'boolean', 'json') DEFAULT 'string',
    category VARCHAR(50) DEFAULT 'authorization',
    description TEXT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_config_key (config_key),
    INDEX idx_category (category),
    INDEX idx_is_active (is_active)
);

-- Insérer les configurations par défaut
INSERT INTO payment_configurations (config_key, config_value, value_type, category, description) VALUES
('confirmation_deadline_hours', '4', 'integer', 'authorization', 'Délai de confirmation en heures'),
('auto_capture_hours_before_trip', '72', 'integer', 'authorization', 'Heures avant le départ pour capture automatique'),
('max_capture_attempts', '3', 'integer', 'authorization', 'Nombre maximum de tentatives de capture'),
('retry_delay_minutes', '30', 'integer', 'authorization', 'Délai entre les tentatives en minutes'),
('platform_fee_percentage', '5.0', 'float', 'fees', 'Pourcentage des frais de plateforme'),
('minimum_platform_fee_cents', '50', 'integer', 'fees', 'Frais minimum de plateforme en centimes'),
('send_confirmation_reminders', 'true', 'boolean', 'notifications', 'Envoyer des rappels de confirmation'),
('reminder_hours_before_expiry', '2', 'integer', 'notifications', 'Heures avant expiration pour envoyer un rappel'),
('auto_refund_on_cancellation', 'true', 'boolean', 'refunds', 'Remboursement automatique en cas d\'annulation'),
('refund_processing_fee_cents', '30', 'integer', 'refunds', 'Frais de traitement pour les remboursements en centimes'),
('enable_auto_capture', 'true', 'boolean', 'authorization', 'Activer la capture automatique'),
('capture_on_pickup_confirmation', 'true', 'boolean', 'authorization', 'Capturer lors de la confirmation de récupération'),
('require_3ds_for_large_amounts', 'true', 'boolean', 'security', 'Exiger 3D Secure pour les gros montants'),
('large_amount_threshold_cents', '50000', 'integer', 'security', 'Seuil en centimes pour considérer un montant comme important')
ON DUPLICATE KEY UPDATE
    config_value = VALUES(config_value),
    value_type = VALUES(value_type),
    category = VALUES(category),
    description = VALUES(description);