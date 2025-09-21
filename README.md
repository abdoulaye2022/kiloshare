# KiloShare - Application de partage d'espace bagages

KiloShare est une application mobile permettant aux voyageurs de partager leur espace bagages avec d'autres personnes qui souhaitent envoyer des objets.

## Architecture du projet

```
kiloshare-project/
├── app/                       # Application Flutter (iOS + Android)
│   ├── lib/
│   │   ├── config/           # Configuration et thèmes
│   │   ├── models/           # Modèles de données
│   │   ├── screens/          # Écrans de l'application
│   │   ├── services/         # Services API et logique métier
│   │   ├── widgets/          # Composants UI réutilisables
│   │   ├── providers/        # Gestion d'état (Riverpod)
│   │   ├── repositories/     # Couche d'accès aux données
│   │   └── utils/            # Utilitaires et helpers
│   ├── assets/               # Ressources (images, icônes, etc.)
│   └── pubspec.yaml
│
├── api/                       # API REST en Slim PHP 4
│   ├── public/
│   │   └── index.php         # Point d'entrée API
│   ├── src/
│   │   ├── Controllers/      # Contrôleurs API
│   │   ├── Models/           # Modèles de données
│   │   ├── Middleware/       # Middleware (auth, CORS, etc.)
│   │   ├── Services/         # Services métier
│   │   └── Routes/           # Définition des routes
│   ├── config/
│   │   ├── database.php      # Configuration BDD
│   │   └── settings.php      # Configuration générale
│   ├── uploads/              # Dossier FTP pour les fichiers
│   │   ├── avatars/
│   │   ├── luggage/
│   │   ├── documents/
│   │   └── temp/
│   ├── .env                  # Variables d'environnement
│   └── composer.json
│
└── database/
    └── schema.sql            # Structure complète de la BDD
```

## Configuration technique

### Base de données
- **Nom**: `kiloshare`
- **Utilisateur**: `root`
- **Mot de passe**: (vide)
- **Type**: MySQL avec charset utf8mb4

### API (Slim PHP 4)
- Framework: Slim 4 avec PHP-DI
- Authentification: JWT avec Firebase PHP-JWT
- Upload: FTP local avec sécurisation
- CORS: Configuré pour le développement

### App (Flutter)
- Version Flutter: >=3.10.0
- Dart SDK: >=3.0.0
- Gestion d'état: Riverpod
- Navigation: GoRouter
- UI: Material Design 3

## Installation

### 1. API

```bash
cd api
composer install
php -S localhost:8080 -t public
```

### 2. Base de données

```bash
mysql -u root < ../database/schema.sql
```

### 3. App

```bash
cd app
flutter pub get
flutter run
```

## Modules de l'application

1. **Authentification** - Inscription, connexion, profil utilisateur
2. **Voyages** - Création et gestion des trajets
3. **Espaces bagages** - Demandes d'envoi d'objets
4. **Réservations** - Mise en relation voyageurs/expéditeurs
5. **Paiements** - Gestion des transactions
6. **Messages** - Chat entre utilisateurs
7. **Évaluations** - Système de notation
8. **Notifications** - Alertes et rappels
9. **Recherche** - Moteur de recherche avancé
10. **Administration** - Panel admin

## API Endpoints

### Authentification
- `POST /api/v1/auth/register` - Inscription
- `POST /api/v1/auth/login` - Connexion
- `POST /api/v1/auth/refresh` - Actualiser token

### Voyages
- `GET /api/v1/journeys` - Liste des voyages
- `POST /api/v1/journeys` - Créer un voyage
- `GET /api/v1/journeys/{id}` - Détails voyage

### Espaces bagages
- `GET /api/v1/spaces` - Liste des demandes
- `POST /api/v1/spaces` - Créer une demande
- `GET /api/v1/spaces/{id}` - Détails demande

Et bien d'autres...

## Fonctionnalités principales

- **Inscription/Connexion** avec vérification d'identité
- **Création de voyages** avec détails du trajet
- **Demandes d'envoi** avec photos et descriptions
- **Système de matching** automatique
- **Chat intégré** pour la communication
- **Paiements sécurisés** avec commission
- **Géolocalisation** pour pickup/delivery
- **Notifications push**
- **Système d'évaluations**
- **Panel d'administration**

## Sécurité

- Authentification JWT
- Validation des données côté serveur
- Upload sécurisé avec restriction des types de fichiers
- Chiffrement des mots de passe
- Protection CORS
- Validation des permissions

## Développement

Le projet est configuré pour le développement local avec:
- Hot reload pour Flutter
- Serveur PHP intégré
- Base de données MySQL locale
- Variables d'environnement pour la configuration

## Licence

Propriétaire - KiloShare