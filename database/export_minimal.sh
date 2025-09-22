#!/bin/bash

# Export minimal - Tables seulement pour hébergeurs très restrictifs
# Usage: ./export_minimal.sh [nom_db] [utilisateur] [mot_de_passe]

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DB_NAME=${1:-kiloshare}
DB_USER=${2:-root}
DB_PASSWORD=$3

echo -e "${BLUE}📦 Export minimal (tables seulement)${NC}"
echo "=================================="

# Demander le mot de passe si non fourni
if [ -z "$DB_PASSWORD" ]; then
    echo -n "Mot de passe MySQL: "
    read -s DB_PASSWORD
    echo
fi

echo -e "${YELLOW}📦 Export des tables uniquement...${NC}"

# Export minimal : tables seulement, pas de triggers/procédures/vues
mysqldump \
  -h localhost \
  -u "$DB_USER" \
  -p"$DB_PASSWORD" \
  --no-data \
  --no-create-info \
  --routines=false \
  --triggers=false \
  --single-transaction \
  --set-gtid-purged=OFF \
  "$DB_NAME" > /dev/null

# Export uniquement la structure des tables
mysqldump \
  -h localhost \
  -u "$DB_USER" \
  -p"$DB_PASSWORD" \
  --no-data \
  --no-create-db \
  --skip-triggers \
  --skip-routines \
  --skip-events \
  --single-transaction \
  --set-gtid-purged=OFF \
  "$DB_NAME" > schema_minimal_temp.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Export des tables réussi${NC}"
else
    echo -e "${RED}❌ Erreur lors de l'export${NC}"
    exit 1
fi

echo -e "${YELLOW}🔧 Nettoyage pour compatibilité maximale...${NC}"

# Nettoyer le fichier
sed -i.bak '
# Supprimer tous les commentaires MySQL dump
/^-- MySQL dump/d
/^-- Host:/d
/^-- Server version/d
/^-- Dump completed/d

# Supprimer tous les DEFINER
s/DEFINER=[^[:space:]]*[[:space:]]*//g

# Supprimer les vues
/DROP VIEW/d
/CREATE.*VIEW/d

# Supprimer les triggers
/DELIMITER/d
/CREATE.*TRIGGER/d
/END.*;;/d

# Supprimer les procédures
/CREATE.*PROCEDURE/d
/CREATE.*FUNCTION/d

# Ajouter IF NOT EXISTS pour les tables
s/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g

# Nettoyer les espaces multiples
s/[[:space:]]\+/ /g
' schema_minimal_temp.sql

# Créer l'en-tête
cat > schema_minimal.sql << 'EOF'
-- KiloShare Database Schema (Minimal - Tables Only)
-- Compatible with the most restrictive shared hosting providers
-- No triggers, procedures, or views - Maximum compatibility

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

EOF

# Ajouter le contenu nettoyé
cat schema_minimal_temp.sql >> schema_minimal.sql

# Ajouter la fin
cat >> schema_minimal.sql << 'EOF'

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

SET FOREIGN_KEY_CHECKS = 1;
COMMIT;

-- Minimal installation completed - Tables only
-- All business logic must be handled by application code
-- No automatic triggers or stored procedures
EOF

# Nettoyer les fichiers temporaires
rm -f schema_minimal_temp.sql schema_minimal_temp.sql.bak

# Statistiques
TABLES=$(grep -c "CREATE TABLE" schema_minimal.sql)

echo -e "${GREEN}✅ Schéma minimal créé !${NC}"
echo
echo -e "${BLUE}📊 Contenu:${NC}"
echo "  📋 Tables: $TABLES"
echo "  👁️  Vues: 0 (supprimées)"
echo "  ⚙️  Procédures: 0 (supprimées)"
echo "  🔧 Fonctions: 0 (supprimées)"
echo "  🎯 Triggers: 0 (supprimés)"
echo
echo -e "${YELLOW}📁 Fichiers disponibles:${NC}"
echo "  schema_minimal.sql - Tables seulement (compatibilité max)"
echo "  schema_production.sql - Avec triggers/vues (recommandé)"
echo "  schema.sql - Version développement complète"
echo
echo -e "${GREEN}🌐 schema_minimal.sql est compatible avec:${NC}"
echo "  • Tous les hébergeurs partagés"
echo "  • Hostinger, OVH, GoDaddy basique"
echo "  • Serveurs MySQL très restrictifs"
echo "  • Anciens serveurs MySQL (5.1+)"
echo
echo -e "${BLUE}⚠️  Note importante:${NC}"
echo "  La logique métier (triggers) devra être gérée par l'application"