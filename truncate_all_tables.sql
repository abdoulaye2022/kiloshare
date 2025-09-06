-- Script de truncate de toutes les tables sauf notification_templates
-- Créé le: 2025-09-06
-- ATTENTION: Ce script vide toutes les données des tables
-- Les données seront perdues définitivement

USE kiloshare;

-- Disable foreign key checks temporarily
SET FOREIGN_KEY_CHECKS = 0;

-- Truncate all tables except notification_templates
TRUNCATE TABLE booking_negotiations;
TRUNCATE TABLE bookings;
TRUNCATE TABLE contact_revelations;
TRUNCATE TABLE conversation_participants;
TRUNCATE TABLE conversations;
TRUNCATE TABLE email_verifications;
TRUNCATE TABLE escrow_accounts;
TRUNCATE TABLE message_attachments;
TRUNCATE TABLE message_reads;
TRUNCATE TABLE messages;
TRUNCATE TABLE notifications;
TRUNCATE TABLE password_resets;
TRUNCATE TABLE phone_verifications;
TRUNCATE TABLE review_reminders;
TRUNCATE TABLE reviews;
TRUNCATE TABLE transactions;
TRUNCATE TABLE trip_favorites;
TRUNCATE TABLE trip_images;
TRUNCATE TABLE trip_reports;
TRUNCATE TABLE trips;
TRUNCATE TABLE user_fcm_tokens;
TRUNCATE TABLE user_notification_preferences;
TRUNCATE TABLE user_ratings;
TRUNCATE TABLE user_social_accounts;
TRUNCATE TABLE user_stripe_accounts;
TRUNCATE TABLE user_tokens;
TRUNCATE TABLE users;
TRUNCATE TABLE verification_codes;

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Truncate terminé - toutes les tables vidées sauf notification_templates' as result;