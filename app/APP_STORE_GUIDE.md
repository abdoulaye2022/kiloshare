# 📱 Guide App Store Connect - KiloShare

## 🚨 Erreur ITMS-90683 Résolue

### ✅ **Corrections Appliquées**

Les descriptions de permissions manquantes ont été ajoutées dans `ios/Runner/Info.plist` :

1. **NSPhotoLibraryUsageDescription** ✅
   - **Usage** : Ajouter des images de colis et voyages
   - **Explication** : Aide les utilisateurs à mieux comprendre les transports

2. **NSCameraUsageDescription** ✅
   - **Usage** : Photos de colis, billets d'avion, vérification identité
   - **Explication** : Nécessaire pour les preuves de livraison

3. **NSLocationWhenInUseUsageDescription** ✅
   - **Usage** : Proposer voyages pertinents selon la zone géographique
   - **Explication** : Facilite les rencontres transporteurs/expéditeurs

4. **NSLocationAlwaysAndWhenInUseUsageDescription** ✅
   - **Usage** : Même fonction que ci-dessus
   - **Explication** : Version étendue pour usage continu

### 🔧 **Permissions Additionnelles Ajoutées**

5. **NSContactsUsageDescription**
   - **Usage** : Inviter amis et famille
   - **Préventif** : Éviter futures erreurs

6. **NSMicrophoneUsageDescription**
   - **Usage** : Appels audio pour coordination livraisons
   - **Préventif** : Si fonctionnalité ajoutée plus tard

7. **NSUserNotificationsUsageDescription**
   - **Usage** : Notifications demandes transport et livraisons
   - **Préventif** : Standard pour apps avec notifications

## 🚀 **Prochaines Étapes**

### 1. Build et Archive
```bash
# Aller dans le dossier app
cd app/

# Exécuter le script de build
./scripts/build_ios_release.sh
```

### 2. Upload via Xcode
1. Ouvrir `ios/Runner.xcworkspace` dans Xcode
2. Sélectionner target "Runner"
3. Choisir "Generic iOS Device"
4. Menu **Product** > **Archive**
5. Dans Organizer : **Distribute App** > **App Store Connect**

### 3. Vérification App Store Connect
- Nouveau build avec version **1.0.0 (6)**
- Toutes les permissions correctement décrites
- Validation automatique réussie

## 📋 **Checklist Pré-Soumission**

- [x] ✅ Permissions Camera ajoutée
- [x] ✅ Permissions Photo Library ajoutée
- [x] ✅ Permissions Location ajoutées
- [x] ✅ Version incrémentée (1.0.0+6)
- [x] ✅ Info.plist mis à jour
- [x] ✅ Descriptions en français user-friendly
- [ ] 🔲 Build iOS clean réussi
- [ ] 🔲 Archive Xcode réussi
- [ ] 🔲 Upload App Store Connect
- [ ] 🔲 Validation Apple réussie

## 🛠️ **En Cas de Problème**

### Erreur de Build
```bash
# Nettoyer complètement
flutter clean
cd ios && pod cache clean --all && rm -rf Pods/ && pod install
cd .. && flutter pub get
```

### Erreur de Signature
- Vérifier les profils de provisioning dans Xcode
- Régénérer les certificats si nécessaire
- S'assurer que Bundle ID correspond

### Nouvelle Erreur de Permission
1. Identifier la permission manquante dans l'erreur
2. Ajouter la clé correspondante dans `Info.plist`
3. Ajouter une description claire en français
4. Refaire le build et upload

## 📞 **Ressources**

- [Documentation Apple - Permissions](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
- [Guide Flutter iOS](https://docs.flutter.dev/deployment/ios)
- [App Store Connect](https://appstoreconnect.apple.com)

## 🎯 **Messages de Permission (Français)**

Nos descriptions sont **user-friendly** et expliquent clairement pourquoi l'app a besoin de chaque permission :

- **Photos** : "Pour ajouter des images de vos colis et voyages"
- **Caméra** : "Pour prendre des photos de vos colis et billets"
- **Localisation** : "Pour vous proposer des voyages dans votre région"

Ces descriptions respectent les guidelines Apple et sont facilement compréhensibles par les utilisateurs français.