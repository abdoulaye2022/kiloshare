-- Migration pour créer la table payment_configuration
-- Pour stocker les paramètres configurables du système de paiement

CREATE TABLE IF NOT EXISTS payment_configuration (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Clé de configuration
    config_key VARCHAR(100) NOT NULL UNIQUE,

    -- Valeur de configuration
    config_value TEXT NOT NULL,

    -- Type de valeur (pour validation)
    value_type ENUM('string', 'integer', 'boolean', 'json', 'float') NOT NULL DEFAULT 'string',

    -- Description
    description TEXT NULL,

    -- Catégorie pour organisation
    category ENUM(
        'authorization',    -- Paramètres d'autorisation
        'capture',         -- Paramètres de capture
        'expiry',          -- Paramètres d'expiration
        'notifications',   -- Paramètres de notifications
        'fees',           -- Paramètres de frais
        'refunds'         -- Paramètres de remboursement
    ) NOT NULL DEFAULT 'authorization',

    -- Métadonnées
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    requires_restart BOOLEAN NOT NULL DEFAULT FALSE,  -- Si le changement nécessite un redémarrage

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Index
    INDEX idx_category (category),
    INDEX idx_active (is_active)
);

-- Insérer les configurations par défaut
INSERT INTO payment_configuration (config_key, config_value, value_type, description, category) VALUES
-- Délais de confirmation
('confirmation_deadline_hours', '4', 'integer', 'Délai en heures pour confirmer un paiement autorisé', 'authorization'),
('auto_capture_hours_before_trip', '72', 'integer', 'Heures avant le départ pour capture automatique', 'capture'),

-- Gestion des tentatives
('max_capture_attempts', '3', 'integer', 'Nombre maximum de tentatives de capture', 'capture'),
('retry_delay_minutes', '30', 'integer', 'Délai en minutes entre les tentatives de capture', 'capture'),

-- Frais de plateforme
('platform_fee_percentage', '5.0', 'float', 'Pourcentage de frais de plateforme', 'fees'),
('minimum_platform_fee_cents', '50', 'integer', 'Frais minimum de plateforme en centimes', 'fees'),

-- Notifications
('send_confirmation_reminders', 'true', 'boolean', 'Envoyer des rappels de confirmation', 'notifications'),
('reminder_hours_before_expiry', '2', 'integer', 'Heures avant expiration pour envoyer un rappel', 'notifications'),

-- Refunds
('auto_refund_on_cancellation', 'true', 'boolean', 'Remboursement automatique en cas d\'annulation', 'refunds'),
('refund_processing_fee_cents', '30', 'integer', 'Frais de traitement pour les remboursements en centimes', 'refunds'),

-- Capture automatique
('enable_auto_capture', 'true', 'boolean', 'Activer la capture automatique', 'capture'),
('capture_on_pickup_confirmation', 'true', 'boolean', 'Capturer lors de la confirmation de récupération', 'capture'),

-- Sécurité
('require_3ds_for_large_amounts', 'true', 'boolean', 'Exiger 3D Secure pour les gros montants', 'authorization'),
('large_amount_threshold_cents', '50000', 'integer', 'Seuil en centimes pour considérer un montant comme important', 'authorization');