-- Script pour nettoyer toutes les données utilisateur
-- Garde seulement les données par défaut et de configuration

-- Désactiver les contraintes de clés étrangères temporairement
SET FOREIGN_KEY_CHECKS = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';

-- Tables de données utilisateur (dans l'ordre des dépendances)
DELETE FROM user_trip_favorites;
DELETE FROM user_tokens;
DELETE FROM user_social_accounts;  
DELETE FROM user_stripe_accounts;
DELETE FROM user_profiles;

-- Tables d'authentification et vérification
DELETE FROM email_verifications;
DELETE FROM phone_verifications;
DELETE FROM password_resets;
DELETE FROM verification_codes;
DELETE FROM verification_documents;
DELETE FROM verification_logs;
DELETE FROM login_attempts;
DELETE FROM social_auth_attempts;

-- Tables de réservations (ordre important)
DELETE FROM booking_package_photos;
DELETE FROM booking_notifications;
DELETE FROM booking_negotiations;
DELETE FROM booking_contracts;
-- booking_summary est une vue, pas une table
DELETE FROM bookings;

-- Tables de voyages
DELETE FROM trip_action_logs;
DELETE FROM trip_views;
DELETE FROM trip_reports;
DELETE FROM trip_favorites;
DELETE FROM trip_images;
DELETE FROM trip_drafts;
DELETE FROM trips;

-- Tables de recherche et historique
DELETE FROM search_history;
DELETE FROM search_alerts;

-- Tables financières
DELETE FROM transactions;
DELETE FROM escrow_accounts;
DELETE FROM stripe_account_creation_log;

-- Tables de confiance et évaluations
DELETE FROM trust_badges;

-- Tables de monitoring et logs Cloudinary
DELETE FROM cloudinary_alerts;
DELETE FROM cloudinary_cleanup_log;
DELETE FROM cloudinary_usage_stats;
DELETE FROM image_uploads;

-- Tables d'administration
DELETE FROM admin_actions;

-- Enfin, supprimer les utilisateurs
DELETE FROM users;

-- TABLES À CONSERVER (ne pas vider) :
-- - city_suggestions (données par défaut des villes)
-- - popular_routes (routes populaires par défaut) 
-- - trip_restrictions (règles métier)
-- - cloudinary_cleanup_rules (règles de configuration)
-- - active_trips_overview (vue)
-- - trip_status_summary (vue)
-- - users_with_stripe_status (vue)  
-- - v_cloudinary_current_usage (vue)
-- - v_cloudinary_usage_summary (vue)

-- Réactiver les contraintes
SET FOREIGN_KEY_CHECKS = 1;

-- Réinitialiser les AUTO_INCREMENT
ALTER TABLE users AUTO_INCREMENT = 1;
ALTER TABLE user_profiles AUTO_INCREMENT = 1;
ALTER TABLE trips AUTO_INCREMENT = 1;
ALTER TABLE bookings AUTO_INCREMENT = 1;
ALTER TABLE transactions AUTO_INCREMENT = 1;
ALTER TABLE trip_images AUTO_INCREMENT = 1;
ALTER TABLE image_uploads AUTO_INCREMENT = 1;
ALTER TABLE admin_actions AUTO_INCREMENT = 1;

SELECT 'Base de données nettoyée avec succès! Toutes les données utilisateur ont été supprimées.' as status;