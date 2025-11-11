-- Table pour les codes de livraison
CREATE TABLE IF NOT EXISTS delivery_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    code VARCHAR(6) NOT NULL,
    status ENUM('active', 'used', 'expired', 'regenerated') DEFAULT 'active',
    generated_by INT NOT NULL,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP NULL,
    used_by INT NULL,
    delivery_location_lat DECIMAL(10, 8) NULL,
    delivery_location_lng DECIMAL(11, 8) NULL,
    delivery_photo_url VARCHAR(512) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY unique_active_booking (booking_id, status),
    INDEX idx_booking_id (booking_id),
    INDEX idx_code (code),
    INDEX idx_status (status),
    INDEX idx_expires_at (expires_at),

    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (generated_by) REFERENCES users(id),
    FOREIGN KEY (used_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour les tentatives de validation
CREATE TABLE IF NOT EXISTS delivery_code_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_code_id INT NOT NULL,
    attempted_code VARCHAR(6) NOT NULL,
    attempted_by INT NOT NULL,
    success BOOLEAN DEFAULT FALSE,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(512) NULL,

    INDEX idx_delivery_code_id (delivery_code_id),
    INDEX idx_attempted_by (attempted_by),
    INDEX idx_attempted_at (attempted_at),

    FOREIGN KEY (delivery_code_id) REFERENCES delivery_codes(id) ON DELETE CASCADE,
    FOREIGN KEY (attempted_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table pour l'historique des codes (audit trail)
CREATE TABLE IF NOT EXISTS delivery_code_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_code_id INT NOT NULL,
    action ENUM('generated', 'regenerated', 'validated', 'expired', 'cancelled') NOT NULL,
    performed_by INT NOT NULL,
    notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_delivery_code_id (delivery_code_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at),

    FOREIGN KEY (delivery_code_id) REFERENCES delivery_codes(id) ON DELETE CASCADE,
    FOREIGN KEY (performed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ajouter des colonnes à la table bookings (ignorer les erreurs si elles existent déjà)
-- delivery_confirmed_at
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare'
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'delivery_confirmed_at'
);

SET @sql = IF(@col_exists = 0,
    'ALTER TABLE bookings ADD COLUMN delivery_confirmed_at TIMESTAMP NULL',
    'SELECT "Column delivery_confirmed_at already exists" AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- delivery_confirmed_by
SET @col_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'kiloshare'
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'delivery_confirmed_by'
);

SET @sql = IF(@col_exists = 0,
    'ALTER TABLE bookings ADD COLUMN delivery_confirmed_by INT NULL',
    'SELECT "Column delivery_confirmed_by already exists" AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Index
SET @idx_exists = (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'kiloshare'
    AND TABLE_NAME = 'bookings'
    AND INDEX_NAME = 'idx_delivery_confirmed_at'
);

SET @sql = IF(@idx_exists = 0,
    'ALTER TABLE bookings ADD INDEX idx_delivery_confirmed_at (delivery_confirmed_at)',
    'SELECT "Index already exists" AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
