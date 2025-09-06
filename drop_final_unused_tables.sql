-- Script de suppression des dernières tables inutilisées
-- Créé le: 2025-09-06
-- Tables à supprimer: user_unread_notifications, users_with_stripe_status, notification_stats_by_channel

USE kiloshare;

-- Vérification des tables avant suppression
SELECT 'Tables à supprimer:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'kiloshare' 
AND table_name IN (
    'user_unread_notifications',
    'users_with_stripe_status',
    'notification_stats_by_channel'
);

-- Suppression des tables inutilisées
DROP TABLE IF EXISTS user_unread_notifications;
DROP TABLE IF EXISTS users_with_stripe_status;
DROP TABLE IF EXISTS notification_stats_by_channel;

-- Vérification finale
SELECT 'Suppression terminée' as result;
SELECT COUNT(*) as tables_finales FROM information_schema.tables WHERE table_schema = 'kiloshare';