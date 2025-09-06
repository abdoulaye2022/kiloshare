-- Script de nettoyage des tables inutilisées de la base kiloshare
-- Créé le: 2025-09-06
-- ATTENTION: Ce script supprime définitivement les tables listées
-- Faire un backup avant d'exécuter si nécessaire

USE kiloshare;

-- Vérification des tables existantes avant suppression
SELECT 'Tables à supprimer:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'kiloshare' 
AND table_name IN (
    'active_trips_overview',
    'booking_summary', 
    'login_attempts',
    'message_moderation_logs',
    'message_quick_actions',
    'message_rate_limits',
    'notification_events',
    'notification_queue',
    'notification_stats_by_channel',
    'social_auth_attempts',
    'trip_status_summary',
    'user_rating_summary',
    'user_unread_notifications',
    'users_with_stripe_status'
);

-- Suppression des tables inutilisées
DROP TABLE IF EXISTS active_trips_overview;
DROP TABLE IF EXISTS booking_summary;
DROP TABLE IF EXISTS login_attempts;
DROP TABLE IF EXISTS message_moderation_logs;
DROP TABLE IF EXISTS message_quick_actions;
DROP TABLE IF EXISTS message_rate_limits;
DROP TABLE IF EXISTS notification_events;
DROP TABLE IF EXISTS notification_queue;
DROP TABLE IF EXISTS notification_stats_by_channel;
DROP TABLE IF EXISTS social_auth_attempts;
DROP TABLE IF EXISTS trip_status_summary;
DROP TABLE IF EXISTS user_rating_summary;
DROP TABLE IF EXISTS user_unread_notifications;
DROP TABLE IF EXISTS users_with_stripe_status;

-- Vérification finale
SELECT 'Nettoyage terminé' as result;
SELECT COUNT(*) as tables_restantes FROM information_schema.tables WHERE table_schema = 'kiloshare';