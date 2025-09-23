#!/bin/bash

# Script de build iOS pour App Store Connect
# Usage: ./scripts/build_ios_release.sh

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Build iOS KiloShare pour App Store${NC}"
echo "======================================="

# Vérifier qu'on est dans le bon dossier
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Erreur: Exécuter depuis le dossier app/${NC}"
    exit 1
fi

# Afficher la version
VERSION=$(grep "version:" pubspec.yaml | cut -d' ' -f2)
echo -e "${YELLOW}📱 Version: $VERSION${NC}"

echo -e "${YELLOW}🧹 Nettoyage...${NC}"
# Nettoyer les builds précédents
flutter clean
rm -rf ios/build/
rm -rf ios/.symlinks/
rm -rf ios/Flutter/App.framework
rm -rf ios/Flutter/Flutter.framework

echo -e "${YELLOW}📦 Récupération des dépendances...${NC}"
# Récupérer les dépendances
flutter pub get

echo -e "${YELLOW}🔧 Génération des fichiers...${NC}"
# Générer les fichiers si nécessaire
flutter packages pub run build_runner build --delete-conflicting-outputs

echo -e "${YELLOW}🍎 Configuration iOS...${NC}"
# Aller dans le dossier iOS
cd ios

# Nettoyer les pods
pod cache clean --all
rm -rf Pods/
rm -rf .symlinks/
rm -f Podfile.lock

# Installer les pods
pod install --repo-update

# Retourner au dossier principal
cd ..

echo -e "${YELLOW}🏗️  Build iOS Release...${NC}"
# Build pour l'App Store
flutter build ios \
    --release \
    --no-codesign \
    --verbose

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build iOS réussi !${NC}"
    echo
    echo -e "${BLUE}📋 Prochaines étapes:${NC}"
    echo "1. Ouvrir ios/Runner.xcworkspace dans Xcode"
    echo "2. Sélectionner 'Generic iOS Device' ou un appareil connecté"
    echo "3. Menu Product > Archive"
    echo "4. Upload vers App Store Connect"
    echo
    echo -e "${YELLOW}📱 Informations build:${NC}"
    echo "Version: $VERSION"
    echo "Permissions ajoutées: Camera, Photo Library, Location"
    echo "Fichier Info.plist mis à jour avec descriptions"
    echo
    echo -e "${GREEN}🎉 Prêt pour soumission App Store !${NC}"
else
    echo -e "${RED}❌ Erreur lors du build${NC}"
    exit 1
fi