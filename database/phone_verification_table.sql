-- Table pour gérer les codes de vérification SMS
CREATE TABLE IF NOT EXISTS phone_verifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL,
    code VARCHAR(6) NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    expires_at DATETIME NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    used_at DATETIME NULL,
    INDEX idx_phone_code (phone_number, code),
    INDEX idx_expires (expires_at),
    INDEX idx_created (created_at)
);