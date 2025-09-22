#!/bin/bash

# Script d'installation de la base de données KiloShare
# Usage: ./install.sh [nom_de_la_base] [utilisateur] [mot_de_passe]

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration par défaut
DEFAULT_DB_NAME="kiloshare"
DEFAULT_DB_USER="root"

# Paramètres
DB_NAME=${1:-$DEFAULT_DB_NAME}
DB_USER=${2:-$DEFAULT_DB_USER}
DB_PASSWORD=$3

echo -e "${BLUE}🗄️  Installation de la base de données KiloShare${NC}"
echo "=================================================="

# Demander le mot de passe si non fourni
if [ -z "$DB_PASSWORD" ]; then
    echo -n "Mot de passe MySQL pour $DB_USER: "
    read -s DB_PASSWORD
    echo
fi

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "  Base de données: $DB_NAME"
echo "  Utilisateur: $DB_USER"
echo "  Fichier schéma: schema.sql"
echo

# Vérifier que le fichier schema.sql existe
if [ ! -f "schema.sql" ]; then
    echo -e "${RED}❌ Erreur: Le fichier schema.sql n'existe pas dans ce dossier${NC}"
    echo "Assurez-vous d'être dans le dossier /database"
    exit 1
fi

# Tester la connexion MySQL
echo -e "${YELLOW}🔍 Test de connexion MySQL...${NC}"
mysql -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT VERSION();" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erreur: Impossible de se connecter à MySQL${NC}"
    echo "Vérifiez vos identifiants et que MySQL est démarré"
    exit 1
fi
echo -e "${GREEN}✅ Connexion MySQL réussie${NC}"

# Demander confirmation
echo -e "${YELLOW}⚠️  Cette opération va:${NC}"
echo "  1. Créer/recréer la base de données '$DB_NAME'"
echo "  2. Importer toute la structure depuis schema.sql"
echo "  3. Écraser toutes les données existantes"
echo
read -p "Continuer? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Installation annulée${NC}"
    exit 0
fi

# Créer la base de données
echo -e "${YELLOW}📦 Création de la base de données...${NC}"
mysql -u "$DB_USER" -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
mysql -u "$DB_USER" -p"$DB_PASSWORD" -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Base de données '$DB_NAME' créée${NC}"
else
    echo -e "${RED}❌ Erreur lors de la création de la base de données${NC}"
    exit 1
fi

# Importer le schéma
echo -e "${YELLOW}📥 Import du schéma...${NC}"
mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < schema.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Schéma importé avec succès${NC}"
else
    echo -e "${RED}❌ Erreur lors de l'import du schéma${NC}"
    exit 1
fi

# Vérifier l'installation
echo -e "${YELLOW}🔍 Vérification de l'installation...${NC}"
TABLE_COUNT=$(mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SHOW TABLES;" | wc -l)
TABLE_COUNT=$((TABLE_COUNT - 1)) # Enlever l'en-tête

echo -e "${GREEN}✅ Installation terminée!${NC}"
echo
echo -e "${BLUE}📊 Résumé:${NC}"
echo "  Base de données: $DB_NAME"
echo "  Nombre de tables: $TABLE_COUNT"
echo "  Charset: utf8mb4"
echo "  Collation: utf8mb4_unicode_ci"
echo

echo -e "${BLUE}🔧 Configuration recommandée pour .env:${NC}"
echo "DB_CONNECTION=mysql"
echo "DB_HOST=localhost"
echo "DB_PORT=3306"
echo "DB_DATABASE=$DB_NAME"
echo "DB_USERNAME=$DB_USER"
echo "DB_PASSWORD=votre_mot_de_passe"
echo "DB_CHARSET=utf8mb4"
echo

echo -e "${GREEN}🎉 Installation réussie! Vous pouvez maintenant utiliser KiloShare.${NC}"