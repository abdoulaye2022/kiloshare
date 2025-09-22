# Guide de Sécurité - KiloShare

## 🔒 Fichiers Sensibles et Configuration Sécurisée

Ce document explique comment gérer les informations sensibles dans le projet KiloShare de manière sécurisée.

## 📋 Fichiers Protégés par .gitignore

Les fichiers suivants sont automatiquement exclus de Git pour protéger les informations sensibles :

### Variables d'Environnement
- `.env` et `.env.*` - Contiennent les clés API, mots de passe, etc.
- `config/settings.php` - Configuration avec données sensibles
- `config/database.php` - Configuration base de données

### Clés et Certificats
- `*.key`, `*.pem`, `*.crt` - Clés privées et certificats
- `service-account.json` - Clés de service Google/Firebase
- `firebase-*.json` - Configuration Firebase
- `credentials.json` - Toute configuration d'authentification

### Documentation Sensible
- `*secret*.md`, `*key*.md` - Documentation contenant des informations sensibles
- `STRIPE_*.md`, `FIREBASE_*.md` - Guides de configuration avec clés

## ⚙️ Configuration Sécurisée

### 1. Variables d'Environnement

**JAMAIS** placer des clés secrètes directement dans le code. Utilisez toujours des variables d'environnement :

```php
// ❌ MAL - Clé en dur
$stripe_key = 'sk_live_abcd1234...';

// ✅ BIEN - Variable d'environnement
$stripe_key = $_ENV['STRIPE_SECRET_KEY'];
```

### 2. Fichier .env

Créez votre fichier `.env` à partir de `.env.example` :

```bash
cp api/.env.example api/.env
```

Puis modifiez les valeurs avec vos vraies clés :

```env
# Remplacez par vos vraies valeurs
STRIPE_SECRET_KEY=sk_live_votre_vraie_clé
JWT_SECRET=votre_secret_jwt_très_long_et_complexe
DB_PASSWORD=votre_mot_de_passe_base_de_données
```

### 3. Variables Critiques à Configurer

#### Base de Données
```env
DB_HOST=localhost
DB_DATABASE=kiloshare_prod
DB_USERNAME=kiloshare_user
DB_PASSWORD=mot_de_passe_très_sécurisé
```

#### JWT (Authentification)
```env
JWT_SECRET=clé_secrète_très_longue_minimum_32_caractères
```

#### Stripe (Paiements)
```env
STRIPE_SECRET_KEY=sk_live_...    # Clé secrète LIVE
STRIPE_PUBLISHABLE_KEY=pk_live_... # Clé publique LIVE
STRIPE_WEBHOOK_SECRET=whsec_...    # Secret webhook
```

#### Firebase
```env
FIREBASE_PROJECT_ID=votre-projet-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nvotre_clé_privée\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL=service-account@projet.iam.gserviceaccount.com
```

## 🛡️ Bonnes Pratiques de Sécurité

### 1. Gestion des Clés

- **Rotation régulière** : Changez les clés secrètes régulièrement
- **Accès limité** : Seules les personnes nécessaires ont accès aux clés
- **Environnements séparés** : Utilisez des clés différentes pour dev/staging/prod

### 2. Stockage Sécurisé

- Utilisez un gestionnaire de mots de passe d'équipe (1Password, Bitwarden)
- Stockez les clés de production séparément des clés de développement
- Ne partagez jamais les clés par email ou chat

### 3. Configuration par Environnement

```env
# Développement (.env.local)
APP_ENV=development
STRIPE_SECRET_KEY=sk_test_...

# Production (.env.production)
APP_ENV=production
STRIPE_SECRET_KEY=sk_live_...
```

### 4. Déploiement Sécurisé

- Configurez les variables d'environnement directement sur le serveur
- Utilisez des services comme Railway Variables, Heroku Config Vars
- Ne jamais commiter les fichiers `.env` de production

## 🚨 Que Faire en Cas de Fuite

### Si une clé est exposée :

1. **Révoquez immédiatement** la clé compromise
2. **Générez une nouvelle clé** sur le service concerné
3. **Mettez à jour** la configuration sur tous les environnements
4. **Vérifiez les logs** pour détecter une utilisation malveillante
5. **Notifiez l'équipe** de l'incident

### Services à vérifier :
- Stripe Dashboard → Clés API
- Firebase Console → Comptes de service
- Cloudinary Dashboard → Clés API
- Base de données → Utilisateurs et permissions

## 🔍 Audit de Sécurité

### Commandes de vérification :

```bash
# Vérifier qu'aucun fichier sensible n'est tracké
git ls-files | grep -E "\.(env|key|pem)$"

# Chercher des clés potentiellement en dur
grep -r "sk_live\|sk_test" --exclude-dir=vendor .
grep -r "password.*=" --exclude-dir=vendor .

# Vérifier le statut .gitignore
git status --ignored
```

## 📞 Contact Sécurité

En cas de problème de sécurité, contactez immédiatement :
- Mohamed Ahmed (Développeur Principal)
- Email : [votre-email-sécurité]

## 📚 Ressources

- [OWASP Top 10](https://owasp.org/Top10/)
- [Stripe Security](https://stripe.com/docs/security)
- [Firebase Security Rules](https://firebase.google.com/docs/rules)