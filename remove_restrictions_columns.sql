-- Script pour supprimer les colonnes de restrictions des annonces
-- À exécuter sur votre base de données KiloShare

-- Sauvegarde des données existantes (optionnel)
-- CREATE TABLE restrictions_backup AS
-- SELECT id, restricted_categories, restricted_items, restriction_notes
-- FROM trips
-- WHERE restricted_categories IS NOT NULL
--    OR restricted_items IS NOT NULL
--    OR restriction_notes IS NOT NULL;

-- Suppression des colonnes de restrictions
ALTER TABLE trips DROP COLUMN IF EXISTS restricted_categories;
ALTER TABLE trips DROP COLUMN IF EXISTS restricted_items;
ALTER TABLE trips DROP COLUMN IF EXISTS restriction_notes;

-- Vérification que les colonnes ont été supprimées
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'trips'
  AND column_name LIKE '%restrict%';

-- Cette requête ne devrait retourner aucun résultat si la suppression a réussi