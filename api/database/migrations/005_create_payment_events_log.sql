-- Migration pour créer la table payment_events_log
-- Pour l'audit et le suivi détaillé des événements de paiement

CREATE TABLE IF NOT EXISTS payment_events_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    -- Références
    payment_authorization_id BIGINT UNSIGNED NULL,
    booking_id INT NOT NULL,
    user_id INT NULL,

    -- Type d'événement
    event_type ENUM(
        'authorization_created',     -- Autorisation créée
        'authorization_confirmed',   -- Autorisation confirmée par l'expéditeur
        'authorization_cancelled',   -- Autorisation annulée
        'authorization_expired',     -- Autorisation expirée
        'capture_scheduled',         -- Capture programmée
        'capture_attempted',         -- Tentative de capture
        'capture_succeeded',         -- Capture réussie
        'capture_failed',           -- Capture échouée
        'refund_initiated',         -- Remboursement initié
        'refund_completed',         -- Remboursement terminé
        'webhook_received',         -- Webhook Stripe reçu
        'notification_sent'         -- Notification envoyée
    ) NOT NULL,

    -- Détails de l'événement
    event_data JSON NULL,               -- Données détaillées de l'événement
    stripe_event_id VARCHAR(255) NULL,  -- ID de l'événement Stripe si applicable

    -- Contexte
    ip_address VARCHAR(45) NULL,        -- Adresse IP de l'utilisateur
    user_agent TEXT NULL,               -- User agent du navigateur

    -- Résultat
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT NULL,

    -- Métadonnées
    processing_time_ms INT NULL,        -- Temps de traitement en ms

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Index
    INDEX idx_payment_authorization (payment_authorization_id),
    INDEX idx_booking_id (booking_id),
    INDEX idx_user_id (user_id),
    INDEX idx_event_type (event_type),
    INDEX idx_stripe_event (stripe_event_id),
    INDEX idx_created_at (created_at),
    INDEX idx_success (success),

    -- Contraintes
    FOREIGN KEY (payment_authorization_id) REFERENCES payment_authorizations(id) ON DELETE SET NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Index composés pour les requêtes d'analyse
CREATE INDEX idx_event_analysis ON payment_events_log(event_type, success, created_at);
CREATE INDEX idx_authorization_timeline ON payment_events_log(payment_authorization_id, created_at);