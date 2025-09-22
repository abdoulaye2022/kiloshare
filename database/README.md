# Base de Données KiloShare

Ce dossier contient le schéma de la base de données KiloShare.

## 📋 Contenu

### 📄 Fichiers de schéma
- `schema.sql` - Structure complète (développement local)
- `schema_production.sql` - Version optimisée pour production/hébergement ⭐
- `schema_minimal.sql` - Tables seulement (hébergeurs restrictifs)

### 🛠️ Scripts d'export
- `export_production.sh` - Génère version production avec corrections auto ⭐
- `export_minimal.sh` - Génère version minimale (tables seulement)
- `install.sh` - Installation automatique locale

### 🔍 Outils de validation
- `validate_schema.sh` - Validation automatique des schémas ⭐
- `TROUBLESHOOTING.md` - Guide complet de résolution d'erreurs

## 🗄️ Structure de la Base de Données

### Tables Principales

1. **users** - Utilisateurs de l'application
2. **trips** - Voyages proposés par les transporteurs
3. **bookings** - Réservations de colis
4. **transactions** - Transactions financières
5. **payment_authorizations** - Autorisations de paiement Stripe
6. **messages** - Système de messagerie
7. **notifications** - Notifications utilisateurs

### Tables de Configuration

- **cancellation_policies** - Politiques d'annulation
- **notification_preferences** - Préférences de notification
- **admin_actions** - Actions administratives
- **system_settings** - Paramètres système

### Tables de Tracking

- **delivery_codes** - Codes de livraison
- **tracking_updates** - Mises à jour de suivi
- **trip_cancellation_reports** - Rapports d'annulation
- **scheduled_jobs** - Tâches programmées

## 🚀 Installation

### Pour Production (Hébergement, phpMyAdmin)

```bash
# Générer le schéma production (si pas déjà fait)
./export_production.sh

# Importer sur votre serveur
mysql -u username -p database_name < schema_production.sql
```

### Pour Développement Local

```bash
# Installation automatique
./install.sh

# Ou manuelle
mysql -u root -p -e "CREATE DATABASE kiloshare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p kiloshare < schema.sql
```

### ⚠️ Problèmes d'Import ?

Si vous obtenez des erreurs `DEFINER` ou `Access denied`, consultez `TROUBLESHOOTING.md`

## 🚀 Workflow Recommandé

### Pour MySQL 8.4 Production (Votre cas)
```bash
# 1. Valider le schéma
./validate_schema.sh schema_production.sql

# 2. Importer sur votre serveur
mysql -u username -p database_name < schema_production.sql
```

### Pour hébergeurs avec restrictions
```bash
# 1. Générer version minimale
./export_minimal.sh

# 2. Valider
./validate_schema.sh schema_minimal.sql

# 3. Importer
mysql -u username -p database_name < schema_minimal.sql
```

### Après modifications locales
```bash
# 1. Re-générer le schéma production
./export_production.sh

# 2. Valider automatiquement
./validate_schema.sh

# 3. Déployer si valide
```

## 🔧 Configuration

Après avoir importé le schéma, configurez votre fichier `.env` :

```env
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=kiloshare
DB_USERNAME=votre_utilisateur
DB_PASSWORD=votre_mot_de_passe
DB_CHARSET=utf8mb4
```

## 📊 Statistiques du Schéma

- **37 tables** au total
- **Vues** : active_trips_overview, user_statistics_view
- **Triggers** : Gestion automatique des timestamps et validations
- **Procédures stockées** : Logique métier complexe
- **Index** : Optimisation des performances

## 🔍 Tables Importantes

### Core Business Logic
- `users` - Gestion des utilisateurs
- `trips` - Voyages et disponibilités
- `bookings` - Réservations et statuts
- `payment_authorizations` - Paiements Stripe

### Communication
- `conversations` - Discussions entre utilisateurs
- `messages` - Messages échangés
- `notifications` - Système de notifications

### Sécurité & Tracking
- `delivery_codes` - Codes sécurisés de livraison
- `tracking_updates` - Suivi temps réel
- `admin_actions` - Actions administratives

## 🛠️ Maintenance

### Backup
```bash
# Export complet (structure + données)
mysqldump -u root -p kiloshare > backup_$(date +%Y%m%d).sql

# Export structure uniquement
mysqldump -u root -p --no-data kiloshare > schema_$(date +%Y%m%d).sql
```

### Mise à jour du schéma
```bash
# Re-générer le schéma après modifications
mysqldump -u root -p --no-data --routines --triggers --single-transaction kiloshare > schema.sql
```

## 📝 Notes

- Le schéma utilise le charset `utf8mb4` pour supporter les emojis
- Les foreign keys sont activées pour l'intégrité référentielle
- Les timestamps sont gérés automatiquement
- Les soft deletes sont utilisés pour certaines tables

## 🔗 Liens Utiles

- [Documentation MySQL](https://dev.mysql.com/doc/)
- [Eloquent ORM](https://laravel.com/docs/eloquent)
- [Guide de migration](../api/README.md)