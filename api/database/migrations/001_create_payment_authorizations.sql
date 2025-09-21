-- Migration pour créer la table payment_authorizations
-- Pour gérer les autorisations de paiement avec capture différée

CREATE TABLE IF NOT EXISTS payment_authorizations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    payment_intent_id VARCHAR(255) NOT NULL UNIQUE,
    stripe_account_id VARCHAR(255) NOT NULL,
    amount_cents INT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'CAD',
    platform_fee_cents INT NOT NULL DEFAULT 0,
    status ENUM(
        'pending',           -- En attente de confirmation par l'expéditeur
        'confirmed',         -- Confirmé par l'expéditeur, en attente de capture
        'captured',          -- Montant capturé avec succès
        'cancelled',         -- Annulé avant capture
        'expired',           -- Expiré (4h de confirmation ou délai de capture dépassé)
        'failed'             -- Échec de capture
    ) NOT NULL DEFAULT 'pending',

    -- Timestamps pour la gestion des délais
    confirmed_at TIMESTAMP NULL,           -- Quand l'expéditeur a confirmé
    expires_at TIMESTAMP NULL,             -- Quand l'autorisation expire
    captured_at TIMESTAMP NULL,            -- Quand le paiement a été capturé
    cancelled_at TIMESTAMP NULL,           -- Quand annulé

    -- Métadonnées
    confirmation_deadline TIMESTAMP NULL,   -- Délai pour confirmation (4h après création)
    auto_capture_at TIMESTAMP NULL,        -- Programmé pour capture automatique
    capture_reason ENUM('manual', 'auto_72h', 'auto_pickup', 'expired') NULL,

    -- Suivi des tentatives
    capture_attempts INT NOT NULL DEFAULT 0,
    last_capture_error TEXT NULL,

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Index
    INDEX idx_booking_id (booking_id),
    INDEX idx_payment_intent (payment_intent_id),
    INDEX idx_status (status),
    INDEX idx_expires_at (expires_at),
    INDEX idx_auto_capture_at (auto_capture_at),
    INDEX idx_confirmation_deadline (confirmation_deadline),

    -- Contraintes
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

-- Index composé pour les requêtes de jobs
CREATE INDEX idx_status_auto_capture ON payment_authorizations(status, auto_capture_at);
CREATE INDEX idx_status_expires ON payment_authorizations(status, expires_at);