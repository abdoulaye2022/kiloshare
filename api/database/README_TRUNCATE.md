# Script de réinitialisation de la base de données KiloShare

⚠️ **ATTENTION : À utiliser uniquement en développement !**

## 📋 Description

Ces scripts permettent de vider toutes les tables de données tout en préservant :
- Les utilisateurs (`users`)
- Les templates de notifications (`notification_templates`)
- La configuration des paiements (`payment_configuration`)
- L'historique des migrations (`migrations`)
- Les paramètres système (`settings`)

## 🗂️ Fichiers disponibles

### 1. `truncate_tables.sql`
Script SQL direct à exécuter dans votre client MySQL.

```bash
mysql -u root -p kiloshare < truncate_tables.sql
```

### 2. `reset_database.php`
Script PHP interactif avec vérifications et confirmations.

```bash
php reset_database.php
```

## 📊 Tables qui seront vidées

### Données principales
- `bookings` - Réservations
- `trips` - Voyages/annonces
- `messages` - Messages entre utilisateurs
- `reviews` - Évaluations
- `favorites` - Favoris
- `trip_photos` - Photos des voyages
- `package_photos` - Photos des colis

### Paiements
- `payments` - Paiements
- `transactions` - Transactions
- `payment_authorizations` - Autorisations de paiement
- `payment_events_log` - Logs des événements de paiement

### Livraison
- `delivery_codes` - Codes de livraison
- `delivery_code_attempts` - Tentatives de validation
- `delivery_code_history` - Historique des codes

### Jobs/Tâches
- `scheduled_jobs` - Tâches programmées

### Notifications
- `notifications` - Notifications utilisateur
- `fcm_tokens` - Tokens Firebase

### Auth/Session
- `password_resets` - Réinitialisations de mot de passe
- `verification_codes` - Codes de vérification

### Logs
- `activity_logs` - Logs d'activité
- `error_logs` - Logs d'erreurs

## 🔒 Tables préservées

- ✅ `users` - Comptes utilisateur
- ✅ `notification_templates` - Templates de notifications
- ✅ `payment_configuration` - Configuration des paiements
- ✅ `migrations` - Historique des migrations
- ✅ `settings` - Paramètres système

## 🚀 Utilisation recommandée

### Option 1 : Script PHP (recommandé)
```bash
cd /path/to/kiloshare/api
php database/reset_database.php
```

**Avantages :**
- Confirmation interactive
- Vérification des tables existantes
- Rapport détaillé
- Gestion d'erreurs

### Option 2 : Script SQL direct
```bash
mysql -u root -p kiloshare < database/truncate_tables.sql
```

**Avantages :**
- Plus rapide
- Scriptable pour automatisation

## ⚠️ Précautions

1. **Sauvegarde** : Faites une sauvegarde avant d'exécuter
2. **Environnement** : Utilisez uniquement en développement
3. **Confirmation** : Le script PHP demande confirmation
4. **Variables d'environnement** : Assurez-vous que `.env` est configuré

## 🔧 Configuration

Le script PHP utilise les variables d'environnement :
```env
DB_HOST=localhost
DB_NAME=kiloshare
DB_USER=root
DB_PASS=yourpassword
```

## 📝 Après exécution

Après le truncate, vous pourrez :
1. ✅ Vous connecter avec vos comptes existants
2. ✅ Garder les templates de notifications
3. ✅ Conserver la configuration des paiements
4. 🆕 Créer de nouveaux voyages/réservations
5. 🆕 Tester le nouveau système de capture différée

## 🎯 Cas d'usage typiques

- Nettoyer les données de test
- Réinitialiser avant démonstration
- Tester les nouvelles fonctionnalités
- Valider les migrations
- Préparer un environnement propre