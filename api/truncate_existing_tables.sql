-- Script pour vider uniquement les tables existantes de la base de données kiloshare
-- ⚠️  ATTENTION: Cette action est IRRÉVERSIBLE ! Toutes les données seront perdues.

USE kiloshare;

-- Désactiver les vérifications de clés étrangères temporairement
SET FOREIGN_KEY_CHECKS = 0;

-- Vider les tables principales (ignorer les erreurs si elles n'existent pas)
SET @OLD_SQL_NOTES = @@SQL_NOTES, SQL_NOTES = 0;

-- Tables principales
TRUNCATE TABLE IF EXISTS booking_negotiations;
TRUNCATE TABLE IF EXISTS bookings;
TRUNCATE TABLE IF EXISTS email_verifications;
TRUNCATE TABLE IF EXISTS escrow_accounts;
TRUNCATE TABLE IF EXISTS login_attempts;
TRUNCATE TABLE IF EXISTS password_resets;
TRUNCATE TABLE IF EXISTS phone_verifications;
TRUNCATE TABLE IF EXISTS transactions;
TRUNCATE TABLE IF EXISTS trip_favorites;
TRUNCATE TABLE IF EXISTS trip_images;
TRUNCATE TABLE IF EXISTS trip_reports;
TRUNCATE TABLE IF EXISTS trips;
TRUNCATE TABLE IF EXISTS user_social_accounts;
TRUNCATE TABLE IF EXISTS user_stripe_accounts;
TRUNCATE TABLE IF EXISTS user_tokens;
TRUNCATE TABLE IF EXISTS verification_codes;

-- Vider la table users en dernier (après les relations)
TRUNCATE TABLE IF EXISTS users;

-- Restaurer les notes SQL
SET SQL_NOTES = @OLD_SQL_NOTES;

-- Réactiver les vérifications de clés étrangères
SET FOREIGN_KEY_CHECKS = 1;

-- Créer un utilisateur admin par défaut pour les tests
INSERT INTO users (uuid, email, password, first_name, last_name, role, status, email_verified_at, created_at, updated_at)
VALUES 
(
    'admin-uuid-12345',
    'admin@gmail.com',
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: admin123
    'Admin',
    'User',
    'admin',
    'active',
    NOW(),
    NOW(),
    NOW()
);

-- Afficher les tables et leur nombre d'enregistrements après nettoyage
SELECT 'Tables vidées avec succès ! Admin créé: admin@gmail.com / admin123' as status;
SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = 'kiloshare' ORDER BY table_name;