-- Migration pour créer la table scheduled_jobs
-- Pour gérer les tâches programmées de capture automatique et d'expiration

CREATE TABLE IF NOT EXISTS scheduled_jobs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    type ENUM(
        'auto_capture',          -- Capture automatique de paiement
        'payment_expiry',        -- Expiration d'autorisation de paiement
        'confirmation_reminder', -- Rappel de confirmation
        'payment_reminder'       -- Rappel de paiement
    ) NOT NULL,

    -- Référence à l'objet concerné
    payment_authorization_id BIGINT UNSIGNED NULL,
    booking_id INT NULL,

    -- Planification
    scheduled_at TIMESTAMP NOT NULL,         -- Quand exécuter le job
    executed_at TIMESTAMP NULL,              -- Quand le job a été exécuté

    -- Statut du job
    status ENUM(
        'pending',               -- En attente d'exécution
        'running',               -- En cours d'exécution
        'completed',             -- Exécuté avec succès
        'failed',                -- Échec d'exécution
        'cancelled'              -- Annulé
    ) NOT NULL DEFAULT 'pending',

    -- Métadonnées
    priority INT NOT NULL DEFAULT 5,        -- Priorité (1=haute, 10=basse)
    attempts INT NOT NULL DEFAULT 0,        -- Nombre de tentatives
    max_attempts INT NOT NULL DEFAULT 3,    -- Nombre maximum de tentatives

    -- Données du job et résultat
    job_data JSON NULL,                     -- Données nécessaires pour le job
    result JSON NULL,                       -- Résultat de l'exécution
    error_message TEXT NULL,                -- Message d'erreur si échec

    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Index
    INDEX idx_type (type),
    INDEX idx_status (status),
    INDEX idx_scheduled_at (scheduled_at),
    INDEX idx_payment_authorization (payment_authorization_id),
    INDEX idx_booking_id (booking_id),

    -- Contraintes
    FOREIGN KEY (payment_authorization_id) REFERENCES payment_authorizations(id) ON DELETE CASCADE,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

-- Index composés pour les requêtes de traitement
CREATE INDEX idx_job_queue ON scheduled_jobs(status, scheduled_at, priority);
CREATE INDEX idx_job_cleanup ON scheduled_jobs(status, created_at);