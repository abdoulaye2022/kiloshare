#!/bin/bash

# Script de vérification sécurité pour KiloShare
# Usage: ./scripts/security-check.sh

echo "🔒 Vérification de sécurité KiloShare"
echo "======================================"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo ""
echo "1. Vérification des fichiers .env..."

# Vérifier que .env n'est pas tracké
if git ls-files | grep -q "\.env$"; then
    echo -e "${RED}❌ ERREUR: Le fichier .env est tracké par Git!${NC}"
    echo "   Solution: git rm --cached .env && git commit -m 'Remove .env from tracking'"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ Fichier .env non tracké${NC}"
fi

# Vérifier que .env.example existe
if [ -f "api/.env.example" ]; then
    echo -e "${GREEN}✅ Fichier .env.example présent${NC}"
else
    echo -e "${YELLOW}⚠️  Fichier .env.example manquant${NC}"
    ((WARNINGS++))
fi

echo ""
echo "2. Vérification des clés en dur..."

# Rechercher des clés Stripe en dur
STRIPE_KEYS=$(grep -r "sk_live_\|sk_test_" --exclude-dir=vendor --exclude-dir=node_modules --exclude="*.log" . | grep -v ".env" | grep -v ".example" | wc -l)
if [ $STRIPE_KEYS -gt 0 ]; then
    echo -e "${RED}❌ ERREUR: Clés Stripe trouvées en dur dans le code!${NC}"
    grep -r "sk_live_\|sk_test_" --exclude-dir=vendor --exclude-dir=node_modules --exclude="*.log" . | grep -v ".env" | grep -v ".example"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ Aucune clé Stripe en dur détectée${NC}"
fi

# Rechercher des mots de passe en dur
PASSWORDS=$(grep -r "password.*=.*['\"].*['\"]" --exclude-dir=vendor --exclude-dir=node_modules --exclude="*.log" api/src/ | grep -v "\$_ENV\|getenv" | wc -l)
if [ $PASSWORDS -gt 0 ]; then
    echo -e "${RED}❌ ERREUR: Mots de passe potentiels en dur détectés!${NC}"
    grep -r "password.*=.*['\"].*['\"]" --exclude-dir=vendor --exclude-dir=node_modules --exclude="*.log" api/src/ | grep -v "\$_ENV\|getenv"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ Aucun mot de passe en dur détecté${NC}"
fi

echo ""
echo "3. Vérification des fichiers de configuration..."

# Vérifier settings.php
if [ -f "api/config/settings.php" ]; then
    if grep -q "\$_ENV\|getenv" api/config/settings.php; then
        echo -e "${GREEN}✅ settings.php utilise des variables d'environnement${NC}"
    else
        echo -e "${RED}❌ ERREUR: settings.php ne semble pas utiliser de variables d'environnement${NC}"
        ((ERRORS++))
    fi
fi

# Vérifier database.php
if [ -f "api/config/database.php" ]; then
    if grep -q "\$_ENV\|getenv" api/config/database.php; then
        echo -e "${GREEN}✅ database.php utilise des variables d'environnement${NC}"
    else
        echo -e "${RED}❌ ERREUR: database.php ne semble pas utiliser de variables d'environnement${NC}"
        ((ERRORS++))
    fi
fi

echo ""
echo "4. Vérification des fichiers potentiellement sensibles..."

# Fichiers JSON avec credentials
SENSITIVE_JSON=$(find . -name "*.json" -not -path "./vendor/*" -not -path "./node_modules/*" -not -path "./.git/*" | grep -E "(credential|service-account|firebase)" | wc -l)
if [ $SENSITIVE_JSON -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Fichiers JSON potentiellement sensibles trouvés:${NC}"
    find . -name "*.json" -not -path "./vendor/*" -not -path "./node_modules/*" -not -path "./.git/*" | grep -E "(credential|service-account|firebase)"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ Aucun fichier JSON sensible détecté${NC}"
fi

# Fichiers .key ou .pem
CERT_FILES=$(find . -name "*.key" -o -name "*.pem" -o -name "*.crt" | grep -v vendor | wc -l)
if [ $CERT_FILES -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Fichiers de certificats trouvés:${NC}"
    find . -name "*.key" -o -name "*.pem" -o -name "*.crt" | grep -v vendor
    echo "   Assurez-vous qu'ils sont dans .gitignore"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ Aucun fichier de certificat détecté${NC}"
fi

echo ""
echo "5. Vérification du .gitignore..."

if [ -f ".gitignore" ]; then
    if grep -q "\.env$" .gitignore; then
        echo -e "${GREEN}✅ .env est dans .gitignore${NC}"
    else
        echo -e "${RED}❌ ERREUR: .env n'est pas dans .gitignore${NC}"
        ((ERRORS++))
    fi

    if grep -q "config/settings\.php" .gitignore; then
        echo -e "${GREEN}✅ settings.php est protégé${NC}"
    else
        echo -e "${YELLOW}⚠️  settings.php n'est pas dans .gitignore${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}❌ ERREUR: Fichier .gitignore manquant!${NC}"
    ((ERRORS++))
fi

echo ""
echo "6. Vérification des permissions..."

# Vérifier les permissions des fichiers .env
if [ -f "api/.env" ]; then
    PERMS=$(stat -f "%A" api/.env 2>/dev/null || stat -c "%a" api/.env 2>/dev/null)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "644" ]; then
        echo -e "${GREEN}✅ Permissions .env correctes ($PERMS)${NC}"
    else
        echo -e "${YELLOW}⚠️  Permissions .env à vérifier ($PERMS)${NC}"
        echo "   Recommandé: chmod 600 api/.env"
        ((WARNINGS++))
    fi
fi

echo ""
echo "======================================"
echo "📊 RÉSUMÉ DE LA VÉRIFICATION"
echo "======================================"

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ $ERRORS erreur(s) critique(s) détectée(s)${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS avertissement(s)${NC}"
fi

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 Aucun problème de sécurité détecté!${NC}"
fi

echo ""
echo "💡 RECOMMANDATIONS:"
echo "- Utilisez toujours des variables d'environnement pour les clés secrètes"
echo "- Vérifiez régulièrement avec: git status --ignored"
echo "- Changez les clés de production régulièrement"
echo "- Ne partagez jamais les fichiers .env par email ou chat"

exit $ERRORS