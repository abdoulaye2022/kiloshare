-- Migration pour ajouter les champs de profil manquants à la table users
-- Date: 2025-09-01

-- Nettoyer d'abord la colonne phone_number dupliquée si elle existe
DROP PROCEDURE IF EXISTS AddUserProfileColumns;
DELIMITER $$
CREATE PROCEDURE AddUserProfileColumns()
BEGIN
    -- Supprimer phone_number si elle existe
    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
               WHERE TABLE_SCHEMA = DATABASE() 
               AND TABLE_NAME = 'users' 
               AND COLUMN_NAME = 'phone_number') THEN
        ALTER TABLE users DROP COLUMN phone_number;
    END IF;

    -- Ajouter gender si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'gender') THEN
        ALTER TABLE users ADD COLUMN gender ENUM('male', 'female', 'other') NULL AFTER last_name;
    END IF;

    -- Ajouter date_of_birth si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'date_of_birth') THEN
        ALTER TABLE users ADD COLUMN date_of_birth DATE NULL AFTER gender;
    END IF;

    -- Ajouter nationality si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'nationality') THEN
        ALTER TABLE users ADD COLUMN nationality VARCHAR(100) NULL AFTER date_of_birth;
    END IF;

    -- Ajouter bio si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'bio') THEN
        ALTER TABLE users ADD COLUMN bio TEXT NULL AFTER nationality;
    END IF;

    -- Ajouter website si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'website') THEN
        ALTER TABLE users ADD COLUMN website VARCHAR(255) NULL AFTER bio;
    END IF;

    -- Ajouter profession si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'profession') THEN
        ALTER TABLE users ADD COLUMN profession VARCHAR(150) NULL AFTER website;
    END IF;

    -- Ajouter company si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'company') THEN
        ALTER TABLE users ADD COLUMN company VARCHAR(150) NULL AFTER profession;
    END IF;

    -- Ajouter address_line1 si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'address_line1') THEN
        ALTER TABLE users ADD COLUMN address_line1 VARCHAR(255) NULL AFTER company;
    END IF;

    -- Ajouter address_line2 si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'address_line2') THEN
        ALTER TABLE users ADD COLUMN address_line2 VARCHAR(255) NULL AFTER address_line1;
    END IF;

    -- Ajouter city si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'city') THEN
        ALTER TABLE users ADD COLUMN city VARCHAR(100) NULL AFTER address_line2;
    END IF;

    -- Ajouter state_province si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'state_province') THEN
        ALTER TABLE users ADD COLUMN state_province VARCHAR(100) NULL AFTER city;
    END IF;

    -- Ajouter postal_code si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'postal_code') THEN
        ALTER TABLE users ADD COLUMN postal_code VARCHAR(20) NULL AFTER state_province;
    END IF;

    -- Ajouter country si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'country') THEN
        ALTER TABLE users ADD COLUMN country VARCHAR(100) NULL AFTER postal_code;
    END IF;

    -- Ajouter preferred_language si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'preferred_language') THEN
        ALTER TABLE users ADD COLUMN preferred_language VARCHAR(10) DEFAULT 'fr' AFTER country;
    END IF;

    -- Ajouter timezone si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'timezone') THEN
        ALTER TABLE users ADD COLUMN timezone VARCHAR(50) DEFAULT 'Europe/Paris' AFTER preferred_language;
    END IF;

    -- Ajouter emergency_contact_name si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'emergency_contact_name') THEN
        ALTER TABLE users ADD COLUMN emergency_contact_name VARCHAR(200) NULL AFTER timezone;
    END IF;

    -- Ajouter emergency_contact_phone si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'emergency_contact_phone') THEN
        ALTER TABLE users ADD COLUMN emergency_contact_phone VARCHAR(20) NULL AFTER emergency_contact_name;
    END IF;

    -- Ajouter emergency_contact_relation si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'emergency_contact_relation') THEN
        ALTER TABLE users ADD COLUMN emergency_contact_relation VARCHAR(50) NULL AFTER emergency_contact_phone;
    END IF;

    -- Ajouter login_method si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'login_method') THEN
        ALTER TABLE users ADD COLUMN login_method ENUM('email', 'phone', 'social') DEFAULT 'email' AFTER emergency_contact_relation;
    END IF;

    -- Ajouter two_factor_enabled si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'two_factor_enabled') THEN
        ALTER TABLE users ADD COLUMN two_factor_enabled BOOLEAN DEFAULT FALSE AFTER login_method;
    END IF;

    -- Ajouter newsletter_subscribed si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'newsletter_subscribed') THEN
        ALTER TABLE users ADD COLUMN newsletter_subscribed BOOLEAN DEFAULT TRUE AFTER two_factor_enabled;
    END IF;

    -- Ajouter marketing_emails si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'marketing_emails') THEN
        ALTER TABLE users ADD COLUMN marketing_emails BOOLEAN DEFAULT FALSE AFTER newsletter_subscribed;
    END IF;

    -- Ajouter profile_visibility si n'existe pas
    IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS 
                   WHERE TABLE_SCHEMA = DATABASE() 
                   AND TABLE_NAME = 'users' 
                   AND COLUMN_NAME = 'profile_visibility') THEN
        ALTER TABLE users ADD COLUMN profile_visibility ENUM('public', 'private', 'friends_only') DEFAULT 'public' AFTER marketing_emails;
    END IF;

END$$
DELIMITER ;

-- Exécuter la procédure
CALL AddUserProfileColumns();

-- Supprimer la procédure
DROP PROCEDURE AddUserProfileColumns;

-- Ajouter des index pour les recherches fréquentes (seulement s'ils n'existent pas)
CREATE INDEX idx_users_login_method ON users(login_method);
CREATE INDEX idx_users_country ON users(country);
CREATE INDEX idx_users_city ON users(city);
CREATE INDEX idx_users_profile_visibility ON users(profile_visibility);

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