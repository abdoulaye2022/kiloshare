-- Migration pour ajouter le champ role aux utilisateurs
-- Exécuter cette migration sur la base de données

ALTER TABLE users 
ADD COLUMN role ENUM('user', 'admin', 'moderator') NOT NULL DEFAULT 'user' AFTER status;

-- Optionnel : Créer un utilisateur admin par défaut
-- UPDATE users SET role = 'admin' WHERE email = 'admin@kiloshare.com';

-- Index pour optimiser les requêtes par rôle
CREATE INDEX idx_users_role ON users(role);

-- Commentaires de la table mise à jour
ALTER TABLE users COMMENT = 'Table des utilisateurs avec système de rôles';