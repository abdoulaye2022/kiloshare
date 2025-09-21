-- Add user presence tracking for real-time messaging

CREATE TABLE user_presence (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_user (user_id),
    INDEX idx_online (is_online),
    INDEX idx_last_seen (last_seen),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Add Firebase token storage if not exists
CREATE TABLE IF NOT EXISTS user_firebase_tokens (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    token VARCHAR(500) NOT NULL,
    device_type ENUM('web', 'android', 'ios') DEFAULT 'web',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_user_token (user_id, token(255)),
    INDEX idx_user (user_id),
    INDEX idx_last_used (last_used),
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);