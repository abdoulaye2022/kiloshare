# 🎯 Système de Confiance KiloShare

## Vue d'ensemble

Le système de confiance KiloShare implémente un workflow d'approbation automatique basé sur le score de confiance des utilisateurs pour améliorer la sécurité et la qualité des annonces de voyage.

## 📊 Workflow d'Approbation

### Nouvel utilisateur (Trust Score < 30)
- **Premier voyage**
  - **Voiture/Bus/Train** → Publication immédiate + Flag review
  - **Avion** → Révision manuelle (1-2h)
- **Après 2 voyages réussis** → Auto-approval activé

### Utilisateur vérifié (Trust Score 30-70)
- **Tous transports** → Publication immédiate
- **Monitoring automatique** post-publication

### Utilisateur établi (Trust Score > 70)
- **Publication immédiate** sans restriction

## 🏗️ Architecture Technique

### Backend (PHP/Slim)
```
backend/
├── src/modules/trips/
│   ├── controllers/TripController.php
│   └── models/Trip.php
├── migrations/
│   └── add_trust_score_to_users.sql
└── routes/admin.php
```

### Mobile (Flutter)
```
mobile/lib/
├── modules/auth/models/user_model.dart
├── modules/trips/
│   ├── models/trip_model.dart
│   └── services/trip_service.dart
```

### Web Admin (Next.js)
```
web/
├── app/admin/
│   ├── login/page.tsx
│   └── dashboard/page.tsx
└── app/api/admin/
    ├── auth/login/route.ts
    └── trips/[id]/{approve,reject}/route.ts
```

## 🔐 Interface d'Administration

### Accès
- **URL**: `http://localhost:3000/admin`
- **Identifiants par défaut**:
  - Admin: `admin@kiloshare.com` / `admin123`
  - Modérateur: `moderator@kiloshare.com` / `moderator123`

### Fonctionnalités
- ✅ Connexion sécurisée avec JWT
- ✅ Liste des voyages en attente d'approbation
- ✅ Informations détaillées sur l'utilisateur et son trust score
- ✅ Actions d'approbation/rejet avec notifications
- ✅ Interface responsive et intuitive

## 📱 Intégration Mobile

### Modèles mis à jour
```dart
// User.dart - Trust Score
class User {
  final int trustScore;
  final int completedTrips;
  final int totalTrips;
  
  TrustLevel get trustLevel { /* ... */ }
  bool needsManualApproval(String transportType) { /* ... */ }
  bool canAutoPublish(String transportType) { /* ... */ }
}

// Trip.dart - Nouveaux statuts
enum TripStatus {
  draft,
  pendingApproval,    // 🆕
  published,
  rejected,           // 🆕
  flaggedForReview,   // 🆕
  completed,
  cancelled
}
```

### Service Trip amélioré
```dart
// Détection automatique du statut basé sur le trust score
final trip = Trip.fromJson(response.data['trip']);

if (trip.status == TripStatus.pendingApproval) {
  showMessage('Voyage soumis pour approbation');
} else if (trip.status == TripStatus.published) {
  showMessage('Voyage publié immédiatement');
}
```

## 🚀 Déploiement

### Prérequis
```bash
# Backend
composer install
php -S localhost:8080

# Mobile  
flutter pub get
flutter run

# Web Admin
npm install
npm run dev
```

### Variables d'environnement
```env
# .env.local (Web)
JWT_SECRET=kiloshare-admin-secret-key-2025
BACKEND_URL=http://192.168.2.22:8080/api/v1
```

## 📈 Métriques & Monitoring

### Trust Score Calculation
- **Voyage terminé**: +10 points
- **Évaluation positive**: +5 points  
- **Vérification document**: +15 points
- **Signalement**: -20 points
- **Voyage annulé**: -5 points

### Statuts de voyage
- `draft` - Brouillon
- `pending_approval` - En attente d'approbation
- `published` - Publié et visible
- `rejected` - Rejeté par admin
- `flagged_for_review` - Signalé pour révision
- `completed` - Terminé avec succès
- `cancelled` - Annulé

## 🔧 Configuration

### Trust Score Thresholds
```dart
enum TrustLevel {
  newUser,      // < 30 points
  verified,     // 30-70 points  
  established   // > 70 points
}
```

### Workflow Rules
| Niveau | Transport | Action |
|--------|-----------|---------|
| Nouveau | Avion | Révision manuelle |
| Nouveau | Autres | Publication + Flag |
| Vérifié | Tous | Publication immédiate |
| Établi | Tous | Publication immédiate |

## 📞 Support

### Identifiants Admin de test
- **Super Admin**: admin@kiloshare.com / admin123
- **Modérateur**: moderator@kiloshare.com / moderator123

### Endpoints API
- `POST /api/admin/auth/login` - Connexion admin
- `GET /api/admin/trips/pending` - Voyages en attente
- `POST /api/admin/trips/{id}/approve` - Approuver voyage
- `POST /api/admin/trips/{id}/reject` - Rejeter voyage

## ✅ Tests

### Scénarios de test
1. **Nouvel utilisateur + voyage avion** → Doit aller en `pending_approval`
2. **Nouvel utilisateur + voyage voiture** → Doit être `published` avec flag
3. **Utilisateur vérifié** → Tous voyages `published` immédiatement
4. **Interface admin** → Login, voir la liste, approuver/rejeter

---

🎉 **Le système de confiance KiloShare est maintenant opérationnel !**

L'authentification mobile fonctionne parfaitement, l'interface web admin est prête, et le workflow d'approbation intelligent est implémenté selon vos spécifications.