-- MySQL dump 10.13  Distrib 9.3.0, for macos15.2 (arm64)
--
-- Host: localhost    Database: kiloshare
-- ------------------------------------------------------
-- Server version	9.3.0

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

--
-- Temporary view structure for view `active_trips_overview`
--

DROP TABLE IF EXISTS `active_trips_overview`;
/*!50001 DROP VIEW IF EXISTS `active_trips_overview`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `active_trips_overview` AS SELECT 
 1 AS `id`,
 1 AS `uuid`,
 1 AS `user_id`,
 1 AS `departure_city`,
 1 AS `departure_country`,
 1 AS `departure_airport_code`,
 1 AS `departure_date`,
 1 AS `arrival_city`,
 1 AS `arrival_country`,
 1 AS `arrival_airport_code`,
 1 AS `arrival_date`,
 1 AS `available_weight_kg`,
 1 AS `price_per_kg`,
 1 AS `currency`,
 1 AS `flight_number`,
 1 AS `airline`,
 1 AS `ticket_verified`,
 1 AS `ticket_verification_date`,
 1 AS `status`,
 1 AS `view_count`,
 1 AS `booking_count`,
 1 AS `description`,
 1 AS `special_notes`,
 1 AS `created_at`,
 1 AS `updated_at`,
 1 AS `published_at`,
 1 AS `paused_at`,
 1 AS `cancelled_at`,
 1 AS `archived_at`,
 1 AS `expired_at`,
 1 AS `rejected_at`,
 1 AS `completed_at`,
 1 AS `rejection_reason`,
 1 AS `rejection_details`,
 1 AS `cancellation_reason`,
 1 AS `cancellation_details`,
 1 AS `pause_reason`,
 1 AS `auto_approved`,
 1 AS `moderated_by`,
 1 AS `moderation_notes`,
 1 AS `trust_score_at_creation`,
 1 AS `requires_manual_review`,
 1 AS `review_priority`,
 1 AS `share_count`,
 1 AS `favorite_count`,
 1 AS `report_count`,
 1 AS `duplicate_count`,
 1 AS `edit_count`,
 1 AS `total_booked_weight`,
 1 AS `remaining_weight`,
 1 AS `is_urgent`,
 1 AS `is_featured`,
 1 AS `is_verified`,
 1 AS `auto_expire`,
 1 AS `allow_partial_booking`,
 1 AS `instant_booking`,
 1 AS `visibility`,
 1 AS `min_user_rating`,
 1 AS `min_user_trips`,
 1 AS `blocked_users`,
 1 AS `slug`,
 1 AS `meta_title`,
 1 AS `meta_description`,
 1 AS `share_token`,
 1 AS `version`,
 1 AS `last_major_edit`,
 1 AS `original_trip_id`,
 1 AS `first_name`,
 1 AS `last_name`,
 1 AS `profile_picture`,
 1 AS `hours_until_departure`,
 1 AS `booking_percentage`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `admin_actions`
--

DROP TABLE IF EXISTS `admin_actions`;
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

--
-- Table structure for table `auto_support_tickets`
--

DROP TABLE IF EXISTS `auto_support_tickets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auto_support_tickets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int DEFAULT NULL,
  `booking_id` int DEFAULT NULL,
  `user_id` int NOT NULL,
  `category` enum('critical_cancellation','refund_issue','user_dispute','technical_issue') NOT NULL,
  `priority` enum('low','medium','high','critical') DEFAULT 'medium',
  `title` varchar(255) NOT NULL,
  `description` text NOT NULL,
  `status` enum('open','in_progress','resolved','closed') DEFAULT 'open',
  `assigned_to` int DEFAULT NULL COMMENT 'Admin user ID',
  `auto_generated` tinyint(1) DEFAULT '1',
  `resolution_notes` text,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `trip_id` (`trip_id`),
  KEY `booking_id` (`booking_id`),
  KEY `user_id` (`user_id`),
  KEY `idx_status_priority` (`status`,`priority`),
  KEY `idx_auto_generated` (`auto_generated`,`created_at`),
  CONSTRAINT `auto_support_tickets_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE SET NULL,
  CONSTRAINT `auto_support_tickets_ibfk_2` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE SET NULL,
  CONSTRAINT `auto_support_tickets_ibfk_3` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `booking_summary`
--

DROP TABLE IF EXISTS `booking_summary`;
/*!50001 DROP VIEW IF EXISTS `booking_summary`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `booking_summary` AS SELECT 
 1 AS `id`,
 1 AS `uuid`,
 1 AS `status`,
 1 AS `package_description`,
 1 AS `weight_kg`,
 1 AS `final_price`,
 1 AS `commission_amount`,
 1 AS `sender_email`,
 1 AS `receiver_email`,
 1 AS `departure_city`,
 1 AS `arrival_city`,
 1 AS `created_at`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `bookings`
--

DROP TABLE IF EXISTS `bookings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bookings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT (uuid()),
  `trip_id` int NOT NULL,
  `booking_negotiation_id` int DEFAULT NULL,
  `sender_id` int NOT NULL,
  `receiver_id` int NOT NULL,
  `package_description` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `weight_kg` decimal(5,2) NOT NULL,
  `dimensions_cm` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `proposed_price` decimal(8,2) NOT NULL,
  `final_price` decimal(8,2) DEFAULT NULL,
  `payment_authorization_id` bigint unsigned DEFAULT NULL,
  `payment_authorized_at` timestamp NULL DEFAULT NULL,
  `payment_confirmed_at` timestamp NULL DEFAULT NULL,
  `payment_captured_at` timestamp NULL DEFAULT NULL,
  `commission_rate` decimal(4,2) DEFAULT '15.00',
  `commission_amount` decimal(8,2) DEFAULT NULL,
  `status` enum('pending','accepted','payment_authorized','payment_confirmed','paid','in_transit','delivered','completed','cancelled','payment_failed','payment_expired','payment_cancelled','refunded') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `pickup_address` text COLLATE utf8mb4_unicode_ci,
  `delivery_address` text COLLATE utf8mb4_unicode_ci,
  `pickup_date` datetime DEFAULT NULL,
  `delivery_date` datetime DEFAULT NULL,
  `pickup_code` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `delivery_code` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `special_instructions` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `expires_at` timestamp NULL DEFAULT NULL,
  `payment_status` enum('pending','paid','refunded','failed') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `rejection_reason` text COLLATE utf8mb4_unicode_ci COMMENT 'Raison optionnelle fournie lors du rejet d''une réservation',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_trip_bookings` (`trip_id`),
  KEY `idx_sender_bookings` (`sender_id`),
  KEY `idx_receiver_bookings` (`receiver_id`),
  KEY `idx_booking_status` (`status`),
  KEY `idx_booking_dates` (`pickup_date`,`delivery_date`),
  KEY `idx_bookings_created_at` (`created_at`),
  KEY `booking_negotiation_id` (`booking_negotiation_id`),
  KEY `idx_bookings_rejection_reason` (`rejection_reason`(255)),
  KEY `idx_payment_authorization` (`payment_authorization_id`),
  KEY `idx_booking_status_timestamps` (`status`,`payment_confirmed_at`,`payment_captured_at`),
  KEY `idx_bookings_trip_status` (`trip_id`,`status`),
  CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bookings_ibfk_3` FOREIGN KEY (`receiver_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_booking_payment_authorization` FOREIGN KEY (`payment_authorization_id`) REFERENCES `payment_authorizations` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table principale des réservations de transport de colis';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `tr_bookings_calculate_commission` BEFORE UPDATE ON `bookings` FOR EACH ROW BEGIN
    IF NEW.final_price IS NOT NULL AND NEW.final_price > 0 THEN
        SET NEW.commission_amount = NEW.final_price * (NEW.commission_rate / 100);
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `cancellation_attempts`
--

DROP TABLE IF EXISTS `cancellation_attempts`;
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
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cancellation_notifications`
--

DROP TABLE IF EXISTS `cancellation_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cancellation_notifications` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int NOT NULL,
  `user_id` int NOT NULL,
  `notification_type` enum('trip_cancelled','alternative_suggested','refund_processed','penalty_applied') NOT NULL,
  `channel` enum('email','push','in_app','sms') NOT NULL,
  `status` enum('pending','sent','delivered','failed') DEFAULT 'pending',
  `content` json DEFAULT NULL COMMENT 'Contenu personnalisé de la notification',
  `sent_at` datetime DEFAULT NULL,
  `delivered_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `trip_id` (`trip_id`),
  KEY `idx_status_type` (`status`,`notification_type`),
  KEY `idx_user_notifications` (`user_id`,`sent_at`),
  CONSTRAINT `cancellation_notifications_ibfk_1` FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `cancellation_notifications_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cancellation_policies`
--

DROP TABLE IF EXISTS `cancellation_policies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cancellation_policies` (
  `id` int NOT NULL AUTO_INCREMENT,
  `policy_name` varchar(100) NOT NULL,
  `hours_before_departure_min` int NOT NULL,
  `hours_before_departure_max` int DEFAULT NULL,
  `has_bookings` tinyint(1) NOT NULL DEFAULT '0',
  `has_payments` tinyint(1) NOT NULL DEFAULT '0',
  `penalty_duration_days` int DEFAULT '0',
  `reliability_impact` int DEFAULT '0',
  `refund_percentage` decimal(5,2) DEFAULT '100.00',
  `compensation_percentage` decimal(5,2) DEFAULT '0.00',
  `restriction_type` enum('none','warning','publication_restriction','account_suspension') DEFAULT 'none',
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_policy` (`hours_before_departure_min`,`hours_before_departure_max`,`has_bookings`,`has_payments`),
  KEY `idx_active_policies` (`is_active`,`hours_before_departure_min`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `contact_revelations`
--

DROP TABLE IF EXISTS `contact_revelations`;
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

--
-- Table structure for table `conversation_participants`
--

DROP TABLE IF EXISTS `conversation_participants`;
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
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `conversations`
--

DROP TABLE IF EXISTS `conversations`;
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
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `email_verifications`
--

DROP TABLE IF EXISTS `email_verifications`;
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
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `escrow_accounts`
--

DROP TABLE IF EXISTS `escrow_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `escrow_accounts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `transaction_id` int NOT NULL,
  `amount_held` decimal(8,2) NOT NULL,
  `amount_released` decimal(8,2) DEFAULT '0.00',
  `hold_reason` enum('payment_security','delivery_confirmation','dispute_resolution') COLLATE utf8mb4_unicode_ci DEFAULT 'delivery_confirmation',
  `status` enum('holding','partial_release','fully_released','disputed') COLLATE utf8mb4_unicode_ci DEFAULT 'holding',
  `held_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at` timestamp NULL DEFAULT NULL,
  `release_notes` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `idx_escrow_transaction` (`transaction_id`),
  KEY `idx_escrow_status` (`status`),
  CONSTRAINT `escrow_accounts_ibfk_1` FOREIGN KEY (`transaction_id`) REFERENCES `transactions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Système de rétention de fonds jusqu''à livraison confirmée';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_attachments`
--

DROP TABLE IF EXISTS `message_attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `message_attachments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `message_id` bigint NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `file_type` varchar(100) NOT NULL,
  `file_size` bigint NOT NULL,
  `image_width` int DEFAULT NULL,
  `image_height` int DEFAULT NULL,
  `thumbnail_path` varchar(500) DEFAULT NULL,
  `is_scanned` tinyint(1) DEFAULT '0',
  `scan_status` enum('pending','clean','malware','suspicious') DEFAULT 'pending',
  `uploaded_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_message` (`message_id`),
  KEY `idx_type` (`file_type`),
  KEY `idx_scan_status` (`scan_status`),
  CONSTRAINT `message_attachments_ibfk_1` FOREIGN KEY (`message_id`) REFERENCES `messages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `message_reads`
--

DROP TABLE IF EXISTS `message_reads`;
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
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
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

--
-- Table structure for table `notification_logs`
--

DROP TABLE IF EXISTS `notification_logs`;
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
) ENGINE=InnoDB AUTO_INCREMENT=170 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `notification_stats_by_channel`
--

DROP TABLE IF EXISTS `notification_stats_by_channel`;
/*!50001 DROP VIEW IF EXISTS `notification_stats_by_channel`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `notification_stats_by_channel` AS SELECT 
 1 AS `channel`,
 1 AS `date`,
 1 AS `total_sent`,
 1 AS `delivered`,
 1 AS `opened`,
 1 AS `failed`,
 1 AS `delivery_rate`,
 1 AS `open_rate`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `notification_templates`
--

DROP TABLE IF EXISTS `notification_templates`;
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
) ENGINE=InnoDB AUTO_INCREMENT=96 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
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
) ENGINE=InnoDB AUTO_INCREMENT=117 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payment_authorizations`
--

DROP TABLE IF EXISTS `payment_authorizations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payment_authorizations` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `booking_id` int NOT NULL,
  `payment_intent_id` varchar(255) NOT NULL,
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
  CONSTRAINT `payment_authorizations_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payment_configurations`
--

DROP TABLE IF EXISTS `payment_configurations`;
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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `payment_events_log`
--

DROP TABLE IF EXISTS `payment_events_log`;
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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `review_reminders`
--

DROP TABLE IF EXISTS `review_reminders`;
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

--
-- Table structure for table `reviews`
--

DROP TABLE IF EXISTS `reviews`;
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
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `after_review_insert` AFTER INSERT ON `reviews` FOR EACH ROW BEGIN
    IF NEW.is_visible = TRUE THEN
        CALL CalculateUserRating(NEW.reviewed_id);
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `after_review_visible_update` AFTER UPDATE ON `reviews` FOR EACH ROW BEGIN
    IF NEW.is_visible = TRUE AND OLD.is_visible = FALSE THEN
        CALL CalculateUserRating(NEW.reviewed_id);
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `scheduled_jobs`
--

DROP TABLE IF EXISTS `scheduled_jobs`;
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
) ENGINE=InnoDB AUTO_INCREMENT=28 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `transactions`
--

DROP TABLE IF EXISTS `transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `transactions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT (uuid()),
  `booking_id` int NOT NULL,
  `type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_authorization_id` bigint unsigned DEFAULT NULL,
  `stripe_payment_intent_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stripe_payment_method_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `amount` decimal(8,2) NOT NULL,
  `commission` decimal(8,2) NOT NULL,
  `receiver_amount` decimal(8,2) NOT NULL,
  `currency` varchar(3) COLLATE utf8mb4_unicode_ci DEFAULT 'CAD',
  `status` enum('pending','processing','succeeded','failed','cancelled','refunded','authorized','confirmed','captured','expired') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `payment_method` enum('stripe','paypal','bank_transfer') COLLATE utf8mb4_unicode_ci DEFAULT 'stripe',
  `processed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `authorized_at` timestamp NULL DEFAULT NULL,
  `confirmed_at` timestamp NULL DEFAULT NULL,
  `captured_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `transfer_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `stripe_transfer_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `transferred_at` timestamp NULL DEFAULT NULL,
  `rejected_at` timestamp NULL DEFAULT NULL,
  `rejected_by` int DEFAULT NULL,
  `refund_type` enum('full_refund','partial_refund','standard_refund','no_refund') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
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
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Transactions financières et paiements Stripe';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `trip_alternatives`
--

DROP TABLE IF EXISTS `trip_alternatives`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_alternatives` (
  `id` int NOT NULL AUTO_INCREMENT,
  `cancelled_trip_id` int NOT NULL,
  `suggested_trip_id` int NOT NULL,
  `affected_user_id` int NOT NULL,
  `suggestion_type` enum('automatic','manual','ai_recommended') DEFAULT 'automatic',
  `relevance_score` decimal(3,2) DEFAULT '0.00' COMMENT 'Score de pertinence (0-1)',
  `is_accepted` tinyint(1) DEFAULT NULL COMMENT 'NULL = non répondu, TRUE = accepté, FALSE = refusé',
  `suggested_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `responded_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `suggested_trip_id` (`suggested_trip_id`),
  KEY `affected_user_id` (`affected_user_id`),
  KEY `idx_suggestions` (`cancelled_trip_id`,`affected_user_id`),
  KEY `idx_responses` (`is_accepted`,`responded_at`),
  CONSTRAINT `trip_alternatives_ibfk_1` FOREIGN KEY (`cancelled_trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trip_alternatives_ibfk_2` FOREIGN KEY (`suggested_trip_id`) REFERENCES `trips` (`id`) ON DELETE CASCADE,
  CONSTRAINT `trip_alternatives_ibfk_3` FOREIGN KEY (`affected_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `trip_favorites`
--

DROP TABLE IF EXISTS `trip_favorites`;
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

--
-- Table structure for table `trip_images`
--

DROP TABLE IF EXISTS `trip_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `trip_images` (
  `id` int NOT NULL AUTO_INCREMENT,
  `trip_id` int NOT NULL,
  `image_path` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `url` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `thumbnail` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `alt_text` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT '0',
  `width` int DEFAULT NULL,
  `height` int DEFAULT NULL,
  `image_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `file_size` int DEFAULT NULL,
  `mime_type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
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
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `trip_reports`
--

DROP TABLE IF EXISTS `trip_reports`;
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

--
-- Temporary view structure for view `trip_status_summary`
--

DROP TABLE IF EXISTS `trip_status_summary`;
/*!50001 DROP VIEW IF EXISTS `trip_status_summary`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `trip_status_summary` AS SELECT 
 1 AS `user_id`,
 1 AS `status`,
 1 AS `count`,
 1 AS `total_views`,
 1 AS `total_bookings`,
 1 AS `avg_price`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `trips`
--

DROP TABLE IF EXISTS `trips`;
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
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `generate_trip_slug` BEFORE INSERT ON `trips` FOR EACH ROW BEGIN
    IF NEW.slug IS NULL THEN
        SET NEW.slug = CONCAT(
            LOWER(REPLACE(NEW.departure_city, ' ', '-')),
            '-to-',
            LOWER(REPLACE(NEW.arrival_city, ' ', '-')),
            '-',
            DATE_FORMAT(NEW.departure_date, '%Y%m%d'),
            '-',
            SUBSTRING(MD5(CONCAT(NEW.uuid, NOW())), 1, 6)
        );
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `auto_expire_trips` BEFORE UPDATE ON `trips` FOR EACH ROW BEGIN
    -- Si la date de départ est passée et statut actif sans réservation
    IF NEW.departure_date < NOW() 
       AND NEW.status = 'active' 
       AND NEW.booking_count = 0 
       AND NEW.auto_expire = TRUE THEN
        SET NEW.status = 'expired';
        SET NEW.expired_at = NOW();
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `update_user_type_on_trip_completion` AFTER UPDATE ON `trips` FOR EACH ROW BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Compter les voyages complétés
        SET @completed_trips = (
            SELECT COUNT(*)
            FROM trips
            WHERE user_id = NEW.user_id AND status = 'completed'
        );

        -- Calculer l'ancienneté du compte en mois
        SET @account_age_months = (
            SELECT TIMESTAMPDIFF(MONTH, created_at, NOW())
            FROM users
            WHERE id = NEW.user_id
        );

        -- Mettre à jour le type d'utilisateur
        UPDATE users
        SET user_type = CASE
            WHEN @completed_trips >= 10 AND @account_age_months >= 6 THEN 'expert'
            WHEN @completed_trips >= 3 AND @account_age_months >= 2 THEN 'confirmed'
            ELSE 'new'
        END
        WHERE id = NEW.user_id;
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `notify_favorites_on_trip_cancellation` AFTER UPDATE ON `trips` FOR EACH ROW BEGIN
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        -- Marquer les favoris comme devant être notifiés
        UPDATE trip_favorites
        SET notified_on_cancellation = TRUE
        WHERE trip_id = NEW.id AND notified_on_cancellation = FALSE;

        -- Insérer les notifications pour les utilisateurs ayant mis en favoris
        INSERT INTO cancellation_notifications (trip_id, user_id, notification_type, channel, content)
        SELECT NEW.id, user_id, 'trip_cancelled', 'push',
               JSON_OBJECT('message', 'Un voyage que vous avez mis en favoris a été annulé')
        FROM trip_favorites
        WHERE trip_id = NEW.id;
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `after_trip_cancellation` AFTER UPDATE ON `trips` FOR EACH ROW BEGIN
    -- Si un voyage est annulé par le voyageur avec des réservations
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' AND NEW.cancelled_by = 'traveler' THEN
        -- Vérifier s'il y avait des réservations confirmées (incluant 'paid')
        IF (SELECT COUNT(*) FROM bookings WHERE trip_id = NEW.id AND status IN ('accepted', 'in_progress', 'paid')) > 0 THEN
            UPDATE users
            SET
                cancellation_count = cancellation_count + 1,
                last_cancellation_date = NOW()
            WHERE id = NEW.user_id;
        END IF;
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `user_fcm_tokens`
--

DROP TABLE IF EXISTS `user_fcm_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_fcm_tokens` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique du token FCM',
  `user_id` int NOT NULL COMMENT 'ID de l''utilisateur propriétaire du token',
  `fcm_token` text COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Token FCM généré par Firebase',
  `platform` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'mobile' COMMENT 'Plateforme (mobile, web, etc.)',
  `is_active` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Indique si le token est actif',
  `device_info` json DEFAULT NULL COMMENT 'Informations sur l''appareil (modèle, version OS, etc.)',
  `app_version` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Version de l''application mobile',
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

--
-- Table structure for table `user_notification_preferences`
--

DROP TABLE IF EXISTS `user_notification_preferences`;
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
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `user_rating_summary`
--

DROP TABLE IF EXISTS `user_rating_summary`;
/*!50001 DROP VIEW IF EXISTS `user_rating_summary`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `user_rating_summary` AS SELECT 
 1 AS `user_id`,
 1 AS `first_name`,
 1 AS `last_name`,
 1 AS `average_rating`,
 1 AS `total_reviews`,
 1 AS `as_traveler_rating`,
 1 AS `as_traveler_count`,
 1 AS `as_sender_rating`,
 1 AS `as_sender_count`,
 1 AS `last_calculated_at`,
 1 AS `rating_status`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `user_ratings`
--

DROP TABLE IF EXISTS `user_ratings`;
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

--
-- Table structure for table `user_reliability_history`
--

DROP TABLE IF EXISTS `user_reliability_history`;
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

--
-- Temporary view structure for view `user_reliability_stats`
--

DROP TABLE IF EXISTS `user_reliability_stats`;
/*!50001 DROP VIEW IF EXISTS `user_reliability_stats`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `user_reliability_stats` AS SELECT 
 1 AS `user_id`,
 1 AS `first_name`,
 1 AS `last_name`,
 1 AS `email`,
 1 AS `user_type`,
 1 AS `reliability_score`,
 1 AS `total_trips`,
 1 AS `completed_trips`,
 1 AS `cancelled_trips`,
 1 AS `completion_rate`,
 1 AS `recent_cancellations`,
 1 AS `member_since`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `user_stripe_accounts`
--

DROP TABLE IF EXISTS `user_stripe_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_stripe_accounts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `stripe_account_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('pending','onboarding','active','restricted','rejected') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `details_submitted` tinyint(1) DEFAULT '0',
  `charges_enabled` tinyint(1) DEFAULT '0',
  `payouts_enabled` tinyint(1) DEFAULT '0',
  `onboarding_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `requirements` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `stripe_account_id` (`stripe_account_id`),
  KEY `idx_user_stripe` (`user_id`),
  KEY `idx_stripe_account` (`stripe_account_id`),
  KEY `idx_account_status` (`status`),
  CONSTRAINT `user_stripe_accounts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Comptes Stripe Connect pour les utilisateurs transporteurs';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_tokens`
--

DROP TABLE IF EXISTS `user_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_tokens` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `token` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('refresh','access','password_reset') COLLATE utf8mb4_unicode_ci NOT NULL,
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
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `user_unread_notifications`
--

DROP TABLE IF EXISTS `user_unread_notifications`;
/*!50001 DROP VIEW IF EXISTS `user_unread_notifications`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `user_unread_notifications` AS SELECT 
 1 AS `user_id`,
 1 AS `unread_count`,
 1 AS `critical_count`,
 1 AS `high_count`,
 1 AS `latest_notification`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `uuid` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password_hash` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gender` enum('male','female','other') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `nationality` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bio` text COLLATE utf8mb4_unicode_ci,
  `website` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profession` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `company` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_line1` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address_line2` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state_province` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `postal_code` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `preferred_language` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT 'fr',
  `timezone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'Europe/Paris',
  `emergency_contact_name` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emergency_contact_phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emergency_contact_relation` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `login_method` enum('email','phone','social') COLLATE utf8mb4_unicode_ci DEFAULT 'email',
  `two_factor_enabled` tinyint(1) DEFAULT '0',
  `newsletter_subscribed` tinyint(1) DEFAULT '1',
  `marketing_emails` tinyint(1) DEFAULT '0',
  `profile_visibility` enum('public','private','friends_only') COLLATE utf8mb4_unicode_ci DEFAULT 'public',
  `is_verified` tinyint(1) DEFAULT '0',
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `stripe_setup_completed` tinyint(1) DEFAULT '0',
  `stripe_onboarding_completed_at` timestamp NULL DEFAULT NULL,
  `phone_verified_at` timestamp NULL DEFAULT NULL,
  `profile_picture` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('active','inactive','suspended') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `role` enum('user','admin','moderator') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `last_login_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `social_provider` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'google, facebook, apple',
  `social_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'ID from social provider',
  `provider_data` json DEFAULT NULL COMMENT 'Additional data from provider',
  `deleted_at` timestamp NULL DEFAULT NULL,
  `publication_restricted_until` datetime DEFAULT NULL COMMENT 'Restriction de publication jusqu''à',
  `reliability_score` int DEFAULT '100' COMMENT 'Score de fiabilité (0-100)',
  `user_type` enum('new','confirmed','expert') COLLATE utf8mb4_unicode_ci DEFAULT 'new' COMMENT 'Type d''utilisateur basé sur l''expérience',
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
  KEY `idx_users_reliability` (`reliability_score`,`user_type`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Table des utilisateurs avec système de rôles';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary view structure for view `users_with_stripe_status`
--

DROP TABLE IF EXISTS `users_with_stripe_status`;
/*!50001 DROP VIEW IF EXISTS `users_with_stripe_status`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `users_with_stripe_status` AS SELECT 
 1 AS `id`,
 1 AS `email`,
 1 AS `first_name`,
 1 AS `last_name`,
 1 AS `stripe_setup_completed`,
 1 AS `stripe_onboarding_completed_at`,
 1 AS `stripe_account_id`,
 1 AS `stripe_status`,
 1 AS `charges_enabled`,
 1 AS `payouts_enabled`,
 1 AS `details_submitted`,
 1 AS `transaction_readiness`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `verification_codes`
--

DROP TABLE IF EXISTS `verification_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `verification_codes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `booking_id` int DEFAULT NULL,
  `code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('phone_verification','email_verification','password_reset','pickup_code','delivery_code') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'kiloshare'
--
/*!50003 DROP PROCEDURE IF EXISTS `CalculateUserRating` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `CalculateUserRating`(IN target_user_id INT)
BEGIN
    DECLARE total_count INT DEFAULT 0;
    DECLARE avg_rating DECIMAL(3,2) DEFAULT 0.00;
    DECLARE traveler_count INT DEFAULT 0;
    DECLARE traveler_rating DECIMAL(3,2) DEFAULT 0.00;
    DECLARE sender_count INT DEFAULT 0;
    DECLARE sender_rating DECIMAL(3,2) DEFAULT 0.00;
    
    -- Calcul des stats générales
    SELECT COUNT(*), COALESCE(AVG(rating), 0)
    INTO total_count, avg_rating
    FROM reviews r
    WHERE r.reviewed_id = target_user_id AND r.is_visible = TRUE;
    
    -- Calcul des stats en tant que voyageur (celui qui transporte)
    SELECT COUNT(*), COALESCE(AVG(r.rating), 0)
    INTO traveler_count, traveler_rating
    FROM reviews r
    JOIN bookings b ON r.booking_id = b.id
    JOIN trips t ON b.trip_id = t.id
    WHERE r.reviewed_id = target_user_id 
    AND t.user_id = target_user_id -- L'utilisateur est le propriétaire du voyage
    AND r.is_visible = TRUE;
    
    -- Calcul des stats en tant qu'expéditeur
    SELECT COUNT(*), COALESCE(AVG(r.rating), 0)
    INTO sender_count, sender_rating
    FROM reviews r
    JOIN bookings b ON r.booking_id = b.id
    WHERE r.reviewed_id = target_user_id 
    AND b.user_id = target_user_id -- L'utilisateur est celui qui a booké
    AND r.is_visible = TRUE;
    
    -- Mise à jour ou insertion dans user_ratings
    INSERT INTO user_ratings (
        user_id, average_rating, total_reviews,
        as_traveler_rating, as_traveler_count,
        as_sender_rating, as_sender_count,
        last_calculated_at
    ) VALUES (
        target_user_id, avg_rating, total_count,
        traveler_rating, traveler_count,
        sender_rating, sender_count,
        NOW()
    ) ON DUPLICATE KEY UPDATE
        average_rating = avg_rating,
        total_reviews = total_count,
        as_traveler_rating = traveler_rating,
        as_traveler_count = traveler_count,
        as_sender_rating = sender_rating,
        as_sender_count = sender_count,
        last_calculated_at = NOW();
        
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `CheckCloudinaryQuotas` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `CheckCloudinaryQuotas`()
BEGIN
    DECLARE storage_used BIGINT DEFAULT 0;
    DECLARE bandwidth_used BIGINT DEFAULT 0;
    DECLARE storage_percentage DECIMAL(5,2) DEFAULT 0;
    DECLARE bandwidth_percentage DECIMAL(5,2) DEFAULT 0;
    
    -- Calculer l'usage actuel du stockage
    SELECT COALESCE(SUM(file_size), 0) INTO storage_used 
    FROM image_uploads 
    WHERE deleted_at IS NULL;
    
    -- Calculer l'usage actuel de la bande passante (approximation basée sur les downloads)
    SELECT COALESCE(SUM(file_size * download_count), 0) INTO bandwidth_used 
    FROM image_uploads 
    WHERE deleted_at IS NULL 
    AND MONTH(last_accessed_at) = MONTH(NOW()) 
    AND YEAR(last_accessed_at) = YEAR(NOW());
    
    -- Calculer les pourcentages
    SET storage_percentage = (storage_used / 26843545600) * 100;
    SET bandwidth_percentage = (bandwidth_used / 26843545600) * 100;
    
    -- Déclencher des alertes selon les seuils
    IF storage_percentage >= 95 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message, recommended_actions)
        VALUES ('storage_critical', 'emergency', storage_used, bandwidth_used, 
                'Quota de stockage critique (95%+)', 
                CONCAT('Le stockage Cloudinary a atteint ', ROUND(storage_percentage, 2), '% de la limite.'),
                '["Activer le nettoyage d\'urgence", "Supprimer les images temporaires", "Augmenter la compression"]');
                
    ELSEIF storage_percentage >= 85 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message, recommended_actions)
        VALUES ('storage_warning', 'critical', storage_used, bandwidth_used,
                'Quota de stockage élevé (85%+)', 
                CONCAT('Le stockage Cloudinary a atteint ', ROUND(storage_percentage, 2), '% de la limite.'),
                '["Programmer le nettoyage", "Réviser les règles de rétention"]');
                
    ELSEIF storage_percentage >= 70 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message)
        VALUES ('storage_warning', 'warning', storage_used, bandwidth_used,
                'Quota de stockage modéré (70%+)', 
                CONCAT('Le stockage Cloudinary a atteint ', ROUND(storage_percentage, 2), '% de la limite.'));
    END IF;
    
    -- Alertes similaires pour la bande passante
    IF bandwidth_percentage >= 95 THEN
        INSERT INTO cloudinary_alerts (alert_type, alert_level, current_storage_usage, current_bandwidth_usage, title, message, recommended_actions)
        VALUES ('bandwidth_critical', 'emergency', storage_used, bandwidth_used,
                'Quota de bande passante critique (95%+)', 
                CONCAT('La bande passante Cloudinary a atteint ', ROUND(bandwidth_percentage, 2), '% de la limite mensuelle.'),
                '["Réduire la qualité des images", "Implémenter plus de cache", "Optimiser les transformations"]');
    END IF;
    
    -- Mettre à jour les statistiques du jour
    INSERT INTO cloudinary_usage_stats (date, storage_used, bandwidth_used)
    VALUES (CURDATE(), storage_used, bandwidth_used)
    ON DUPLICATE KEY UPDATE
        storage_used = VALUES(storage_used),
        bandwidth_used = VALUES(bandwidth_used),
        updated_at = NOW();
        
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `CleanupOldNotifications` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `CleanupOldNotifications`()
BEGIN
    DECLARE rows_affected INT DEFAULT 0;
    
    -- Supprimer les notifications expirées
    DELETE FROM notifications 
    WHERE expires_at IS NOT NULL 
      AND expires_at < NOW() 
      AND deleted_at IS NULL;
    
    SET rows_affected = ROW_COUNT();
    
    -- Marquer comme supprimées les notifications lues de plus de 30 jours
    UPDATE notifications 
    SET deleted_at = NOW() 
    WHERE is_read = TRUE 
      AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
      AND deleted_at IS NULL;
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    -- Supprimer les logs de plus de 90 jours (sauf les erreurs)
    DELETE FROM notification_logs 
    WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY)
      AND status != 'failed';
    
    SET rows_affected = rows_affected + ROW_COUNT();
    
    SELECT CONCAT('Cleaned up ', rows_affected, ' records') as result;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `cleanup_expired_trips` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `cleanup_expired_trips`()
BEGIN
    -- Marquer comme expirées les annonces dont la date est passée
    UPDATE trips 
    SET status = 'expired',
        expired_at = NOW()
    WHERE status = 'active' 
      AND departure_date < NOW()
      AND booking_count = 0
      AND auto_expire = TRUE;
      
    -- Archiver les annonces expirées depuis plus de 30 jours
    UPDATE trips
    SET archived_at = NOW()
    WHERE status = 'expired'
      AND expired_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
      AND archived_at IS NULL;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Final view structure for view `active_trips_overview`
--

/*!50001 DROP VIEW IF EXISTS `active_trips_overview`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `active_trips_overview` AS select `t`.`id` AS `id`,`t`.`uuid` AS `uuid`,`t`.`user_id` AS `user_id`,`t`.`departure_city` AS `departure_city`,`t`.`departure_country` AS `departure_country`,`t`.`departure_airport_code` AS `departure_airport_code`,`t`.`departure_date` AS `departure_date`,`t`.`arrival_city` AS `arrival_city`,`t`.`arrival_country` AS `arrival_country`,`t`.`arrival_airport_code` AS `arrival_airport_code`,`t`.`arrival_date` AS `arrival_date`,`t`.`available_weight_kg` AS `available_weight_kg`,`t`.`price_per_kg` AS `price_per_kg`,`t`.`currency` AS `currency`,`t`.`flight_number` AS `flight_number`,`t`.`airline` AS `airline`,`t`.`ticket_verified` AS `ticket_verified`,`t`.`ticket_verification_date` AS `ticket_verification_date`,`t`.`status` AS `status`,`t`.`view_count` AS `view_count`,`t`.`booking_count` AS `booking_count`,`t`.`description` AS `description`,`t`.`special_notes` AS `special_notes`,`t`.`created_at` AS `created_at`,`t`.`updated_at` AS `updated_at`,`t`.`published_at` AS `published_at`,`t`.`paused_at` AS `paused_at`,`t`.`cancelled_at` AS `cancelled_at`,`t`.`archived_at` AS `archived_at`,`t`.`expired_at` AS `expired_at`,`t`.`rejected_at` AS `rejected_at`,`t`.`completed_at` AS `completed_at`,`t`.`rejection_reason` AS `rejection_reason`,`t`.`rejection_details` AS `rejection_details`,`t`.`cancellation_reason` AS `cancellation_reason`,`t`.`cancellation_details` AS `cancellation_details`,`t`.`pause_reason` AS `pause_reason`,`t`.`auto_approved` AS `auto_approved`,`t`.`moderated_by` AS `moderated_by`,`t`.`moderation_notes` AS `moderation_notes`,`t`.`trust_score_at_creation` AS `trust_score_at_creation`,`t`.`requires_manual_review` AS `requires_manual_review`,`t`.`review_priority` AS `review_priority`,`t`.`share_count` AS `share_count`,`t`.`favorite_count` AS `favorite_count`,`t`.`report_count` AS `report_count`,`t`.`duplicate_count` AS `duplicate_count`,`t`.`edit_count` AS `edit_count`,`t`.`total_booked_weight` AS `total_booked_weight`,`t`.`remaining_weight` AS `remaining_weight`,`t`.`is_urgent` AS `is_urgent`,`t`.`is_featured` AS `is_featured`,`t`.`is_verified` AS `is_verified`,`t`.`auto_expire` AS `auto_expire`,`t`.`allow_partial_booking` AS `allow_partial_booking`,`t`.`instant_booking` AS `instant_booking`,`t`.`visibility` AS `visibility`,`t`.`min_user_rating` AS `min_user_rating`,`t`.`min_user_trips` AS `min_user_trips`,`t`.`blocked_users` AS `blocked_users`,`t`.`slug` AS `slug`,`t`.`meta_title` AS `meta_title`,`t`.`meta_description` AS `meta_description`,`t`.`share_token` AS `share_token`,`t`.`version` AS `version`,`t`.`last_major_edit` AS `last_major_edit`,`t`.`original_trip_id` AS `original_trip_id`,`u`.`first_name` AS `first_name`,`u`.`last_name` AS `last_name`,`u`.`profile_picture` AS `profile_picture`,timestampdiff(HOUR,now(),`t`.`departure_date`) AS `hours_until_departure`,((`t`.`total_booked_weight` / `t`.`available_weight_kg`) * 100) AS `booking_percentage` from (`trips` `t` join `users` `u` on((`t`.`user_id` = `u`.`id`))) where ((`t`.`status` = 'active') and (`t`.`departure_date` > now())) order by `t`.`departure_date` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `booking_summary`
--

/*!50001 DROP VIEW IF EXISTS `booking_summary`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `booking_summary` AS select `b`.`id` AS `id`,`b`.`uuid` AS `uuid`,`b`.`status` AS `status`,`b`.`package_description` AS `package_description`,`b`.`weight_kg` AS `weight_kg`,`b`.`final_price` AS `final_price`,`b`.`commission_amount` AS `commission_amount`,`t_sender`.`email` AS `sender_email`,`t_receiver`.`email` AS `receiver_email`,`tr`.`departure_city` AS `departure_city`,`tr`.`arrival_city` AS `arrival_city`,`b`.`created_at` AS `created_at` from (((`bookings` `b` left join `users` `t_sender` on((`b`.`sender_id` = `t_sender`.`id`))) left join `users` `t_receiver` on((`b`.`receiver_id` = `t_receiver`.`id`))) left join `trips` `tr` on((`b`.`trip_id` = `tr`.`id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `notification_stats_by_channel`
--

/*!50001 DROP VIEW IF EXISTS `notification_stats_by_channel`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `notification_stats_by_channel` AS select `notification_logs`.`channel` AS `channel`,cast(`notification_logs`.`sent_at` as date) AS `date`,count(0) AS `total_sent`,count((case when (`notification_logs`.`status` = 'delivered') then 1 end)) AS `delivered`,count((case when (`notification_logs`.`status` = 'opened') then 1 end)) AS `opened`,count((case when (`notification_logs`.`status` = 'failed') then 1 end)) AS `failed`,round(((count((case when (`notification_logs`.`status` = 'delivered') then 1 end)) * 100.0) / count(0)),2) AS `delivery_rate`,round(((count((case when (`notification_logs`.`status` = 'opened') then 1 end)) * 100.0) / count((case when (`notification_logs`.`status` = 'delivered') then 1 end))),2) AS `open_rate` from `notification_logs` where (`notification_logs`.`sent_at` >= (now() - interval 30 day)) group by `notification_logs`.`channel`,cast(`notification_logs`.`sent_at` as date) order by `date` desc,`notification_logs`.`channel` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `trip_status_summary`
--

/*!50001 DROP VIEW IF EXISTS `trip_status_summary`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `trip_status_summary` AS select `trips`.`user_id` AS `user_id`,`trips`.`status` AS `status`,count(0) AS `count`,sum(`trips`.`view_count`) AS `total_views`,sum(`trips`.`booking_count`) AS `total_bookings`,avg(`trips`.`price_per_kg`) AS `avg_price` from `trips` where (`trips`.`archived_at` is null) group by `trips`.`user_id`,`trips`.`status` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `user_rating_summary`
--

/*!50001 DROP VIEW IF EXISTS `user_rating_summary`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `user_rating_summary` AS select `ur`.`user_id` AS `user_id`,`u`.`first_name` AS `first_name`,`u`.`last_name` AS `last_name`,`ur`.`average_rating` AS `average_rating`,`ur`.`total_reviews` AS `total_reviews`,`ur`.`as_traveler_rating` AS `as_traveler_rating`,`ur`.`as_traveler_count` AS `as_traveler_count`,`ur`.`as_sender_rating` AS `as_sender_rating`,`ur`.`as_sender_count` AS `as_sender_count`,`ur`.`last_calculated_at` AS `last_calculated_at`,(case when ((`ur`.`average_rating` >= 4.5) and (`ur`.`total_reviews` >= 5)) then 'super_traveler' when ((`ur`.`average_rating` < 2.5) and (`ur`.`total_reviews` >= 3)) then 'suspended' when ((`ur`.`average_rating` < 3.0) and (`ur`.`total_reviews` >= 3)) then 'warning' else 'normal' end) AS `rating_status` from (`user_ratings` `ur` join `users` `u` on((`ur`.`user_id` = `u`.`id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `user_reliability_stats`
--

/*!50001 DROP VIEW IF EXISTS `user_reliability_stats`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `user_reliability_stats` AS select `u`.`id` AS `user_id`,`u`.`first_name` AS `first_name`,`u`.`last_name` AS `last_name`,`u`.`email` AS `email`,`u`.`user_type` AS `user_type`,coalesce(`ur`.`reliability_score`,100) AS `reliability_score`,count(`t`.`id`) AS `total_trips`,count((case when (`t`.`status` = 'completed') then 1 end)) AS `completed_trips`,count((case when (`t`.`status` = 'cancelled') then 1 end)) AS `cancelled_trips`,round((case when (count(`t`.`id`) > 0) then ((count((case when (`t`.`status` = 'completed') then 1 end)) / count(`t`.`id`)) * 100) else 100 end),2) AS `completion_rate`,(select count(0) from `cancellation_attempts` `ca` where ((`ca`.`user_id` = `u`.`id`) and (`ca`.`is_allowed` = true) and (`ca`.`created_at` >= (now() - interval 3 month)))) AS `recent_cancellations`,`u`.`created_at` AS `member_since` from ((`users` `u` left join `user_ratings` `ur` on((`u`.`id` = `ur`.`user_id`))) left join `trips` `t` on((`u`.`id` = `t`.`user_id`))) group by `u`.`id`,`u`.`first_name`,`u`.`last_name`,`u`.`email`,`u`.`user_type`,`ur`.`reliability_score`,`u`.`created_at` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `user_unread_notifications`
--

/*!50001 DROP VIEW IF EXISTS `user_unread_notifications`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `user_unread_notifications` AS select `notifications`.`user_id` AS `user_id`,count(0) AS `unread_count`,count((case when (`notifications`.`priority` = 'critical') then 1 end)) AS `critical_count`,count((case when (`notifications`.`priority` = 'high') then 1 end)) AS `high_count`,max(`notifications`.`created_at`) AS `latest_notification` from `notifications` where ((`notifications`.`is_read` = false) and (`notifications`.`deleted_at` is null) and ((`notifications`.`expires_at` is null) or (`notifications`.`expires_at` > now()))) group by `notifications`.`user_id` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `users_with_stripe_status`
--

/*!50001 DROP VIEW IF EXISTS `users_with_stripe_status`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `users_with_stripe_status` AS select `u`.`id` AS `id`,`u`.`email` AS `email`,`u`.`first_name` AS `first_name`,`u`.`last_name` AS `last_name`,`u`.`stripe_setup_completed` AS `stripe_setup_completed`,`u`.`stripe_onboarding_completed_at` AS `stripe_onboarding_completed_at`,`usa`.`stripe_account_id` AS `stripe_account_id`,`usa`.`status` AS `stripe_status`,`usa`.`charges_enabled` AS `charges_enabled`,`usa`.`payouts_enabled` AS `payouts_enabled`,`usa`.`details_submitted` AS `details_submitted`,(case when ((`usa`.`charges_enabled` = true) and (`usa`.`payouts_enabled` = true)) then 'ready_for_transactions' when (`usa`.`details_submitted` = true) then 'pending_verification' when (`usa`.`stripe_account_id` is not null) then 'onboarding_incomplete' else 'no_account' end) AS `transaction_readiness` from (`users` `u` left join `user_stripe_accounts` `usa` on((`u`.`id` = `usa`.`user_id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-09-22 16:42:25
