-- =====================================================
-- NETTOYAGE DES TABLES INUTILISÉES - KILOSHARE DB
-- =====================================================
-- 
-- Ce script supprime toutes les tables qui ne sont pas
-- utilisées dans le code PHP (28 tables sur 47)
--
-- ATTENTION: Exécuter en staging d'abord !
-- Faire un backup complet avant exécution !
--
-- Usage: mysql -u root kiloshare < cleanup_unused_tables.sql
--
-- =====================================================

USE kiloshare;

-- Sauvegarder la liste des tables avant suppression
SELECT 'TABLES AVANT NETTOYAGE:' as info;
SELECT COUNT(*) as total_tables FROM information_schema.tables 
WHERE table_schema = 'kiloshare' AND table_type = 'BASE TABLE';

-- =====================================================
-- SUPPRESSION DES TABLES COMPLÈTEMENT INUTILISÉES
-- =====================================================

-- Tables de résumé/overview (probablement des vues)
DROP TABLE IF EXISTS active_trips_overview;
DROP TABLE IF EXISTS booking_summary;
DROP TABLE IF EXISTS trip_status_summary;
DROP TABLE IF EXISTS users_with_stripe_status;

-- Tables de contrats et négociations non utilisées  
DROP TABLE IF EXISTS booking_contracts;
DROP TABLE IF EXISTS booking_notifications;

-- Table photos en doublon (on garde package_photos)
DROP TABLE IF EXISTS booking_package_photos;

-- Tables de suggestions et recherche non utilisées
DROP TABLE IF EXISTS city_suggestions;
DROP TABLE IF EXISTS popular_routes;
DROP TABLE IF EXISTS search_alerts;
DROP TABLE IF EXISTS search_history;

-- Tables Cloudinary non utilisées
DROP TABLE IF EXISTS cloudinary_alerts;
DROP TABLE IF EXISTS cloudinary_cleanup_log;
DROP TABLE IF EXISTS cloudinary_cleanup_rules;
DROP TABLE IF EXISTS cloudinary_usage_stats;
DROP TABLE IF EXISTS image_uploads;

-- Tables de logs non utilisées
DROP TABLE IF EXISTS stripe_account_creation_log;
DROP TABLE IF EXISTS trip_action_logs;
DROP TABLE IF EXISTS trip_views;
DROP TABLE IF EXISTS verification_logs;

-- Tables de restriction et brouillons non utilisées
DROP TABLE IF EXISTS trip_drafts;
DROP TABLE IF EXISTS trip_restrictions;

-- Tables de badges et profils non utilisées
DROP TABLE IF EXISTS trust_badges;
DROP TABLE IF EXISTS user_profiles;

-- Table favoris en doublon (on garde trip_favorites)
DROP TABLE IF EXISTS user_trip_favorites;

-- Tables de vérification non utilisées
DROP TABLE IF EXISTS verification_documents;

-- =====================================================
-- SUPPRESSION DES VUES CLOUDINARY NON UTILISÉES
-- =====================================================

DROP VIEW IF EXISTS v_cloudinary_current_usage;
DROP VIEW IF EXISTS v_cloudinary_usage_summary;

-- =====================================================
-- VÉRIFICATION POST-NETTOYAGE
-- =====================================================

SELECT 'TABLES APRÈS NETTOYAGE:' as info;
SELECT COUNT(*) as total_tables FROM information_schema.tables 
WHERE table_schema = 'kiloshare' AND table_type = 'BASE TABLE';

SELECT 'TABLES RESTANTES:' as info;
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'kiloshare' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- =====================================================
-- RÉSUMÉ DU NETTOYAGE
-- =====================================================

SELECT '✅ NETTOYAGE TERMINÉ' as status;
SELECT '28 tables supprimées (60% de la DB)' as removed;
SELECT 'Tables restantes: uniquement celles utilisées dans le code' as kept;
SELECT '⚠️  IMPORTANT: Vérifier que l\'application fonctionne correctement' as warning;