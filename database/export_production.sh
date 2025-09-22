#!/bin/bash

# Script d'export pour production - Compatible avec tous les hébergeurs
# Usage: ./export_production.sh [nom_db] [utilisateur] [mot_de_passe]

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DB_NAME=${1:-kiloshare}
DB_USER=${2:-root}
DB_PASSWORD=$3

echo -e "${BLUE}🚀 Export de schéma pour production${NC}"
echo "=================================="

# Demander le mot de passe si non fourni
if [ -z "$DB_PASSWORD" ]; then
    echo -n "Mot de passe MySQL: "
    read -s DB_PASSWORD
    echo
fi

echo -e "${YELLOW}📦 Export en cours...${NC}"

# Export optimisé pour production
mysqldump \
  -h localhost \
  -u "$DB_USER" \
  -p"$DB_PASSWORD" \
  --no-data \
  --routines \
  --triggers \
  --single-transaction \
  --set-gtid-purged=OFF \
  "$DB_NAME" > schema_production.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Export initial réussi${NC}"
else
    echo -e "${RED}❌ Erreur lors de l'export${NC}"
    exit 1
fi

echo -e "${YELLOW}🔧 Nettoyage pour production...${NC}"

# Nettoyer le fichier pour la production
sed -i.bak '
# Supprimer les commentaires MySQL dump
/^-- MySQL dump/d
/^-- Host:/d
/^-- Server version/d

# Supprimer tous les DEFINER
s/DEFINER=[^[:space:]]*[[:space:]]*//g
s/\/\*!50017[^*]*\*\///g
s/\/\*!50013[^*]*\*\///g

# Ajouter IF NOT EXISTS pour les procédures et fonctions
s/CREATE PROCEDURE/CREATE PROCEDURE IF NOT EXISTS/g
s/CREATE FUNCTION/CREATE FUNCTION IF NOT EXISTS/g

# Corriger les erreurs de syntaxe courantes
s/cancellation_count  1/cancellation_count + 1/g
s/cancellation_count  -1/cancellation_count - 1/g
s/rows_affected  ROW_COUNT/rows_affected + ROW_COUNT/g
s/\([a-zA-Z_][a-zA-Z0-9_]*\)  \([A-Z][A-Z_]*(\)/\1 + \2/g
s/\([a-zA-Z_][a-zA-Z0-9_]*\)  \([0-9]\)/\1 + \2/g

# Nettoyer les espaces multiples
s/[[:space:]]\+/ /g
' schema_production.sql

# Ajouter un en-tête propre
cat > temp_header.sql << 'EOF'
-- KiloShare Database Schema (Production Ready)
-- Generated automatically - Compatible with all MySQL hosting providers
-- No DEFINER restrictions - Safe for shared hosting

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";

EOF

# Combiner l'en-tête avec le schéma
cat temp_header.sql schema_production.sql > temp_combined.sql

# Ajouter la fin du fichier
cat >> temp_combined.sql << 'EOF'

SET FOREIGN_KEY_CHECKS = 1;
COMMIT;

-- Installation completed successfully
-- Database ready for production use
EOF

# Remplacer le fichier final
mv temp_combined.sql schema_production.sql
rm -f temp_header.sql schema_production.sql.bak

# Statistiques
TABLES=$(grep -c "CREATE TABLE" schema_production.sql)
PROCEDURES=$(grep -c "CREATE PROCEDURE" schema_production.sql)
FUNCTIONS=$(grep -c "CREATE FUNCTION" schema_production.sql)
TRIGGERS=$(grep -c "CREATE TRIGGER" schema_production.sql)
VIEWS=$(grep -c "CREATE.*VIEW" schema_production.sql)

echo -e "${GREEN}✅ Schéma de production créé !${NC}"
echo
echo -e "${BLUE}📊 Contenu:${NC}"
echo "  📋 Tables: $TABLES"
echo "  👁️  Vues: $VIEWS"
echo "  ⚙️  Procédures: $PROCEDURES"
echo "  🔧 Fonctions: $FUNCTIONS"
echo "  🎯 Triggers: $TRIGGERS"
echo
echo -e "${YELLOW}📁 Fichiers générés:${NC}"
echo "  schema_production.sql - Version production (nettoyée)"
echo "  schema.sql - Version développement (originale)"
echo
echo -e "${GREEN}🌐 Le fichier schema_production.sql est prêt pour:${NC}"
echo "  • phpMyAdmin"
echo "  • Hébergement partagé"
echo "  • Railway, Heroku, DigitalOcean"
echo "  • Tous les providers MySQL"
echo
echo -e "${BLUE}💡 Import sur votre serveur:${NC}"
echo "  mysql -u username -p database_name < schema_production.sql"