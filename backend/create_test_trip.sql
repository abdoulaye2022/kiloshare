-- Script pour créer un voyage de test avec l'utilisateur admin
USE kiloshare;

-- Récupérer l'ID de l'utilisateur admin
SET @admin_user_id = (SELECT id FROM users WHERE email = 'admin@gmail.com' LIMIT 1);

-- Créer un voyage de test
INSERT INTO trips (
    uuid,
    user_id,
    title,
    description,
    departure_city,
    departure_country,
    arrival_city,
    arrival_country,
    departure_date,
    arrival_date,
    available_weight_kg,
    price_per_kg,
    currency,
    status,
    created_at,
    updated_at
) VALUES (
    UUID(),
    @admin_user_id,
    'Test Trip - Voyage de démonstration',
    'Voyage de test pour tester l\'upload d\'images. De Montréal à Paris.',
    'Montréal',
    'Canada',
    'Paris',
    'France',
    DATE_ADD(NOW(), INTERVAL 7 DAY),
    DATE_ADD(NOW(), INTERVAL 14 DAY),
    15.0,
    25.00,
    'CAD',
    'active',
    NOW(),
    NOW()
);

-- Afficher le voyage créé
SELECT 
    id,
    uuid,
    title,
    departure_city,
    arrival_city,
    departure_date,
    status,
    'Admin trip created successfully' as message
FROM trips 
WHERE user_id = @admin_user_id 
ORDER BY id DESC 
LIMIT 1;