# Système de Codes de Livraison Sécurisé - KiloShare

## Vue d'ensemble

Ce document décrit l'implémentation complète du système de codes de livraison sécurisé pour l'application KiloShare. Ce système permet de confirmer la livraison des colis avec un code à 6 chiffres, une géolocalisation et des photos obligatoires.

## Architecture

### Stack Technique
- **Frontend**: Flutter (application mobile)
- **Backend**: PHP Slim Framework
- **Base de données**: MySQL
- **Notifications**: Firebase FCM + Brevo (emails)
- **Photos**: Cloudinary
- **Géolocalisation**: Flutter Geolocator

## Workflow du Système

### 1. Génération du Code
```
Réservation confirmée → Code généré automatiquement → Envoyé à l'expéditeur UNIQUEMENT
```

### 2. Validation du Code
```
Voyageur arrive → Contacte l'expéditeur → Obtient le code → Saisit dans l'app
                                                            ↓
Géolocalisation + Photos + Code → Validation → Libération du paiement
```

### 3. Sécurité
- Code à 6 chiffres généré aléatoirement
- Maximum 3 tentatives de saisie
- Expiration 48h après arrivée du voyage
- Géolocalisation obligatoire
- Photos obligatoires
- Envoi uniquement à l'expéditeur

## Base de Données

### Tables Créées

#### `delivery_codes`
```sql
CREATE TABLE delivery_codes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    code VARCHAR(6) NOT NULL,
    status ENUM('active', 'used', 'expired', 'regenerated') DEFAULT 'active',
    attempts_count INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL,
    used_at TIMESTAMP NULL,
    delivery_latitude DECIMAL(10, 8) NULL,
    delivery_longitude DECIMAL(11, 8) NULL,
    delivery_photos JSON NULL,
    verification_photos JSON NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);
```

#### `delivery_code_attempts`
```sql
CREATE TABLE delivery_code_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_code_id INT NOT NULL,
    attempted_code VARCHAR(6) NOT NULL,
    user_id INT NOT NULL,
    attempt_latitude DECIMAL(10, 8) NULL,
    attempt_longitude DECIMAL(11, 8) NULL,
    success BOOLEAN DEFAULT FALSE,
    error_message VARCHAR(255) NULL,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (delivery_code_id) REFERENCES delivery_codes(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

#### `delivery_code_history`
```sql
CREATE TABLE delivery_code_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    old_code VARCHAR(6) NULL,
    new_code VARCHAR(6) NOT NULL,
    action ENUM('generated', 'regenerated', 'expired', 'used') NOT NULL,
    triggered_by_user_id INT NULL,
    reason VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);
```

#### Modifications aux `bookings`
```sql
ALTER TABLE bookings
ADD COLUMN delivery_code_required BOOLEAN DEFAULT FALSE,
ADD COLUMN delivery_confirmed_at TIMESTAMP NULL,
ADD COLUMN delivery_confirmed_by INT NULL;
```

## API Backend

### Endpoints Disponibles

#### Génération de Code (Transporteur uniquement)
```
POST /api/v1/bookings/{id}/delivery-code/generate
```

#### Validation de Code
```
POST /api/v1/bookings/{id}/delivery-code/validate
Body: {
    "code": "123456",
    "latitude": 45.5017,
    "longitude": -73.5673,
    "photos": ["base64_image1", "base64_image2"]
}
```

#### Régénération de Code (Expéditeur uniquement)
```
POST /api/v1/bookings/{id}/delivery-code/regenerate
Body: {
    "reason": "Code perdu"
}
```

#### Récupération d'informations
```
GET /api/v1/bookings/{id}/delivery-code
GET /api/v1/bookings/{id}/delivery-code/attempts
GET /api/v1/bookings/{id}/delivery-code/required
```

#### Statistiques Admin
```
GET /api/v1/admin/delivery-codes/stats?days=30
```

### Classes Backend Principales

#### `DeliveryCode` (Model)
- Gestion des codes de livraison
- Méthodes de validation et expiration
- Relations avec bookings et tentatives

#### `DeliveryCodeService` (Service)
- Logique métier principale
- Génération et validation des codes
- Intégration avec notifications

#### `DeliveryCodeController` (Controller)
- Endpoints API
- Validation des données
- Gestion des permissions

## Frontend Flutter

### Service Principal

#### `DeliveryCodeService`
```dart
class DeliveryCodeService {
    // Génération de code
    Future<Map<String, dynamic>> generateDeliveryCode(String bookingId);

    // Validation avec géolocalisation et photos
    Future<Map<String, dynamic>> validateDeliveryCode({
        required String bookingId,
        required String code,
        List<File>? photos,
        bool requireLocation = true,
    });

    // Régénération
    Future<Map<String, dynamic>> regenerateDeliveryCode({
        required String bookingId,
        String? reason,
    });

    // Utilitaires photo et géolocalisation
    Future<File?> takePhoto();
    Future<List<File>> pickPhotosFromGallery({int maxPhotos = 3});
}
```

### Écran de Validation

#### `DeliveryCodeValidationScreen`
- Interface de saisie du code à 6 chiffres
- Capture automatique de géolocalisation
- Prise de photos obligatoire
- Validation en temps réel
- Gestion des erreurs et tentatives

### Modèle de Données

#### `DeliveryCodeModel`
```dart
class DeliveryCodeModel {
    final int id;
    final int bookingId;
    final String? code; // null pour le destinataire
    final String status;
    final int attemptsCount;
    final int maxAttempts;
    final DateTime generatedAt;
    final DateTime? expiresAt;
    // ... autres propriétés et méthodes utilitaires
}
```

## Système de Notifications

### Types de Notifications

1. **Code Généré** (`delivery_code_generated`)
   - Envoyé à l'expéditeur uniquement
   - Contient le code à 6 chiffres
   - Via email, SMS et notification push

2. **Code Régénéré** (`delivery_code_regenerated`)
   - Nouveau code suite à perte/oubli
   - Envoyé à l'expéditeur

3. **Livraison Confirmée** (`delivery_confirmed`)
   - Envoyé à toutes les parties
   - Confirme la validation du code
   - Déclenche la libération du paiement

### Canaux de Notification
- **Notification Push**: Immédiate
- **Email**: Détaillé avec instructions
- **SMS**: Code simple et direct
- **In-App**: Historique persistant

## Sécurité

### Mesures Implémentées

1. **Génération Sécurisée**
   - Code aléatoire à 6 chiffres
   - Vérification d'unicité
   - Cryptographiquement sécurisé

2. **Limitation des Tentatives**
   - Maximum 3 tentatives
   - Blocage automatique après échec
   - Historique des tentatives

3. **Expiration Temporelle**
   - 48h après arrivée du voyage
   - Nettoyage automatique des codes expirés

4. **Géolocalisation Obligatoire**
   - Position GPS au moment de validation
   - Vérification de cohérence géographique

5. **Preuves Photographiques**
   - Photos obligatoires du colis
   - Stockage sécurisé sur Cloudinary
   - Horodatage et métadonnées

6. **Permissions Strictes**
   - Expéditeur: Peut voir et régénérer le code
   - Destinataire: Ne voit pas le code, peut seulement valider
   - Transporteur: Peut générer le code initial

## Gestion des Erreurs

### Cas d'Usage Couverts

1. **Code Incorrect**
   - Décrémentation des tentatives
   - Message d'erreur clair
   - Blocage après 3 échecs

2. **Code Expiré**
   - Vérification automatique
   - Possibilité de régénération
   - Notification aux parties

3. **Géolocalisation Échouée**
   - Demande de permissions
   - Réessai automatique
   - Message d'aide utilisateur

4. **Photos Manquantes**
   - Validation côté client et serveur
   - Interface intuitive pour ajout
   - Support appareil photo et galerie

5. **Problèmes Réseau**
   - Retry automatique
   - Mode hors ligne partiel
   - Synchronisation différée

## Installation et Configuration

### Base de Données
```bash
# Exécuter la migration
mysql -u root kiloshare < api/database/migrations/create_delivery_codes_table.sql
```

### Dependencies Flutter
```yaml
dependencies:
  geolocator: ^13.0.1
  image_picker: ^1.2.0
```

### Configuration API
1. Ajouter les routes dans `config/routes.php`
2. Enregistrer le contrôleur `DeliveryCodeController`
3. Configurer les services de notification

### Permissions Android
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
```

### Permissions iOS
```plist
<key>NSLocationWhenInUseUsageDescription</key>
<string>Cette application a besoin de votre localisation pour confirmer les livraisons</string>
<key>NSCameraUsageDescription</key>
<string>Cette application a besoin d'accès à l'appareil photo pour prendre des photos des colis</string>
```

## Tests et Validation

### Tests Backend
- Tests unitaires pour `DeliveryCodeService`
- Tests d'intégration pour l'API
- Tests de sécurité pour la génération de codes

### Tests Frontend
- Tests de widgets pour l'interface
- Tests d'intégration pour le flux complet
- Tests de géolocalisation et photos

### Tests Manuels
1. Générer un code pour une réservation
2. Vérifier la réception des notifications
3. Valider le code avec géolocalisation et photos
4. Tester les cas d'erreur (code incorrect, expiré)
5. Vérifier la régénération de codes

## Monitoring et Analytics

### Métriques Surveillées
- Taux de génération de codes
- Taux de validation réussie
- Temps moyen de validation
- Tentatives échouées par code
- Codes expirés non utilisés

### Logs Importants
- Génération de codes
- Tentatives de validation
- Échecs et erreurs
- Régénérations de codes

## Maintenance

### Tâches Automatiques
- Nettoyage des codes expirés (toutes les heures)
- Archivage des anciens codes (mensuel)
- Statistiques de performance (quotidien)

### Tâches Manuelles
- Analyse des métriques de sécurité
- Révision des tentatives d'intrusion
- Mise à jour des seuils de sécurité

## Évolutions Futures

### Améliorations Possibles
1. **Codes QR**: Alternative aux codes numériques
2. **Biométrie**: Validation par empreinte/visage
3. **Blockchain**: Traçabilité immuable
4. **IA**: Détection automatique de colis dans photos
5. **NFC**: Validation sans contact

### Considérations
- Compatibilité avec appareils existants
- Impact sur l'expérience utilisateur
- Coûts d'implémentation
- Sécurité renforcée vs simplicité

## Support et Dépannage

### Problèmes Courants

1. **Code non reçu**
   - Vérifier les notifications
   - Régénérer si nécessaire
   - Contacter le support

2. **Géolocalisation échoue**
   - Vérifier les permissions
   - Activer le GPS
   - Réessayer la validation

3. **Photos non acceptées**
   - Vérifier la qualité
   - Prendre de nouvelles photos
   - Vérifier la connexion

### Contact Support
- Email: support@kiloshare.com
- Documentation: docs.kiloshare.com
- GitHub: github.com/kiloshare/delivery-codes

---

*Système implémenté le 20/09/2025 - Version 1.0*