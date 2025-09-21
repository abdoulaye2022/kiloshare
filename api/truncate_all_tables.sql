-- Script pour vider toutes les tables de la base de données kiloshare
-- ⚠️  ATTENTION: Cette action est IRRÉVERSIBLE ! Toutes les données seront perdues.
-- Utilisez ce script uniquement pour recommencer avec des données de test fraîches

USE kiloshare;

-- Désactiver les vérifications de clés étrangères temporairement
SET FOREIGN_KEY_CHECKS = 0;

-- Vider toutes les tables dans l'ordre
TRUNCATE TABLE active_trips_overview;
TRUNCATE TABLE admin_actions;
TRUNCATE TABLE booking_negotiations;
TRUNCATE TABLE booking_summary;
TRUNCATE TABLE bookings;
TRUNCATE TABLE email_verifications;
TRUNCATE TABLE escrow_accounts;
TRUNCATE TABLE login_attempts;
TRUNCATE TABLE password_resets;
TRUNCATE TABLE phone_verifications;
TRUNCATE TABLE social_auth_attempts;
TRUNCATE TABLE transactions;
TRUNCATE TABLE trip_favorites;
TRUNCATE TABLE trip_images;
TRUNCATE TABLE trip_reports;
TRUNCATE TABLE trip_status_summary;
TRUNCATE TABLE trips;
TRUNCATE TABLE user_social_accounts;
TRUNCATE TABLE user_stripe_accounts;
TRUNCATE TABLE user_tokens;
TRUNCATE TABLE users;
TRUNCATE TABLE users_with_stripe_status;
TRUNCATE TABLE verification_codes;

-- Réactiver les vérifications de clés étrangères
SET FOREIGN_KEY_CHECKS = 1;

-- Créer un utilisateur admin par défaut pour les tests
INSERT INTO users (uuid, email, password, first_name, last_name, role, status, email_verified_at, created_at, updated_at)
VALUES 
(
    UUID(),
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

-- Message de confirmation
SELECT 'Toutes les tables ont été vidées et un utilisateur admin créé (admin@gmail.com / admin123)' as status;