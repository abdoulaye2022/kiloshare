-- Migration pour ajouter les champs de profil manquants à la table users
-- Date: 2025-09-01

-- Nettoyer d'abord les colonnes phone dupliquées (garder phone, supprimer phone_number)
-- Vérifier si la colonne existe avant de la supprimer
SET @sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_SCHEMA = DATABASE() 
               AND TABLE_NAME = 'users' 
               AND COLUMN_NAME = 'phone_number') > 0,
              'ALTER TABLE users DROP COLUMN phone_number',
              'SELECT "Column phone_number does not exist"');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Ajouter les champs de profil manquants
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS gender ENUM('male', 'female', 'other') NULL AFTER last_name,
ADD COLUMN IF NOT EXISTS date_of_birth DATE NULL AFTER gender,
ADD COLUMN IF NOT EXISTS nationality VARCHAR(100) NULL AFTER date_of_birth,
ADD COLUMN IF NOT EXISTS bio TEXT NULL AFTER nationality,
ADD COLUMN IF NOT EXISTS website VARCHAR(255) NULL AFTER bio,
ADD COLUMN IF NOT EXISTS profession VARCHAR(150) NULL AFTER website,
ADD COLUMN IF NOT EXISTS company VARCHAR(150) NULL AFTER profession,
ADD COLUMN IF NOT EXISTS address_line1 VARCHAR(255) NULL AFTER company,
ADD COLUMN IF NOT EXISTS address_line2 VARCHAR(255) NULL AFTER address_line1,
ADD COLUMN IF NOT EXISTS city VARCHAR(100) NULL AFTER address_line2,
ADD COLUMN IF NOT EXISTS state_province VARCHAR(100) NULL AFTER city,
ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20) NULL AFTER state_province,
ADD COLUMN IF NOT EXISTS country VARCHAR(100) NULL AFTER postal_code,
ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'fr' AFTER country,
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'Europe/Paris' AFTER preferred_language,
ADD COLUMN IF NOT EXISTS emergency_contact_name VARCHAR(200) NULL AFTER timezone,
ADD COLUMN IF NOT EXISTS emergency_contact_phone VARCHAR(20) NULL AFTER emergency_contact_name,
ADD COLUMN IF NOT EXISTS emergency_contact_relation VARCHAR(50) NULL AFTER emergency_contact_phone,
ADD COLUMN IF NOT EXISTS login_method ENUM('email', 'phone', 'social') DEFAULT 'email' AFTER emergency_contact_relation,
ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN DEFAULT FALSE AFTER login_method,
ADD COLUMN IF NOT EXISTS newsletter_subscribed BOOLEAN DEFAULT TRUE AFTER two_factor_enabled,
ADD COLUMN IF NOT EXISTS marketing_emails BOOLEAN DEFAULT FALSE AFTER newsletter_subscribed,
ADD COLUMN IF NOT EXISTS profile_visibility ENUM('public', 'private', 'friends_only') DEFAULT 'public' AFTER marketing_emails;

-- Ajouter des index pour les recherches fréquentes
CREATE INDEX IF NOT EXISTS idx_users_login_method ON users(login_method);
CREATE INDEX IF NOT EXISTS idx_users_country ON users(country);
CREATE INDEX IF NOT EXISTS idx_users_city ON users(city);
CREATE INDEX IF NOT EXISTS idx_users_profile_visibility ON users(profile_visibility);

-- Mettre à jour les utilisateurs existants qui se connectent avec le téléphone
UPDATE users 
SET login_method = 'phone' 
WHERE phone IS NOT NULL 
  AND (email IS NULL OR email = '' OR email LIKE '%@temp.%');

-- Mettre à jour les utilisateurs avec des providers sociaux
UPDATE users 
SET login_method = 'social' 
WHERE social_provider IS NOT NULL;

-- S'assurer que les utilisateurs avec email ont la bonne méthode de connexion
UPDATE users 
SET login_method = 'email' 
WHERE login_method IS NULL 
  AND email IS NOT NULL 
  AND email != '' 
  AND email NOT LIKE '%@temp.%';