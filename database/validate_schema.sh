#!/bin/bash

# Script de validation du schéma SQL
# Usage: ./validate_schema.sh [fichier_schema]

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fichier à valider
SCHEMA_FILE=${1:-schema_production.sql}

echo -e "${BLUE}🔍 Validation du schéma SQL${NC}"
echo "================================"
echo "Fichier: $SCHEMA_FILE"
echo

if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}❌ Erreur: Le fichier $SCHEMA_FILE n'existe pas${NC}"
    exit 1
fi

ERRORS_FOUND=0

echo -e "${YELLOW}🔍 Vérification des erreurs de syntaxe courantes...${NC}"

# 1. Vérifier les opérateurs manquants
echo -n "  Opérateurs manquants (var  1): "
MISSING_OPS=$(grep -c "[a-zA-Z_][a-zA-Z0-9_]*  [0-9]" "$SCHEMA_FILE")
if [ $MISSING_OPS -gt 0 ]; then
    echo -e "${RED}❌ $MISSING_OPS trouvés${NC}"
    grep -n "[a-zA-Z_][a-zA-Z0-9_]*  [0-9]" "$SCHEMA_FILE" | head -3
    ERRORS_FOUND=$((ERRORS_FOUND + MISSING_OPS))
else
    echo -e "${GREEN}✅ Aucun${NC}"
fi

# 2. Vérifier ROW_COUNT mal formaté
echo -n "  ROW_COUNT() mal formaté: "
ROWCOUNT_ERRORS=$(grep -c "[a-zA-Z_][a-zA-Z0-9_]*  ROW_COUNT" "$SCHEMA_FILE")
if [ $ROWCOUNT_ERRORS -gt 0 ]; then
    echo -e "${RED}❌ $ROWCOUNT_ERRORS trouvés${NC}"
    grep -n "[a-zA-Z_][a-zA-Z0-9_]*  ROW_COUNT" "$SCHEMA_FILE"
    ERRORS_FOUND=$((ERRORS_FOUND + ROWCOUNT_ERRORS))
else
    echo -e "${GREEN}✅ Aucun${NC}"
fi

# 3. Vérifier les DEFINER problématiques
echo -n "  Restrictions DEFINER: "
DEFINER_COUNT=$(grep -c "DEFINER=" "$SCHEMA_FILE")
if [ $DEFINER_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $DEFINER_COUNT trouvés${NC}"
    echo "    Note: Peuvent causer des erreurs sur certains hébergeurs"
else
    echo -e "${GREEN}✅ Aucun${NC}"
fi

# 4. Vérifier les collations problématiques
echo -n "  Collations MySQL 8+: "
COLLATION_COUNT=$(grep -c "utf8mb4_0900_ai_ci" "$SCHEMA_FILE")
if [ $COLLATION_COUNT -gt 0 ]; then
    echo -e "${GREEN}✅ $COLLATION_COUNT (MySQL 8.0+)${NC}"
else
    echo -e "${YELLOW}⚠️  Utilise utf8mb4_unicode_ci (compatible anciennes versions)${NC}"
fi

# 5. Vérifier la structure générale
echo -e "${YELLOW}📊 Statistiques du schéma:${NC}"
TABLES=$(grep -c "CREATE TABLE" "$SCHEMA_FILE")
VIEWS=$(grep -c "CREATE.*VIEW" "$SCHEMA_FILE")
PROCEDURES=$(grep -c "CREATE.*PROCEDURE" "$SCHEMA_FILE")
FUNCTIONS=$(grep -c "CREATE.*FUNCTION" "$SCHEMA_FILE")
TRIGGERS=$(grep -c "CREATE.*TRIGGER" "$SCHEMA_FILE")

echo "  📋 Tables: $TABLES"
echo "  👁️  Vues: $VIEWS"
echo "  ⚙️  Procédures: $PROCEDURES"
echo "  🔧 Fonctions: $FUNCTIONS"
echo "  🎯 Triggers: $TRIGGERS"

# 6. Vérifier les en-têtes de sécurité
echo -e "${YELLOW}🔒 Vérifications de sécurité:${NC}"
if grep -q "SET FOREIGN_KEY_CHECKS = 0" "$SCHEMA_FILE"; then
    echo -e "  ✅ Foreign key checks désactivés pendant l'import"
else
    echo -e "  ${YELLOW}⚠️  Foreign key checks non gérés${NC}"
fi

if grep -q "START TRANSACTION" "$SCHEMA_FILE"; then
    echo -e "  ✅ Import transactionnel"
else
    echo -e "  ${YELLOW}⚠️  Import non transactionnel${NC}"
fi

echo
echo "================================"

# Résultat final
if [ $ERRORS_FOUND -eq 0 ]; then
    echo -e "${GREEN}🎉 Schéma valide ! Prêt pour l'import${NC}"
    echo
    echo -e "${BLUE}💡 Recommandations d'import:${NC}"
    if [ $DEFINER_COUNT -gt 0 ]; then
        echo "  • Hébergement partagé: Possible conflit avec DEFINER"
    fi
    if [ $COLLATION_COUNT -gt 0 ]; then
        echo "  • Serveur MySQL 8.0+ recommandé"
    else
        echo "  • Compatible MySQL 5.7+"
    fi
    exit 0
else
    echo -e "${RED}❌ $ERRORS_FOUND erreur(s) de syntaxe détectée(s)${NC}"
    echo
    echo -e "${BLUE}🛠️ Solutions:${NC}"
    echo "  1. Utiliser ./export_production.sh pour corriger automatiquement"
    echo "  2. Voir TROUBLESHOOTING.md pour corrections manuelles"
    echo "  3. Contacter l'équipe de développement"
    exit 1
fi