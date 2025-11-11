-- Migration pour ajouter l'archivage spécifique par utilisateur
-- Chaque partie (sender/receiver) peut archiver indépendamment sa vue de la réservation

-- Ajouter colonnes d'archivage spécifiques
ALTER TABLE bookings
ADD COLUMN archived_by_sender TINYINT(1) DEFAULT 0 COMMENT 'Archivé par l\'expéditeur',
ADD COLUMN archived_by_sender_at TIMESTAMP NULL COMMENT 'Date d\'archivage par l\'expéditeur',
ADD COLUMN archived_by_receiver TINYINT(1) DEFAULT 0 COMMENT 'Archivé par le transporteur',
ADD COLUMN archived_by_receiver_at TIMESTAMP NULL COMMENT 'Date d\'archivage par le transporteur';

-- Créer des index pour améliorer les performances des requêtes filtrées
CREATE INDEX idx_bookings_archived_sender ON bookings(sender_id, archived_by_sender, status);
CREATE INDEX idx_bookings_archived_receiver ON bookings(receiver_id, archived_by_receiver, status);
