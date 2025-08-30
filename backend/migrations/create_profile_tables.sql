-- Migration pour créer les tables du module profil et vérification KYC

-- Table des profils utilisateur
CREATE TABLE user_profiles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL UNIQUE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    gender ENUM('male', 'female', 'other'),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    avatar_url VARCHAR(500),
    bio TEXT,
    profession VARCHAR(100),
    company VARCHAR(100),
    website VARCHAR(255),
    is_verified BOOLEAN DEFAULT FALSE,
    verification_level ENUM('none', 'basic', 'advanced', 'premium') DEFAULT 'none',
    trust_score DECIMAL(3,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_verification_level (verification_level),
    INDEX idx_is_verified (is_verified)
);

-- Table des documents de vérification
CREATE TABLE verification_documents (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    document_type ENUM(
        'identity_card', 
        'passport', 
        'driver_license', 
        'proof_of_address', 
        'bank_statement', 
        'utility_bill',
        'selfie_with_id'
    ) NOT NULL,
    document_number VARCHAR(100),
    file_path VARCHAR(500) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_size INT,
    mime_type VARCHAR(100),
    status ENUM('pending', 'approved', 'rejected', 'expired') DEFAULT 'pending',
    verification_notes TEXT,
    expiry_date DATE,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMP NULL,
    verified_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_document_type (document_type),
    INDEX idx_status (status),
    INDEX idx_uploaded_at (uploaded_at)
);

-- Table des badges de confiance
CREATE TABLE trust_badges (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    badge_type ENUM(
        'email_verified',
        'phone_verified', 
        'identity_verified',
        'address_verified',
        'bank_verified',
        'social_media_verified',
        'background_check',
        'premium_member',
        'top_rated',
        'quick_responder'
    ) NOT NULL,
    badge_name VARCHAR(100) NOT NULL,
    badge_description TEXT,
    badge_icon VARCHAR(100),
    badge_color VARCHAR(7), -- Couleur hexadécimale
    is_active BOOLEAN DEFAULT TRUE,
    priority_order INT DEFAULT 0,
    earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    verification_data JSON, -- Données supplémentaires de vérification
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_badge (user_id, badge_type),
    INDEX idx_user_id (user_id),
    INDEX idx_badge_type (badge_type),
    INDEX idx_is_active (is_active),
    INDEX idx_priority_order (priority_order)
);

-- Table des logs de vérification (pour audit)
CREATE TABLE verification_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    action ENUM(
        'profile_created',
        'profile_updated', 
        'document_uploaded',
        'document_approved',
        'document_rejected',
        'badge_awarded',
        'badge_revoked',
        'verification_level_changed'
    ) NOT NULL,
    entity_type ENUM('profile', 'document', 'badge') NOT NULL,
    entity_id INT NOT NULL,
    old_value JSON,
    new_value JSON,
    performed_by INT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (performed_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_entity (entity_type, entity_id),
    INDEX idx_created_at (created_at)
);

-- Insérer quelques badges par défaut
INSERT INTO trust_badges (user_id, badge_type, badge_name, badge_description, badge_icon, badge_color, is_active, priority_order) VALUES
-- Pour l'utilisateur admin (ID 1) comme exemple
(1, 'email_verified', 'Email Vérifié', 'Adresse email confirmée', 'mail-check', '#10B981', TRUE, 1),
(1, 'phone_verified', 'Téléphone Vérifié', 'Numéro de téléphone confirmé', 'phone-check', '#3B82F6', TRUE, 2),
(1, 'premium_member', 'Membre Premium', 'Membre avec compte premium actif', 'crown', '#F59E0B', TRUE, 10);