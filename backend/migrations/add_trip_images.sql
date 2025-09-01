-- Migration to add trip images functionality
-- Date: 2025-01-20

-- Create table for trip images
CREATE TABLE IF NOT EXISTS trip_images (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trip_id INT NOT NULL,
    image_path VARCHAR(500) NOT NULL,
    image_name VARCHAR(255) NOT NULL,
    file_size INT NOT NULL COMMENT 'File size in bytes',
    mime_type VARCHAR(100) NOT NULL,
    upload_order TINYINT NOT NULL DEFAULT 1 COMMENT 'Order of images (1 or 2)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign key constraint
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
    
    -- Ensure only 2 images per trip
    UNIQUE KEY unique_trip_order (trip_id, upload_order),
    
    -- Index for faster queries
    INDEX idx_trip_id (trip_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add image-related columns to trips table
ALTER TABLE trips 
ADD COLUMN has_images BOOLEAN DEFAULT FALSE COMMENT 'Quick flag to check if trip has images',
ADD COLUMN image_count TINYINT DEFAULT 0 COMMENT 'Number of images (0-2)';

-- Create upload directory structure (to be created by PHP)
-- /backend/uploads/trips/{trip_id}/
-- Each image will be renamed to: {trip_id}_{order}_{timestamp}.{extension}

-- Update existing trips to set default values
UPDATE trips SET has_images = FALSE, image_count = 0 WHERE has_images IS NULL;