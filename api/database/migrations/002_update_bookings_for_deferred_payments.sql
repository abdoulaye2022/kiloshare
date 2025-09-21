-- Migration pour mettre à jour la table bookings
-- Ajout des nouveaux statuts et champs pour la capture différée

-- Ajouter les nouveaux statuts pour les réservations
ALTER TABLE bookings MODIFY COLUMN status ENUM(
    'pending',                    -- En attente d'acceptation
    'accepted',                   -- Acceptée, en attente de paiement
    'payment_authorized',         -- Paiement autorisé, en attente de confirmation
    'payment_confirmed',          -- Paiement confirmé, en attente de capture
    'paid',                       -- Paiement capturé avec succès
    'in_transit',                 -- En cours de transport
    'delivered',                  -- Livré (avec code de livraison)
    'completed',                  -- Terminé et validé
    'cancelled',                  -- Annulé
    'payment_failed',             -- Échec de paiement
    'payment_expired',            -- Paiement expiré
    'payment_cancelled',          -- Paiement annulé
    'refunded'                    -- Remboursé
) NOT NULL DEFAULT 'pending';

-- Ajouter une colonne pour lier à l'autorisation de paiement
ALTER TABLE bookings
ADD COLUMN payment_authorization_id BIGINT UNSIGNED NULL AFTER final_price,
ADD INDEX idx_payment_authorization (payment_authorization_id);

-- Ajouter une contrainte de clé étrangère
ALTER TABLE bookings
ADD CONSTRAINT fk_booking_payment_authorization
FOREIGN KEY (payment_authorization_id) REFERENCES payment_authorizations(id)
ON DELETE SET NULL;

-- Ajouter des timestamps pour le suivi du workflow
ALTER TABLE bookings
ADD COLUMN payment_authorized_at TIMESTAMP NULL AFTER payment_authorization_id,
ADD COLUMN payment_confirmed_at TIMESTAMP NULL AFTER payment_authorized_at,
ADD COLUMN payment_captured_at TIMESTAMP NULL AFTER payment_confirmed_at;

-- Index pour les requêtes de statut
CREATE INDEX idx_booking_status_timestamps ON bookings(status, payment_confirmed_at, payment_captured_at);