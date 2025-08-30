-- KiloShare Authentication Module Tables
-- Database: kiloshare

USE `kiloshare`;

-- Users table for authentication
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `uuid` VARCHAR(36) UNIQUE NOT NULL,
    `email` VARCHAR(255) UNIQUE NOT NULL,
    `phone` VARCHAR(20) UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `first_name` VARCHAR(100),
    `last_name` VARCHAR(100),
    `is_verified` BOOLEAN DEFAULT FALSE,
    `email_verified_at` TIMESTAMP NULL,
    `phone_verified_at` TIMESTAMP NULL,
    `profile_picture` VARCHAR(500),
    `status` ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    `last_login_at` TIMESTAMP NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_email` (`email`),
    INDEX `idx_phone` (`phone`),
    INDEX `idx_uuid` (`uuid`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- User tokens for JWT refresh and other purposes
CREATE TABLE IF NOT EXISTS `user_tokens` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `token` VARCHAR(500) NOT NULL,
    `type` ENUM('refresh', 'access', 'password_reset') NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `is_revoked` BOOLEAN DEFAULT FALSE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    INDEX `idx_user_id` (`user_id`),
    INDEX `idx_token` (`token`),
    INDEX `idx_type` (`type`),
    INDEX `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Verification codes for phone/email verification
CREATE TABLE IF NOT EXISTS `verification_codes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL,
    `code` VARCHAR(10) NOT NULL,
    `type` ENUM('phone_verification', 'email_verification', 'password_reset') NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `is_used` BOOLEAN DEFAULT FALSE,
    `attempts` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE,
    INDEX `idx_user_id` (`user_id`),
    INDEX `idx_code` (`code`),
    INDEX `idx_type` (`type`),
    INDEX `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Password reset tokens
CREATE TABLE IF NOT EXISTS `password_resets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `email` VARCHAR(255) NOT NULL,
    `token` VARCHAR(255) NOT NULL,
    `expires_at` TIMESTAMP NOT NULL,
    `is_used` BOOLEAN DEFAULT FALSE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_email` (`email`),
    INDEX `idx_token` (`token`),
    INDEX `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Login attempts tracking (security)
CREATE TABLE IF NOT EXISTS `login_attempts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `email` VARCHAR(255),
    `ip_address` VARCHAR(45),
    `user_agent` TEXT,
    `success` BOOLEAN DEFAULT FALSE,
    `attempted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_email` (`email`),
    INDEX `idx_ip_address` (`ip_address`),
    INDEX `idx_attempted_at` (`attempted_at`)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;