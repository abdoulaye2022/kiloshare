-- =====================================================
-- KiloShare Database Schema
-- Generated: 2025-11-12
-- Purpose: Complete database structure for production
-- =====================================================
-- 
-- This schema includes:
-- - User management (users, user_tokens, user_fcm_tokens)
-- - Authentication (email_verifications, verification_codes)
-- - Stripe integration (user_stripe_accounts, payment_authorizations)
-- - Trips & Bookings (trips, bookings, trip_images)
-- - Delivery system (delivery_codes)
-- - Messaging (conversations, messages, conversation_participants)
-- - Notifications (notifications, notification_logs, user_notification_preferences)
-- - Reviews & Ratings (reviews, user_ratings, user_reliability_history)
-- - Transactions & Payments (transactions, payment_events_log)
-- - Admin (admin_actions)
-- - Misc (trip_favorites, trip_views, trip_shares, contact_revelations)
-- =====================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_actions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `admin_id` int NOT NULL,
  `action_type` varchar(50) NOT NULL,
  `target_type` varchar(50) NOT NULL,
  `target_id` varchar(100) NOT NULL,
  `details` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_id` (`admin_id`),
  KEY `idx_target` (`target_type`,`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bookings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT (uuid()),
  `trip_id` int NOT NULL,
  `sender_id` int NOT NULL,
  `receiver_id` int NOT NULL,
  `package_description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `weight_kg` decimal(5,2) NOT NULL,
  `total_price` decimal(8,2) NOT NULL,
  `dimensions_cm` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_authorization_id` bigint unsigned DEFAULT NULL,
  `payment_authorized_at` timestamp NULL DEFAULT NULL,
  `payment_confirmed_at` timestamp NULL DEFAULT NULL,
  `payment_captured_at` timestamp NULL DEFAULT NULL,
  `commission_rate` decimal(4,2) DEFAULT '15.00',
  `commission_amount` decimal(8,2) DEFAULT NULL,
  `status` enum('pending','accepted','rejected','payment_authorized','payment_confirmed','paid','in_transit','delivered','completed','cancelled','payment_failed','payment_expired','payment_cancelled','refunded') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `pickup_address` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `delivery_address` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `pickup_date` datetime DEFAULT NULL,
  `delivery_date` datetime DEFAULT NULL,
  `special_instructions` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `expires_at` timestamp NULL DEFAULT NULL,
  `payment_status` enum('pending','paid','refunded','failed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `rejection_reason` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Raison optionnelle fournie lors du rejet d''une réservation',
  `archived_by_sender` tinyint(1) DEFAULT '0' COMMENT 'Archivé par l''expéditeur',
  `archived_by_sender_at` timestamp NULL DEFAULT NULL COMMENT 'Date d''archivage par l''expéditeur',
  `archived_by_receiver` tinyint(1) DEFAULT '0' COMMENT 'Archivé par le transporteur',
  `archived_by_receiver_at` timestamp NULL DEFAULT NULL COMMENT 'Date d''archivage par le transporteur',
  `delivery_confirmed_at` timestamp NULL DEFAULT NULL,
  `delivery_confirmed_by` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_trip_bookings` (`trip_id`),
  KEY `idx_sender_bookings` (`sender_id`),
  KEY `idx_receiver_bookings` (`receiver_id`),
  KEY `idx_booking_status` (`status`),
  KEY `idx_booking_dates` (`pickup_date`,`delivery_date`),
  KEY `idx_bookings_created_at` (`created_at`),
  KEY `idx_bookings_rejection_reason` (`rejection_reason`(255)),
  KEY `idx_payment_authorization` (`payment_authorization_id`),
  KEY `idx_booking_status_timestamps` (`status`,`payment_confirmed_at`,`payment_captured_at`),
  KEY `idx_bookings_trip_status` (`trip_id`,`status`),
  KEY `idx_bookings_archived_sender` (`sender_id`,`archived_by_sender`,`status`),
  KEY `idx_bookings_archived_receiver` (`receiver_id`,`archived_by_receiver`,`status`),
  KEY `idx_delivery_confirmed_at` (`delivery_confirmed_at`),
  CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bookings_ibfk_3` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_booking_payment_authorization` FOREIGN KEY (`payment_authorization_id`) REFERENCES `payment_authorizations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table principale des réservations de transport de colis';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cancellation_attempts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `trip_id` int DEFAULT NULL,
  `booking_id` int DEFAULT NULL,
  `attempt_type` enum('trip_cancel','booking_cancel') NOT NULL,
  `is_allowed` tinyint(1) NOT NULL,
  `denial_reason` varchar(500) DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `trip_id` (`trip_id`),
  KEY `booking_id` (`booking_id`),
  KEY `idx_user_attempts` (`user_id`,`created_at`),
  CONSTRAINT `cancellation_attempts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `cancellation_attempts_ibfk_2` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE SET NULL,
  CONSTRAINT `cancellation_attempts_ibfk_3` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `contact_revelations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `conversation_id` bigint NOT NULL,
  `booking_id` bigint NOT NULL,
  `payment_id` bigint DEFAULT NULL,
  `revealed_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `revealed_by_system` tinyint(1) DEFAULT '1',
  `phone_revealed` tinyint(1) DEFAULT '0',
  `email_revealed` tinyint(1) DEFAULT '0',
  `full_name_revealed` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_conversation` (`conversation_id`),
  KEY `idx_booking` (`booking_id`),
  KEY `idx_payment` (`payment_id`),
  CONSTRAINT `contact_revelations_ibfk_1` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversation_participants` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `conversation_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `role` enum('driver','passenger','admin','trip_owner','inquirer') NOT NULL,
  `joined_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `left_at` timestamp NULL DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_participant` (`conversation_id`,`user_id`),
  KEY `idx_conversation_user` (`conversation_id`,`user_id`),
  KEY `idx_user_active` (`user_id`,`is_active`),
  CONSTRAINT `conversation_participants_ibfk_1` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `booking_id` bigint DEFAULT NULL,
  `trip_id` bigint DEFAULT NULL,
  `type` enum('negotiation','post_payment','support','trip_inquiry') DEFAULT 'negotiation',
  `status` enum('active','archived','blocked') DEFAULT 'active',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_message_at` timestamp NULL DEFAULT NULL,
  `archived_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_status` (`status`),
  KEY `idx_last_message` (`last_message_at`),
  KEY `idx_trip_id` (`trip_id`),
  CONSTRAINT `chk_conversation_reference` CHECK (((`booking_id` is not null) or (`trip_id` is not null)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delivery_codes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `booking_id` int NOT NULL,
  `code` varchar(6) COLLATE utf8mb4_unicode_ci NOT NULL,
  `attempts_count` int DEFAULT '0',
  `max_attempts` int DEFAULT '3',
  `status` enum('active','used','expired','regenerated') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `generated_by` int NOT NULL,
  `generated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` timestamp NOT NULL,
  `used_at` timestamp NULL DEFAULT NULL,
  `used_by` int DEFAULT NULL,
  `delivery_latitude` decimal(10,8) DEFAULT NULL,
  `delivery_longitude` decimal(11,8) DEFAULT NULL,
  `delivery_photos` json DEFAULT NULL,
  `verification_photos` json DEFAULT NULL,
  `delivery_location_lat` decimal(10,8) DEFAULT NULL,
  `delivery_location_lng` decimal(11,8) DEFAULT NULL,
  `delivery_photo_url` varchar(512) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_active_booking` (`booking_id`,`status`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_code` (`code`),
  KEY `idx_status` (`status`),
  KEY `idx_expires_at` (`expires_at`),
  KEY `generated_by` (`generated_by`),
  KEY `used_by` (`used_by`),
  CONSTRAINT `delivery_codes_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `delivery_codes_ibfk_2` FOREIGN KEY (`generated_by`) REFERENCES `users` (`id`),
  CONSTRAINT `delivery_codes_ibfk_3` FOREIGN KEY (`used_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `email_verifications` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `token` varchar(255) NOT NULL,
  `is_used` tinyint(1) DEFAULT '0',
  `expires_at` datetime NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `used_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `idx_token` (`token`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_expires_at` (`expires_at`),
  KEY `idx_cleanup` (`expires_at`,`is_used`),
  CONSTRAINT `email_verifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `escrow_accounts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `transaction_id` int NOT NULL,
  `amount_held` decimal(8,2) NOT NULL,
  `amount_released` decimal(8,2) DEFAULT '0.00',
  `hold_reason` enum('payment_security','delivery_confirmation','dispute_resolution') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'delivery_confirmation',
  `status` enum('holding','partial_release','fully_released','disputed') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'holding',
  `held_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at` timestamp NULL DEFAULT NULL,
  `release_notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `idx_escrow_transaction` (`transaction_id`),
  KEY `idx_escrow_status` (`status`),
  CONSTRAINT `escrow_accounts_ibfk_1` FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Système de rétention de fonds jusqu''à livraison confirmée';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_reads` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `message_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `read_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_read` (`message_id`,`user_id`),
  KEY `idx_user_read` (`user_id`,`read_at`),
  KEY `idx_message` (`message_id`),
  CONSTRAINT `message_reads_ibfk_1` FOREIGN KEY (`message_id`) REFERENCES `messages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `messages` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `conversation_id` bigint NOT NULL,
  `sender_id` bigint NOT NULL,
  `message_type` enum('text','image','location','system','action') DEFAULT 'text',
  `content` text,
  `metadata` json DEFAULT NULL,
  `is_masked` tinyint(1) DEFAULT '0',
  `masking_reason` varchar(100) DEFAULT NULL,
  `original_content` text,
  `moderation_status` enum('pending','approved','flagged','blocked') DEFAULT 'approved',
  `moderation_flags` json DEFAULT NULL,
  `system_action` varchar(50) DEFAULT NULL,
  `system_data` json DEFAULT NULL,
  `is_deleted` tinyint(1) DEFAULT '0',
  `deleted_at` timestamp NULL DEFAULT NULL,
  `deleted_by` bigint DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_conversation_created` (`conversation_id`,`created_at`),
  KEY `idx_sender` (`sender_id`),
  KEY `idx_type` (`message_type`),
  KEY `idx_moderation` (`moderation_status`),
  KEY `idx_system_action` (`system_action`),
  CONSTRAINT `messages_ibfk_1` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification_logs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `notification_id` bigint unsigned DEFAULT NULL,
  `user_id` int NOT NULL,
  `type` varchar(50) NOT NULL,
  `channel` enum('push','email','sms','in_app') NOT NULL,
  `recipient` varchar(255) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `data` json DEFAULT NULL,
  `status` enum('pending','sent','delivered','opened','failed','cancelled') DEFAULT 'pending',
  `sent_at` timestamp NULL DEFAULT NULL,
  `delivered_at` timestamp NULL DEFAULT NULL,
  `opened_at` timestamp NULL DEFAULT NULL,
  `failed_at` timestamp NULL DEFAULT NULL,
  `error_message` text,
  `retry_count` int DEFAULT '0',
  `retry_after` timestamp NULL DEFAULT NULL,
  `provider` varchar(50) DEFAULT NULL,
  `provider_message_id` varchar(255) DEFAULT NULL,
  `cost_cents` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_channel` (`user_id`,`channel`),
  KEY `idx_type_status` (`type`,`status`),
  KEY `idx_sent_at` (`sent_at`),
  KEY `idx_retry_after` (`retry_after`),
  KEY `idx_provider_message_id` (`provider_message_id`),
  KEY `notification_id` (`notification_id`),
  CONSTRAINT `notification_logs_ibfk_1` FOREIGN KEY (`notification_id`) REFERENCES `notifications` (`id`) ON DELETE SET NULL,
  CONSTRAINT `notification_logs_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification_templates` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(50) NOT NULL,
  `channel` enum('push','email','sms','in_app') NOT NULL,
  `language` varchar(5) DEFAULT 'fr',
  `subject` varchar(255) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `message` text NOT NULL,
  `html_content` text,
  `variables` json DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_template` (`type`,`channel`,`language`),
  KEY `idx_type` (`type`),
  KEY `idx_channel` (`channel`),
  KEY `idx_language` (`language`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `type` varchar(50) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `data` json DEFAULT NULL,
  `is_read` tinyint(1) DEFAULT '0',
  `priority` enum('low','normal','high','critical') DEFAULT 'normal',
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_user_type` (`user_id`,`type`),
  KEY `idx_user_read` (`user_id`,`is_read`),
  KEY `idx_priority` (`priority`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_authorizations` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `booking_id` int NOT NULL,
  `payment_intent_id` varchar(255) DEFAULT NULL,
  `stripe_account_id` varchar(255) NOT NULL,
  `amount_cents` int NOT NULL,
  `currency` varchar(3) NOT NULL DEFAULT 'CAD',
  `platform_fee_cents` int NOT NULL DEFAULT '0',
  `status` enum('pending','confirmed','captured','cancelled','expired','failed') NOT NULL DEFAULT 'pending',
  `confirmed_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `captured_at` timestamp NULL DEFAULT NULL,
  `cancelled_at` timestamp NULL DEFAULT NULL,
  `confirmation_deadline` timestamp NULL DEFAULT NULL,
  `auto_capture_at` timestamp NULL DEFAULT NULL,
  `capture_reason` enum('manual','auto_72h','auto_pickup','expired') DEFAULT NULL,
  `capture_attempts` int NOT NULL DEFAULT '0',
  `last_capture_error` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `transferred_at` datetime DEFAULT NULL COMMENT 'Date du transfert au transporteur',
  `transfer_id` varchar(255) DEFAULT NULL COMMENT 'ID du transfert Stripe',
  PRIMARY KEY (`id`),
  UNIQUE KEY `payment_intent_id` (`payment_intent_id`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_payment_intent` (`payment_intent_id`),
  KEY `idx_status` (`status`),
  KEY `idx_expires_at` (`expires_at`),
  KEY `idx_auto_capture_at` (`auto_capture_at`),
  KEY `idx_confirmation_deadline` (`confirmation_deadline`),
  KEY `idx_status_auto_capture` (`status`,`auto_capture_at`),
  KEY `idx_status_expires` (`status`,`expires_at`),
  KEY `idx_transferred_at` (`transferred_at`),
  CONSTRAINT `payment_authorizations_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_configurations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `config_key` varchar(100) NOT NULL,
  `config_value` text NOT NULL,
  `value_type` enum('string','integer','float','boolean','json') DEFAULT 'string',
  `category` varchar(50) DEFAULT 'authorization',
  `description` text,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `config_key` (`config_key`),
  KEY `idx_config_key` (`config_key`),
  KEY `idx_category` (`category`),
  KEY `idx_is_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_events_log` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `payment_authorization_id` bigint unsigned DEFAULT NULL,
  `booking_id` int NOT NULL,
  `user_id` int DEFAULT NULL,
  `event_type` enum('authorization_created','authorization_confirmed','authorization_cancelled','authorization_expired','capture_scheduled','capture_attempted','capture_succeeded','capture_failed','refund_initiated','refund_completed','webhook_received','notification_sent') NOT NULL,
  `event_data` json DEFAULT NULL,
  `stripe_event_id` varchar(255) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `success` tinyint(1) NOT NULL DEFAULT '1',
  `error_message` text,
  `processing_time_ms` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_payment_authorization` (`payment_authorization_id`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_stripe_event` (`stripe_event_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_success` (`success`),
  KEY `idx_event_analysis` (`event_type`,`success`,`created_at`),
  KEY `idx_authorization_timeline` (`payment_authorization_id`,`created_at`),
  CONSTRAINT `payment_events_log_ibfk_1` FOREIGN KEY (`payment_authorization_id`) REFERENCES `payment_authorizations` (`id`) ON DELETE SET NULL,
  CONSTRAINT `payment_events_log_ibfk_2` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `payment_events_log_ibfk_3` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `review_reminders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `booking_id` int NOT NULL,
  `user_id` int NOT NULL,
  `reminder_type` enum('initial','reminder_day3') NOT NULL,
  `sent_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_reminder` (`booking_id`,`user_id`,`reminder_type`),
  KEY `idx_booking_user` (`booking_id`,`user_id`),
  KEY `idx_sent_at` (`sent_at`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `review_reminders_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `review_reminders_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reviews` (
  `id` int NOT NULL AUTO_INCREMENT,
  `booking_id` int NOT NULL,
  `reviewer_id` int NOT NULL,
  `reviewed_id` int NOT NULL,
  `rating` tinyint NOT NULL,
  `comment` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `is_visible` tinyint(1) DEFAULT '0',
  `auto_published_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `booking_id` (`booking_id`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_reviewer_id` (`reviewer_id`),
  KEY `idx_reviewed_id` (`reviewed_id`),
  KEY `idx_is_visible` (`is_visible`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `reviews_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reviews_ibfk_2` FOREIGN KEY (`reviewer_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reviews_ibfk_3` FOREIGN KEY (`reviewed_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reviews_chk_1` CHECK ((`rating` between 1 and 5)),
  CONSTRAINT `reviews_chk_2` CHECK ((`reviewer_id` <> `reviewed_id`)),
  CONSTRAINT `reviews_chk_3` CHECK ((char_length(`comment`) <= 500))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scheduled_jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `type` enum('auto_capture','payment_expiry','confirmation_reminder','payment_reminder') NOT NULL,
  `payment_authorization_id` bigint unsigned DEFAULT NULL,
  `booking_id` int DEFAULT NULL,
  `scheduled_at` timestamp NOT NULL,
  `executed_at` timestamp NULL DEFAULT NULL,
  `status` enum('pending','running','completed','failed','cancelled') NOT NULL DEFAULT 'pending',
  `priority` int NOT NULL DEFAULT '5',
  `attempts` int NOT NULL DEFAULT '0',
  `max_attempts` int NOT NULL DEFAULT '3',
  `job_data` json DEFAULT NULL,
  `result` json DEFAULT NULL,
  `error_message` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_type` (`type`),
  KEY `idx_status` (`status`),
  KEY `idx_scheduled_at` (`scheduled_at`),
  KEY `idx_payment_authorization` (`payment_authorization_id`),
  KEY `idx_booking_id` (`booking_id`),
  KEY `idx_job_queue` (`status`,`scheduled_at`,`priority`),
  KEY `idx_job_cleanup` (`status`,`created_at`),
  CONSTRAINT `scheduled_jobs_ibfk_1` FOREIGN KEY (`payment_authorization_id`) REFERENCES `payment_authorizations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `scheduled_jobs_ibfk_2` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `transactions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT (uuid()),
  `booking_id` int NOT NULL,
  `type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_authorization_id` bigint unsigned DEFAULT NULL,
  `stripe_payment_intent_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stripe_payment_method_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `amount` decimal(8,2) NOT NULL,
  `commission` decimal(8,2) NOT NULL,
  `receiver_amount` decimal(8,2) NOT NULL,
  `currency` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'CAD',
  `status` enum('pending','processing','succeeded','failed','cancelled','refunded','authorized','confirmed','captured','expired') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `payment_method` enum('stripe','paypal','bank_transfer') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'stripe',
  `processed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `authorized_at` timestamp NULL DEFAULT NULL,
  `confirmed_at` timestamp NULL DEFAULT NULL,
  `captured_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `transfer_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `stripe_transfer_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `transferred_at` timestamp NULL DEFAULT NULL,
  `rejected_at` timestamp NULL DEFAULT NULL,
  `rejected_by` int DEFAULT NULL,
  `refund_type` enum('full_refund','partial_refund','standard_refund','no_refund') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `compensation_amount` decimal(10,2) DEFAULT '0.00',
  `original_transaction_id` int DEFAULT NULL COMMENT 'Référence à la transaction originale',
  `auto_processed` tinyint(1) DEFAULT '0' COMMENT 'Traité automatiquement',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_transaction_booking` (`booking_id`),
  KEY `idx_transaction_status` (`status`),
  KEY `idx_transaction_stripe` (`stripe_payment_intent_id`),
  KEY `idx_transactions_created_at` (`created_at`),
  KEY `idx_payment_authorization_trans` (`payment_authorization_id`),
  KEY `idx_type` (`type`),
  KEY `idx_transactions_type_status` (`type`,`status`),
  CONSTRAINT `fk_transaction_payment_authorization` FOREIGN KEY (`payment_authorization_id`) REFERENCES `payment_authorizations` (`id`) ON DELETE SET NULL,
  CONSTRAINT `transactions_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Transactions financières et paiements Stripe';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_favorites` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int NOT NULL,
  `user_id` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `notified_on_cancellation` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_favorite` (`trip_id`,`user_id`),
  KEY `idx_user_favorites` (`user_id`,`created_at`),
  CONSTRAINT `trip_favorites_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trip_favorites_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_images` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int NOT NULL,
  `image_path` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `thumbnail` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `alt_text` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT '0',
  `width` int DEFAULT NULL,
  `height` int DEFAULT NULL,
  `image_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_size` int DEFAULT NULL,
  `mime_type` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `order` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_trip_order` (`trip_id`,`order`),
  KEY `idx_trip_id` (`trip_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_trip_images_primary` (`is_primary`),
  KEY `idx_trip_images_order` (`order`),
  CONSTRAINT `trip_images_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_reports` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int NOT NULL,
  `reported_by` int NOT NULL,
  `report_type` enum('spam','fraud','inappropriate','misleading','prohibited_items','suspicious_price','other') NOT NULL,
  `description` text,
  `status` enum('pending','reviewing','resolved','dismissed') DEFAULT 'pending',
  `resolution` text,
  `resolved_by` int DEFAULT NULL,
  `resolved_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_report` (`trip_id`,`reported_by`),
  KEY `reported_by` (`reported_by`),
  KEY `resolved_by` (`resolved_by`),
  KEY `idx_pending_reports` (`status`,`created_at`),
  CONSTRAINT `trip_reports_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trip_reports_ibfk_2` FOREIGN KEY (`reported_by`) REFERENCES `users` (`id`),
  CONSTRAINT `trip_reports_ibfk_3` FOREIGN KEY (`resolved_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_shares` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int NOT NULL,
  `user_id` int DEFAULT NULL,
  `shared_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `platform` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'whatsapp, telegram, copy_link, etc.',
  PRIMARY KEY (`id`),
  KEY `idx_trip_id` (`trip_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_shared_at` (`shared_at`),
  CONSTRAINT `trip_shares_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trip_shares_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_views` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int NOT NULL,
  `user_id` int DEFAULT NULL,
  `session_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `viewed_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_view` (`trip_id`,`user_id`,`session_id`),
  KEY `idx_trip_id` (`trip_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_session_id` (`session_id`),
  KEY `idx_viewed_at` (`viewed_at`),
  CONSTRAINT `trip_views_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trip_views_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trips` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) NOT NULL,
  `title` varchar(255) DEFAULT NULL,
  `user_id` int NOT NULL,
  `departure_city` varchar(100) NOT NULL,
  `departure_country` varchar(100) NOT NULL,
  `departure_airport_code` varchar(10) DEFAULT NULL,
  `departure_date` datetime NOT NULL,
  `arrival_city` varchar(100) NOT NULL,
  `arrival_country` varchar(100) NOT NULL,
  `arrival_airport_code` varchar(10) DEFAULT NULL,
  `arrival_date` datetime NOT NULL,
  `transport_type` varchar(50) NOT NULL DEFAULT 'car',
  `available_weight_kg` decimal(5,2) NOT NULL DEFAULT '23.00',
  `price_per_kg` decimal(8,2) NOT NULL,
  `currency` varchar(3) DEFAULT 'EUR',
  `is_domestic` tinyint(1) NOT NULL DEFAULT '0',
  `restrictions` json DEFAULT NULL,
  `special_instructions` text,
  `flight_number` varchar(20) DEFAULT NULL,
  `airline` varchar(100) DEFAULT NULL,
  `ticket_verified` tinyint(1) DEFAULT '0',
  `ticket_verification_date` datetime DEFAULT NULL,
  `status` enum('draft','pending_review','published','active','rejected','paused','booked','in_progress','completed','cancelled','expired') DEFAULT 'draft',
  `is_approved` tinyint(1) DEFAULT '0',
  `view_count` int DEFAULT '0',
  `booking_count` int DEFAULT '0',
  `description` text,
  `special_notes` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `published_at` timestamp NULL DEFAULT NULL COMMENT 'Date de publication',
  `approved_at` timestamp NULL DEFAULT NULL,
  `approved_by` int DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `paused_at` timestamp NULL DEFAULT NULL COMMENT 'Date de mise en pause',
  `cancelled_at` timestamp NULL DEFAULT NULL COMMENT 'Date d''annulation',
  `archived_at` timestamp NULL DEFAULT NULL COMMENT 'Date d''archivage',
  `expired_at` timestamp NULL DEFAULT NULL COMMENT 'Date d''expiration',
  `rejected_at` timestamp NULL DEFAULT NULL COMMENT 'Date de rejet',
  `completed_at` timestamp NULL DEFAULT NULL COMMENT 'Date de complétion',
  `rejection_reason` text COMMENT 'Raison du rejet par modération',
  `rejection_details` json DEFAULT NULL COMMENT 'Détails structurés du rejet',
  `cancellation_reason` enum('user_cancelled','no_bookings','emergency','flight_cancelled','admin_cancelled','fraud_suspected','other') DEFAULT NULL COMMENT 'Type de raison d''annulation',
  `cancellation_details` text COMMENT 'Détails de l''annulation',
  `pause_reason` varchar(255) DEFAULT NULL COMMENT 'Raison de la pause',
  `auto_approved` tinyint(1) DEFAULT '0' COMMENT 'Approuvé automatiquement',
  `moderated_by` int DEFAULT NULL COMMENT 'ID du modérateur',
  `moderation_notes` text COMMENT 'Notes de modération',
  `trust_score_at_creation` int DEFAULT NULL COMMENT 'Score de confiance lors de la création',
  `requires_manual_review` tinyint(1) DEFAULT '0' COMMENT 'Nécessite révision manuelle',
  `review_priority` enum('low','medium','high','urgent') DEFAULT 'medium',
  `share_count` int DEFAULT '0' COMMENT 'Nombre de partages',
  `favorite_count` int DEFAULT '0' COMMENT 'Nombre de favoris',
  `report_count` int DEFAULT '0' COMMENT 'Nombre de signalements',
  `duplicate_count` int DEFAULT '0' COMMENT 'Nombre de duplications',
  `edit_count` int DEFAULT '0' COMMENT 'Nombre de modifications',
  `total_booked_weight` decimal(5,2) DEFAULT '0.00' COMMENT 'Poids total réservé',
  `remaining_weight` decimal(5,2) GENERATED ALWAYS AS ((`available_weight_kg` - `total_booked_weight`)) STORED,
  `is_urgent` tinyint(1) DEFAULT '0' COMMENT 'Marqué comme urgent',
  `is_featured` tinyint(1) DEFAULT '0' COMMENT 'Mis en avant',
  `is_verified` tinyint(1) DEFAULT '0' COMMENT 'Vérifié par admin',
  `auto_expire` tinyint(1) DEFAULT '1' COMMENT 'Expiration automatique',
  `allow_partial_booking` tinyint(1) DEFAULT '1' COMMENT 'Accepte réservations partielles',
  `instant_booking` tinyint(1) DEFAULT '0' COMMENT 'Réservation instantanée sans confirmation',
  `visibility` enum('public','private','unlisted') DEFAULT 'public',
  `min_user_rating` decimal(2,1) DEFAULT '0.0' COMMENT 'Note minimum requise pour réserver',
  `min_user_trips` int DEFAULT '0' COMMENT 'Nombre minimum de voyages requis',
  `blocked_users` json DEFAULT NULL COMMENT 'Liste des IDs utilisateurs bloqués',
  `slug` varchar(255) DEFAULT NULL COMMENT 'URL slug pour partage',
  `meta_title` varchar(255) DEFAULT NULL COMMENT 'Titre pour partage social',
  `meta_description` text COMMENT 'Description pour partage social',
  `share_token` varchar(64) DEFAULT NULL COMMENT 'Token unique pour partage privé',
  `version` int DEFAULT '1' COMMENT 'Version de l''annonce',
  `last_major_edit` timestamp NULL DEFAULT NULL COMMENT 'Dernière modification majeure',
  `original_trip_id` int DEFAULT NULL COMMENT 'ID de l''annonce originale si dupliquée',
  `deleted_at` timestamp NULL DEFAULT NULL,
  `has_images` tinyint(1) DEFAULT '0' COMMENT 'Quick flag to check if trip has images',
  `image_count` tinyint DEFAULT '0' COMMENT 'Number of images (0-2)',
  `cancelled_by` enum('traveler','sender') DEFAULT NULL COMMENT 'Qui a annulé le voyage',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  UNIQUE KEY `slug` (`slug`),
  KEY `idx_departure_date` (`departure_date`),
  KEY `idx_departure_city` (`departure_city`),
  KEY `idx_arrival_city` (`arrival_city`),
  KEY `idx_status` (`status`),
  KEY `idx_user_id` (`user_id`),
  KEY `original_trip_id` (`original_trip_id`),
  KEY `idx_status_dates` (`status`,`departure_date`),
  KEY `idx_published` (`published_at`,`status`),
  KEY `idx_moderation` (`requires_manual_review`,`review_priority`),
  KEY `idx_visibility` (`visibility`,`status`),
  KEY `idx_slug` (`slug`),
  KEY `idx_featured` (`is_featured`,`status`),
  KEY `idx_expired` (`auto_expire`,`departure_date`,`status`),
  KEY `idx_is_approved` (`is_approved`),
  KEY `idx_trips_transport_type` (`transport_type`),
  KEY `idx_trips_is_domestic` (`is_domestic`),
  KEY `idx_trips_approved_at` (`approved_at`),
  KEY `idx_trips_approved_by` (`approved_by`),
  KEY `idx_trips_departure_status` (`departure_date`,`status`),
  CONSTRAINT `fk_trips_approved_by` FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `trips_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trips_ibfk_2` FOREIGN KEY (`original_trip_id`) REFERENCES `trips` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_fcm_tokens` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique du token FCM',
  `user_id` int NOT NULL COMMENT 'ID de l''utilisateur propriétaire du token',
  `fcm_token` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Token FCM généré par Firebase',
  `platform` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'mobile' COMMENT 'Plateforme (mobile, web, etc.)',
  `is_active` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Indique si le token est actif',
  `device_info` json DEFAULT NULL COMMENT 'Informations sur l''appareil (modèle, version OS, etc.)',
  `app_version` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Version de l''application mobile',
  `last_used_at` timestamp NULL DEFAULT NULL COMMENT 'Dernière utilisation du token',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date de création',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Date de dernière modification',
  `deleted_at` timestamp NULL DEFAULT NULL COMMENT 'Date de suppression logique (soft delete)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_user_token` (`user_id`,`fcm_token`(255)),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_is_active` (`is_active`),
  KEY `idx_platform` (`platform`),
  KEY `idx_last_used_at` (`last_used_at`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_user_fcm_tokens_active` (`user_id`,`is_active`),
  KEY `idx_user_fcm_tokens_platform` (`platform`,`is_active`),
  KEY `idx_user_fcm_active` (`user_id`,`is_active`),
  KEY `idx_platform_active` (`platform`,`is_active`),
  CONSTRAINT `fk_user_fcm_tokens_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Stockage des tokens FCM pour les notifications push des utilisateurs';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_notification_preferences` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `push_enabled` tinyint(1) DEFAULT '1',
  `email_enabled` tinyint(1) DEFAULT '1',
  `sms_enabled` tinyint(1) DEFAULT '1',
  `in_app_enabled` tinyint(1) DEFAULT '1',
  `marketing_enabled` tinyint(1) DEFAULT '0',
  `quiet_hours_enabled` tinyint(1) DEFAULT '1',
  `quiet_hours_start` time DEFAULT '22:00:00',
  `quiet_hours_end` time DEFAULT '08:00:00',
  `timezone` varchar(50) DEFAULT 'Europe/Paris',
  `trip_updates_push` tinyint(1) DEFAULT '1',
  `trip_updates_email` tinyint(1) DEFAULT '1',
  `booking_updates_push` tinyint(1) DEFAULT '1',
  `booking_updates_email` tinyint(1) DEFAULT '1',
  `payment_updates_push` tinyint(1) DEFAULT '1',
  `payment_updates_email` tinyint(1) DEFAULT '1',
  `security_alerts_push` tinyint(1) DEFAULT '1',
  `security_alerts_email` tinyint(1) DEFAULT '1',
  `language` varchar(5) DEFAULT 'fr',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `user_notification_preferences_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_ratings` (
  `user_id` int NOT NULL,
  `average_rating` decimal(3,2) DEFAULT '0.00',
  `total_reviews` int DEFAULT '0',
  `as_traveler_rating` decimal(3,2) DEFAULT '0.00',
  `as_traveler_count` int DEFAULT '0',
  `as_sender_rating` decimal(3,2) DEFAULT '0.00',
  `as_sender_count` int DEFAULT '0',
  `last_calculated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `reliability_score` int DEFAULT '100' COMMENT 'Score de fiabilité calculé',
  `last_updated` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  KEY `idx_average_rating` (`average_rating` DESC),
  KEY `idx_last_calculated` (`last_calculated_at`),
  CONSTRAINT `user_ratings_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_reliability_history` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `action` varchar(100) NOT NULL,
  `impact` int NOT NULL COMMENT 'Impact sur le score (-10 à +10)',
  `previous_score` int NOT NULL,
  `new_score` int NOT NULL,
  `description` text,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_reliability` (`user_id`,`created_at`),
  CONSTRAINT `user_reliability_history_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_stripe_accounts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `stripe_account_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('pending','onboarding','active','restricted','rejected') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `details_submitted` tinyint(1) DEFAULT '0',
  `charges_enabled` tinyint(1) DEFAULT '0',
  `payouts_enabled` tinyint(1) DEFAULT '0',
  `onboarding_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requirements` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `stripe_account_id` (`stripe_account_id`),
  KEY `idx_user_stripe` (`user_id`),
  KEY `idx_stripe_account` (`stripe_account_id`),
  KEY `idx_account_status` (`status`),
  CONSTRAINT `user_stripe_accounts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Comptes Stripe Connect pour les utilisateurs transporteurs';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_tokens` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `token` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('refresh','access','password_reset') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` timestamp NOT NULL,
  `is_revoked` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_token` (`token`),
  KEY `idx_type` (`type`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `user_tokens_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` enum('male','female','other') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `nationality` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bio` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `website` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profession` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_line1` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_line2` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state_province` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `postal_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `preferred_language` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'fr',
  `timezone` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'Europe/Paris',
  `emergency_contact_name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emergency_contact_phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emergency_contact_relation` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `login_method` enum('email','phone','social') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'email',
  `two_factor_enabled` tinyint(1) DEFAULT '0',
  `newsletter_subscribed` tinyint(1) DEFAULT '1',
  `marketing_emails` tinyint(1) DEFAULT '0',
  `profile_visibility` enum('public','private','friends_only') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'public',
  `is_verified` tinyint(1) DEFAULT '0',
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `stripe_setup_completed` tinyint(1) DEFAULT '0',
  `stripe_onboarding_completed_at` timestamp NULL DEFAULT NULL,
  `phone_verified_at` timestamp NULL DEFAULT NULL,
  `profile_picture` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('active','inactive','suspended') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `role` enum('user','admin','moderator') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `last_login_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `social_provider` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'google, facebook, apple',
  `social_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'ID from social provider',
  `provider_data` json DEFAULT NULL COMMENT 'Additional data from provider',
  `deleted_at` timestamp NULL DEFAULT NULL,
  `publication_restricted_until` datetime DEFAULT NULL COMMENT 'Restriction de publication jusqu''à',
  `reliability_score` int DEFAULT '100' COMMENT 'Score de fiabilité (0-100)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `phone` (`phone`),
  UNIQUE KEY `unique_social_account` (`social_provider`,`social_id`),
  KEY `idx_email` (`email`),
  KEY `idx_phone` (`phone`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_status` (`status`),
  KEY `idx_social_provider` (`social_provider`),
  KEY `idx_social_id` (`social_id`),
  KEY `idx_users_role` (`role`),
  KEY `idx_users_login_method` (`login_method`),
  KEY `idx_users_country` (`country`),
  KEY `idx_users_city` (`city`),
  KEY `idx_users_profile_visibility` (`profile_visibility`),
  KEY `idx_users_stripe_setup` (`stripe_setup_completed`),
  KEY `idx_users_reliability` (`reliability_score`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table des utilisateurs avec système de rôles';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `verification_codes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `booking_id` int DEFAULT NULL,
  `code` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('phone_verification','email_verification','password_reset','pickup_code','delivery_code') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expires_at` timestamp NOT NULL,
  `is_used` tinyint(1) DEFAULT '0',
  `attempts` int DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_code` (`code`),
  KEY `idx_type` (`type`),
  KEY `idx_expires_at` (`expires_at`),
  KEY `idx_booking_id` (`booking_id`),
  CONSTRAINT `verification_codes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;



SET FOREIGN_KEY_CHECKS = 1;

