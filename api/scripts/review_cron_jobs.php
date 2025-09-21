<?php

declare(strict_types=1);

/**
 * Script CRON pour la gestion automatique des reviews KiloShare
 * 
 * Tâches quotidiennes:
 * 1. Calculer les ratings utilisateurs
 * 2. Publier automatiquement les reviews après 14 jours
 * 3. Envoyer les notifications de rappel (J+1 et J+3)
 * 
 * Usage:
 * php scripts/review_cron_jobs.php [task]
 * 
 * Tasks disponibles:
 * - calculate-ratings: Recalculer les ratings utilisateurs
 * - auto-publish: Publier automatiquement les reviews après 14 jours
 * - send-reminders: Envoyer les rappels de review
 * - full: Exécuter toutes les tâches (défaut)
 */

require_once __DIR__ . '/../vendor/autoload.php';

use KiloShare\Utils\Database;
use KiloShare\Models\ReviewModel;
use KiloShare\Utils\Logger;

class ReviewCronJobsManager
{
    private PDO $db;
    private ReviewModel $reviewModel;
    private array $stats = [];

    public function __construct()
    {
        $this->db = Database::getConnection();
        $this->reviewModel = new ReviewModel($this->db);
        $this->stats = [
            'ratings_calculated' => 0,
            'reviews_published' => 0,
            'reminders_sent' => 0,
            'errors' => []
        ];
    }

    /**
     * Exécuter toutes les tâches cron
     */
    public function runAll(): void
    {
        echo "[" . date('Y-m-d H:i:s') . "] Démarrage des tâches cron reviews\n";
        
        $startTime = microtime(true);
        
        try {
            $this->calculateUserRatings();
            $this->autoPublishReviews();
            $this->sendReviewReminders();
            
            $executionTime = round(microtime(true) - $startTime, 2);
            
            echo "\n=== RÉSUMÉ D'EXÉCUTION ===\n";
            echo "Durée: {$executionTime}s\n";
            echo "Ratings calculés: {$this->stats['ratings_calculated']}\n";
            echo "Reviews publiées: {$this->stats['reviews_published']}\n";
            echo "Rappels envoyés: {$this->stats['reminders_sent']}\n";
            echo "Erreurs: " . count($this->stats['errors']) . "\n";
            
            if (!empty($this->stats['errors'])) {
                echo "\nERREURS:\n";
                foreach ($this->stats['errors'] as $error) {
                    echo "- $error\n";
                }
            }
            
        } catch (\Exception $e) {
            echo "ERREUR CRITIQUE: " . $e->getMessage() . "\n";
            $this->stats['errors'][] = $e->getMessage();
        }
        
        echo "[" . date('Y-m-d H:i:s') . "] Fin des tâches cron reviews\n";
    }

    /**
     * Calculer/recalculer les ratings de tous les utilisateurs
     */
    public function calculateUserRatings(): void
    {
        echo "\n--- Calcul des ratings utilisateurs ---\n";
        
        try {
            // Récupérer tous les utilisateurs ayant des reviews visibles
            $sql = "SELECT DISTINCT reviewed_id FROM reviews WHERE is_visible = TRUE";
            $stmt = $this->db->prepare($sql);
            $stmt->execute();
            $userIds = $stmt->fetchAll(PDO::FETCH_COLUMN);
            
            echo "Utilisateurs à traiter: " . count($userIds) . "\n";
            
            foreach ($userIds as $userId) {
                try {
                    // Appeler la procédure stockée pour calculer les ratings
                    $callSql = "CALL CalculateUserRating(:user_id)";
                    $callStmt = $this->db->prepare($callSql);
                    $callStmt->execute(['user_id' => $userId]);
                    
                    $this->stats['ratings_calculated']++;
                    
                    if ($this->stats['ratings_calculated'] % 50 == 0) {
                        echo "Traité: {$this->stats['ratings_calculated']} utilisateurs\n";
                    }
                    
                } catch (\Exception $e) {
                    $error = "Erreur calcul rating utilisateur $userId: " . $e->getMessage();
                    echo "$error\n";
                    $this->stats['errors'][] = $error;
                }
            }
            
            echo "✅ Calcul des ratings terminé: {$this->stats['ratings_calculated']} utilisateurs\n";
            
        } catch (\Exception $e) {
            $error = "Erreur calcul des ratings: " . $e->getMessage();
            echo "❌ $error\n";
            $this->stats['errors'][] = $error;
        }
    }

    /**
     * Publier automatiquement les reviews après 14 jours
     */
    public function autoPublishReviews(): void
    {
        echo "\n--- Publication automatique des reviews ---\n";
        
        try {
            $publishedCount = $this->reviewModel->autoPublishPendingReviews();
            $this->stats['reviews_published'] = $publishedCount;
            
            echo "✅ Reviews publiées automatiquement: $publishedCount\n";
            
        } catch (\Exception $e) {
            $error = "Erreur publication automatique: " . $e->getMessage();
            echo "❌ $error\n";
            $this->stats['errors'][] = $error;
        }
    }

    /**
     * Envoyer les rappels de review (J+1 et J+3)
     */
    public function sendReviewReminders(): void
    {
        echo "\n--- Envoi des rappels de review ---\n";
        
        try {
            // Récupérer les bookings éligibles pour rappels
            $eligibleBookings = $this->reviewModel->getEligibleBookingsForReview();
            $remindersJ3 = $this->reviewModel->getBookingsNeedingReminders();
            
            echo "Bookings éligibles J+1: " . count($eligibleBookings) . "\n";
            echo "Bookings éligibles J+3: " . count($remindersJ3) . "\n";
            
            // Rappels J+1 (première notification)
            foreach ($eligibleBookings as $booking) {
                $this->sendInitialReminder($booking);
            }
            
            // Rappels J+3 (deuxième notification)
            foreach ($remindersJ3 as $booking) {
                $this->sendSecondReminder($booking);
            }
            
            echo "✅ Rappels envoyés: {$this->stats['reminders_sent']}\n";
            
        } catch (\Exception $e) {
            $error = "Erreur envoi rappels: " . $e->getMessage();
            echo "❌ $error\n";
            $this->stats['errors'][] = $error;
        }
    }

    /**
     * Envoyer le rappel initial (J+1)
     */
    private function sendInitialReminder(array $booking): void
    {
        try {
            $bookingId = (int) $booking['booking_id'];
            $senderId = (int) $booking['sender_id'];
            $travelerId = (int) $booking['traveler_id'];
            
            // Vérifier si le sender doit être rappelé
            if (!$this->reviewModel->hasReminderBeenSent($bookingId, $senderId, 'initial')) {
                $existingReview = $this->reviewModel->getByBookingAndReviewer($bookingId, $senderId);
                if (!$existingReview) {
                    // TODO: Intégrer avec le système de notifications
                    $this->sendNotificationToUser($senderId, [
                        'type' => 'review_reminder',
                        'title' => 'Comment s\'est passée la livraison ?',
                        'message' => "N'oubliez pas d'évaluer votre livraison {$booking['departure_city']} → {$booking['arrival_city']}",
                        'booking_id' => $bookingId
                    ]);
                    
                    $this->reviewModel->recordReviewReminder($bookingId, $senderId, 'initial');
                    $this->stats['reminders_sent']++;
                }
            }
            
            // Vérifier si le traveler doit être rappelé
            if (!$this->reviewModel->hasReminderBeenSent($bookingId, $travelerId, 'initial')) {
                $existingReview = $this->reviewModel->getByBookingAndReviewer($bookingId, $travelerId);
                if (!$existingReview) {
                    $this->sendNotificationToUser($travelerId, [
                        'type' => 'review_reminder',
                        'title' => 'Comment s\'est passée la livraison ?',
                        'message' => "N'oubliez pas d'évaluer la livraison {$booking['departure_city']} → {$booking['arrival_city']}",
                        'booking_id' => $bookingId
                    ]);
                    
                    $this->reviewModel->recordReviewReminder($bookingId, $travelerId, 'initial');
                    $this->stats['reminders_sent']++;
                }
            }
            
        } catch (\Exception $e) {
            $error = "Erreur rappel initial booking {$booking['booking_id']}: " . $e->getMessage();
            $this->stats['errors'][] = $error;
        }
    }

    /**
     * Envoyer le rappel J+3
     */
    private function sendSecondReminder(array $booking): void
    {
        try {
            $bookingId = (int) $booking['booking_id'];
            $senderId = (int) $booking['sender_id'];
            $travelerId = (int) $booking['traveler_id'];
            
            // Rappel J+3 pour le sender
            if (!$this->reviewModel->hasReminderBeenSent($bookingId, $senderId, 'reminder_day3')) {
                $existingReview = $this->reviewModel->getByBookingAndReviewer($bookingId, $senderId);
                if (!$existingReview) {
                    $this->sendNotificationToUser($senderId, [
                        'type' => 'review_reminder_urgent',
                        'title' => 'Dernière chance d\'évaluer',
                        'message' => "Votre évaluation sera bientôt publiée automatiquement. Donnez votre avis sur {$booking['departure_city']} → {$booking['arrival_city']}",
                        'booking_id' => $bookingId
                    ]);
                    
                    $this->reviewModel->recordReviewReminder($bookingId, $senderId, 'reminder_day3');
                    $this->stats['reminders_sent']++;
                }
            }
            
            // Rappel J+3 pour le traveler
            if (!$this->reviewModel->hasReminderBeenSent($bookingId, $travelerId, 'reminder_day3')) {
                $existingReview = $this->reviewModel->getByBookingAndReviewer($bookingId, $travelerId);
                if (!$existingReview) {
                    $this->sendNotificationToUser($travelerId, [
                        'type' => 'review_reminder_urgent',
                        'title' => 'Dernière chance d\'évaluer',
                        'message' => "Votre évaluation sera bientôt publiée automatiquement. Donnez votre avis sur {$booking['departure_city']} → {$booking['arrival_city']}",
                        'booking_id' => $bookingId
                    ]);
                    
                    $this->reviewModel->recordReviewReminder($bookingId, $travelerId, 'reminder_day3');
                    $this->stats['reminders_sent']++;
                }
            }
            
        } catch (\Exception $e) {
            $error = "Erreur rappel J+3 booking {$booking['booking_id']}: " . $e->getMessage();
            $this->stats['errors'][] = $error;
        }
    }

    /**
     * Envoyer une notification à un utilisateur
     * TODO: Intégrer avec le vrai système de notifications
     */
    private function sendNotificationToUser(int $userId, array $notificationData): void
    {
        try {
            // Pour l'instant, on simule l'envoi de notification
            // TODO: Intégrer avec NotificationModel et FCM
            
            echo "📧 Notification envoyée à l'utilisateur $userId: {$notificationData['title']}\n";
            
        } catch (\Exception $e) {
            $error = "Erreur envoi notification utilisateur $userId: " . $e->getMessage();
            $this->stats['errors'][] = $error;
        }
    }

    /**
     * Nettoyer les anciennes données de rappels (optionnel)
     */
    public function cleanupOldReminders(): void
    {
        try {
            // Supprimer les rappels de plus de 30 jours
            $sql = "DELETE FROM review_reminders WHERE sent_at < DATE_SUB(NOW(), INTERVAL 30 DAY)";
            $stmt = $this->db->prepare($sql);
            $stmt->execute();
            
            $deletedCount = $stmt->rowCount();
            echo "🧹 Anciens rappels supprimés: $deletedCount\n";
            
        } catch (\Exception $e) {
            $error = "Erreur nettoyage rappels: " . $e->getMessage();
            echo "❌ $error\n";
            $this->stats['errors'][] = $error;
        }
    }
}

// === EXÉCUTION DU SCRIPT ===

if (php_sapi_name() !== 'cli') {
    die('Ce script ne peut être exécuté qu\'en ligne de commande');
}

$task = $argv[1] ?? 'full';
$cronManager = new ReviewCronJobsManager();

switch ($task) {
    case 'calculate-ratings':
        $cronManager->calculateUserRatings();
        break;
    
    case 'auto-publish':
        $cronManager->autoPublishReviews();
        break;
    
    case 'send-reminders':
        $cronManager->sendReviewReminders();
        break;
    
    case 'cleanup':
        $cronManager->cleanupOldReminders();
        break;
    
    case 'full':
    default:
        $cronManager->runAll();
        break;
}

echo "\n";