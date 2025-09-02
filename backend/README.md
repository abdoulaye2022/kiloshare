# KiloShare Backend API v2.0

Backend API refactorisé pour KiloShare avec architecture moderne et ORM Eloquent.

## 🏗️ Architecture

Cette nouvelle architecture suit les principes de Clean Architecture avec:
- **ORM Eloquent** pour la gestion de la base de données
- **Slim Framework 4** pour l'API REST
- **DI Container** pour l'injection de dépendances  
- **Middleware** pour l'authentification et CORS
- **Structure MVC** claire et organisée

## 📁 Structure des dossiers

```
backend_new/
├── public/
│   └── index.php                 # Point d'entrée
├── src/
│   ├── Controllers/             # Contrôleurs
│   │   ├── AuthController.php
│   │   ├── TripController.php
│   │   ├── BookingController.php
│   │   └── UserController.php
│   ├── Models/                  # Modèles Eloquent
│   │   ├── User.php
│   │   ├── Trip.php
│   │   ├── Booking.php
│   │   └── UserToken.php
│   ├── Middleware/              # Middlewares
│   │   ├── AuthMiddleware.php
│   │   └── CorsMiddleware.php
│   ├── Services/                # Logique métier
│   │   ├── AuthService.php
│   │   ├── StripeService.php
│   │   └── EmailService.php
│   └── Utils/                   # Utilitaires
│       ├── Database.php
│       ├── Response.php
│       └── Validator.php
├── config/
│   ├── database.php
│   ├── settings.php
│   └── routes.php
├── storage/
│   ├── logs/
│   └── uploads/
├── vendor/                      # Dépendances Composer
├── .env                        # Variables d'environnement
├── .env.example
├── composer.json
└── README.md
```

## 📊 Tables de la base de données

Le système gère les tables suivantes:

### 🔐 Authentification & Utilisateurs
- `users` - Utilisateurs principaux
- `user_tokens` - Tokens JWT et de vérification
- `user_profiles` - Profils détaillés
- `user_social_accounts` - Comptes sociaux liés
- `user_stripe_accounts` - Comptes Stripe Connect
- `email_verifications` - Vérifications email
- `phone_verifications` - Vérifications téléphone
- `password_resets` - Réinitialisations mot de passe
- `login_attempts` - Tentatives de connexion
- `verification_codes` - Codes de vérification
- `verification_documents` - Documents KYC
- `verification_logs` - Logs de vérification

### 🚗 Voyages & Annonces
- `trips` - Annonces de voyage
- `trip_drafts` - Brouillons d'annonces
- `trip_images` - Photos des voyages
- `trip_favorites` - Favoris utilisateurs
- `trip_views` - Vues des annonces
- `trip_reports` - Signalements
- `trip_restrictions` - Restrictions de transport
- `trip_action_logs` - Logs d'actions
- `trip_status_summary` - Résumé des statuts
- `active_trips_overview` - Vue d'ensemble des voyages actifs

### 📦 Réservations & Paiements
- `bookings` - Réservations
- `booking_negotiations` - Négociations de prix
- `booking_notifications` - Notifications
- `booking_package_photos` - Photos des colis
- `booking_contracts` - Contrats générés
- `booking_summary` - Résumé des réservations
- `transactions` - Transactions financières
- `escrow_accounts` - Comptes séquestre

### 🔍 Recherche & Analytics
- `search_history` - Historique de recherche
- `search_alerts` - Alertes de recherche
- `city_suggestions` - Suggestions de villes
- `popular_routes` - Routes populaires

### 🏆 Confiance & Réputation
- `trust_badges` - Badges de confiance
- `user_trip_favorites` - Favoris utilisateurs-voyages

### ☁️ Gestion des médias
- `image_uploads` - Téléchargements d'images
- `cloudinary_usage_stats` - Stats d'usage Cloudinary
- `cloudinary_cleanup_log` - Logs de nettoyage
- `cloudinary_cleanup_rules` - Règles de nettoyage
- `cloudinary_alerts` - Alertes Cloudinary

### 🛡️ Administration
- `admin_actions` - Actions administrateur
- `stripe_account_creation_log` - Logs création comptes Stripe
- `social_auth_attempts` - Tentatives auth sociale

### 📊 Vues & Analytics
- `users_with_stripe_status` - Vue utilisateurs avec statut Stripe
- `v_cloudinary_current_usage` - Vue usage Cloudinary actuel
- `v_cloudinary_usage_summary` - Vue résumé usage Cloudinary

## 🚀 Installation

1. **Cloner et installer les dépendances**
```bash
cd backend_new
composer install
```

2. **Configuration**
```bash
cp .env.example .env
# Éditer .env avec vos paramètres de base de données
```

3. **Démarrer le serveur**
```bash
php -S 127.0.0.1:8080 -t public
```

## 📡 Endpoints API

### Authentification
- `POST /api/v1/auth/register` - Inscription
- `POST /api/v1/auth/login` - Connexion
- `POST /api/v1/auth/refresh` - Rafraîchir token
- `GET /api/v1/auth/me` - Profil utilisateur
- `POST /api/v1/auth/logout` - Déconnexion

### Administration
- `POST /api/v1/admin/auth/login` - Connexion admin
- `GET /api/v1/admin/dashboard/stats` - Statistiques dashboard

### Santé de l'API
- `GET /` - Health check

## 🔧 Fonctionnalités

### ✅ Implémenté
- [x] Architecture MVC avec Eloquent ORM
- [x] Authentification JWT avec refresh tokens
- [x] Middleware d'authentification et CORS
- [x] Modèles User, Trip, Booking avec relations
- [x] Système de validation des données
- [x] Gestion des réponses JSON standardisées
- [x] Configuration centralisée
- [x] Autoloading PSR-4

### 🚧 À implémenter
- [ ] Tous les contrôleurs (Trips, Bookings, etc.)
- [ ] Services métier (Email, Stripe, etc.)
- [ ] Système complet de routes
- [ ] Tests unitaires
- [ ] Documentation API complète
- [ ] Cache et optimisations
- [ ] Logs et monitoring

## 🛠️ Développement

### Ajout d'un nouveau modèle
```php
<?php
namespace KiloShare\Models;
use Illuminate\Database\Eloquent\Model;

class MonModele extends Model {
    protected $table = 'ma_table';
    protected $fillable = ['champ1', 'champ2'];
}
```

### Ajout d'un contrôleur
```php
<?php
namespace KiloShare\Controllers;
use KiloShare\Utils\Response;

class MonController {
    public function index(ServerRequestInterface $request): ResponseInterface {
        return Response::success(['data' => 'Hello World']);
    }
}
```

### Ajout de routes
```php
// config/routes.php
$v1Group->get('/mon-endpoint', [MonController::class, 'index']);
```

## 📝 Migration depuis l'ancienne structure

Cette nouvelle structure remplace complètement l'ancienne architecture modulaire:
- ❌ `/src/modules/` → ✅ `/src/Controllers/` et `/src/Models/`
- ❌ PDO direct → ✅ Eloquent ORM
- ❌ Configuration dispersée → ✅ Configuration centralisée
- ❌ Gestion manuelle des tokens → ✅ Middleware d'authentification

## 🤝 Contribution

1. Suivre la structure MVC établie
2. Utiliser Eloquent pour tous les accès BDD
3. Valider les données avec la classe Validator
4. Retourner les réponses avec la classe Response
5. Documenter les nouveaux endpoints