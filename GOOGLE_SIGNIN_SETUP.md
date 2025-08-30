# Configuration Google Sign-In - KiloShare

## ✅ Configuration actuelle terminée - Mise à jour iOS

### Corrections apportées pour le crash iOS :
- ✅ Fichier `GoogleService-Info.plist` créé pour iOS
- ✅ AppDelegate configuré avec Google Sign-In
- ✅ Gestion d'URL schemes améliorée
- ✅ Pods iOS mis à jour (GoogleSignIn 8.0.0)
- ✅ Gestion d'erreurs améliorée dans SocialAuthService

### Android
- ✅ Plugin Google Services ajouté au `build.gradle`
- ✅ Fichier `google-services.json` créé avec Client ID
- ✅ Package name configuré : `com.kiloshare.kiloshare`

### iOS  
- ✅ URL Schemes ajoutés au `Info.plist`
- ✅ Bundle ID configuré : `com.kiloshare.kiloshare`

### Flutter
- ✅ Google Sign-In package ajouté
- ✅ SocialAuthService implémenté
- ✅ AuthBloc configuré avec handler

## 📋 Étapes restantes dans Google Console

### 1. Créer/Configurer le projet Google Cloud
1. Aller sur [Google Cloud Console](https://console.cloud.google.com/)
2. Créer un nouveau projet ou utiliser celui existant
3. Activer l'API Google Sign-In

### 2. Configurer OAuth consent screen
1. APIs & Services → OAuth consent screen
2. Configurer les informations de l'application
3. Ajouter les domaines autorisés

### 3. Créer les credentials OAuth
1. APIs & Services → Credentials
2. Créer OAuth 2.0 Client IDs pour :
   - **Type**: Android
   - **Package name**: `com.kiloshare.kiloshare` 
   - **SHA-1**: `63:04:9D:D2:81:63:F7:96:FA:24:D7:50:1E:2A:55:40:64:9A:5C:A7`

   - **Type**: iOS  
   - **Bundle ID**: `com.kiloshare.kiloshare`

### 4. Télécharger google-services.json
1. Une fois les credentials créés, télécharger le vrai `google-services.json`
2. Remplacer le fichier temporaire dans `android/app/google-services.json`

### 5. Configuration iOS (GoogleService-Info.plist)
1. Télécharger `GoogleService-Info.plist` depuis la console
2. Ajouter le fichier dans `ios/Runner/GoogleService-Info.plist`

## 🔧 Configuration actuelle

**Client ID utilisé**: `325498754106-ocf60iqo99m4la6viaahfkvc0c9pcs4k.apps.googleusercontent.com`

**Backend**: Configuré pour recevoir les tokens Google sur `/auth/google`

## ⚠️ Notes importantes

1. Le fichier `google-services.json` actuel est temporaire
2. Il faut télécharger le vrai fichier depuis Google Console
3. Les SHA-1 fingerprints doivent être configurés dans Google Console
4. Pour la production, générer de nouveaux SHA-1 avec le keystore de release

## 🧪 Test de fonctionnement

Une fois la configuration terminée dans Google Console :
1. Rebuilder l'app Flutter (`flutter clean && flutter run`)
2. Cliquer sur le bouton "Continuer avec Google"
3. Vérifier que l'authentification fonctionne

Le flux devrait maintenant fonctionner correctement ! 🚀