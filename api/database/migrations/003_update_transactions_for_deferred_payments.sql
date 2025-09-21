-- Migration pour mettre à jour la table transactions
-- Ajout des nouveaux statuts pour la capture différée

-- Mettre à jour les statuts existants pour inclure les nouveaux statuts de capture différée
ALTER TABLE transactions MODIFY COLUMN status ENUM(
    'pending',                  -- En attente (existant)
    'processing',              -- En cours (existant)
    'succeeded',               -- Réussi (existant)
    'failed',                  -- Échoué (existant)
    'cancelled',               -- Annulé (existant)
    'refunded',                -- Remboursé (existant)
    'authorized',              -- Autorisé (nouveau)
    'confirmed',               -- Confirmé (nouveau)
    'captured',                -- Capturé (nouveau)
    'expired'                  -- Expiré (nouveau)
) NOT NULL DEFAULT 'pending';

-- Ajouter une référence à l'autorisation de paiement
ALTER TABLE transactions
ADD COLUMN payment_authorization_id BIGINT UNSIGNED NULL AFTER booking_id,
ADD INDEX idx_payment_authorization_trans (payment_authorization_id);

-- Ajouter des métadonnées pour la capture différée
ALTER TABLE transactions
ADD COLUMN authorized_at TIMESTAMP NULL AFTER created_at,
ADD COLUMN confirmed_at TIMESTAMP NULL AFTER authorized_at,
ADD COLUMN captured_at TIMESTAMP NULL AFTER confirmed_at,
ADD COLUMN expires_at TIMESTAMP NULL AFTER captured_at;

-- Ajouter une contrainte de clé étrangère
ALTER TABLE transactions
ADD CONSTRAINT fk_transaction_payment_authorization
FOREIGN KEY (payment_authorization_id) REFERENCES payment_authorizations(id)
ON DELETE SET NULL;

-- Index composés pour les requêtes de suivi
CREATE INDEX idx_transaction_status_type ON transactions(status, type);
CREATE INDEX idx_transaction_expires ON transactions(expires_at, status);