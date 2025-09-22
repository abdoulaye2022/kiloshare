# Base de Données KiloShare

Ce dossier contient le schéma de la base de données KiloShare.

## 📋 Contenu

- `schema.sql` - Structure complète de la base de données (sans données)

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

### Créer une nouvelle base de données

```bash
# Se connecter à MySQL
mysql -u root -p

# Créer la base de données
CREATE DATABASE kiloshare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Sélectionner la base
USE kiloshare;

# Importer le schéma
SOURCE /path/to/schema.sql;
```

### Ou via la ligne de commande

```bash
# Créer la base de données
mysql -u root -p -e "CREATE DATABASE kiloshare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Importer le schéma
mysql -u root -p kiloshare < schema.sql
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