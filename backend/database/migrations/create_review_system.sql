-- Migration pour créer le système d'évaluation simple KiloShare
-- Création des tables reviews et user_ratings

-- Table des reviews individuelles
CREATE TABLE reviews (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL UNIQUE, -- Une seule review par transaction
    reviewer_id INT NOT NULL, -- Qui donne la note
    reviewed_id INT NOT NULL, -- Qui reçoit la note
    rating TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5), -- 1-5 étoiles
    comment TEXT NULL DEFAULT NULL, -- Optionnel, max 500 caractères via validation app
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_visible BOOLEAN DEFAULT FALSE, -- true après review mutuelle ou 14 jours
    auto_published_at TIMESTAMP NULL DEFAULT NULL, -- Quand la review a été auto-publiée (J+14)
    
    -- Index et contraintes
    INDEX idx_booking_id (booking_id),
    INDEX idx_reviewer_id (reviewer_id),
    INDEX idx_reviewed_id (reviewed_id),
    INDEX idx_is_visible (is_visible),
    INDEX idx_created_at (created_at),
    
    -- Contraintes foreign keys
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reviewed_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- Contraintes métier
    CHECK (reviewer_id != reviewed_id), -- Pas d'auto-évaluation
    CHECK (CHAR_LENGTH(comment) <= 500) -- Limite commentaire
);

-- Table d'agrégation des ratings utilisateurs
CREATE TABLE user_ratings (
    user_id INT PRIMARY KEY,
    average_rating DECIMAL(3,2) DEFAULT 0.00, -- Moyenne générale sur 5
    total_reviews INT DEFAULT 0, -- Nombre total de reviews reçues
    as_traveler_rating DECIMAL(3,2) DEFAULT 0.00, -- Moyenne en tant que voyageur
    as_traveler_count INT DEFAULT 0, -- Nombre de reviews en tant que voyageur
    as_sender_rating DECIMAL(3,2) DEFAULT 0.00, -- Moyenne en tant qu'expéditeur
    as_sender_count INT DEFAULT 0, -- Nombre de reviews en tant qu'expéditeur
    last_calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Index pour recherches
    INDEX idx_average_rating (average_rating DESC),
    INDEX idx_last_calculated (last_calculated_at),
    
    -- Contrainte foreign key
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Table pour tracker les notifications de review envoyées
CREATE TABLE review_reminders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    booking_id INT NOT NULL,
    user_id INT NOT NULL, -- L'utilisateur à qui on doit rappeler
    reminder_type ENUM('initial', 'reminder_day3') NOT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Index
    INDEX idx_booking_user (booking_id, user_id),
    INDEX idx_sent_at (sent_at),
    
    -- Contraintes
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- Éviter les doublons de rappels
    UNIQUE KEY unique_reminder (booking_id, user_id, reminder_type)
);

-- Vue pour récupérer facilement les stats utilisateur avec les reviews récentes
CREATE VIEW user_rating_summary AS
SELECT 
    ur.user_id,
    u.first_name,
    u.last_name,
    ur.average_rating,
    ur.total_reviews,
    ur.as_traveler_rating,
    ur.as_traveler_count,
    ur.as_sender_rating,
    ur.as_sender_count,
    ur.last_calculated_at,
    -- Badge automatique basé sur la note
    CASE 
        WHEN ur.average_rating >= 4.5 AND ur.total_reviews >= 5 THEN 'super_traveler'
        WHEN ur.average_rating < 2.5 AND ur.total_reviews >= 3 THEN 'suspended'
        WHEN ur.average_rating < 3.0 AND ur.total_reviews >= 3 THEN 'warning'
        ELSE 'normal'
    END AS rating_status
FROM user_ratings ur
JOIN users u ON ur.user_id = u.id;

-- Procédure stockée pour calculer les ratings d'un utilisateur
DELIMITER $$
CREATE PROCEDURE CalculateUserRating(IN target_user_id INT)
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
        
END$$
DELIMITER ;

-- Trigger pour auto-calculer les ratings quand une review devient visible
DELIMITER $$
CREATE TRIGGER after_review_visible_update
    AFTER UPDATE ON reviews
    FOR EACH ROW
BEGIN
    IF NEW.is_visible = TRUE AND OLD.is_visible = FALSE THEN
        CALL CalculateUserRating(NEW.reviewed_id);
    END IF;
END$$
DELIMITER ;

-- Trigger pour auto-calculer les ratings lors de l'insertion d'une review visible
DELIMITER $$
CREATE TRIGGER after_review_insert
    AFTER INSERT ON reviews
    FOR EACH ROW
BEGIN
    IF NEW.is_visible = TRUE THEN
        CALL CalculateUserRating(NEW.reviewed_id);
    END IF;
END$$
DELIMITER ;

-- Insertion des ratings par défaut pour tous les utilisateurs existants
INSERT INTO user_ratings (user_id) 
SELECT id FROM users 
WHERE id NOT IN (SELECT user_id FROM user_ratings);