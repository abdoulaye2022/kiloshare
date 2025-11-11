# Exemples de Tests pour les Notifications FCM

Ce document contient des exemples concrets pour tester toutes les notifications implémentées.

## 📱 Configuration Initiale

### 1. Enregistrer un Token FCM

Avant de pouvoir recevoir des notifications, l'application mobile doit enregistrer son token FCM:

```bash
curl -X POST http://localhost:8080/api/v1/fcm/register \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fcm_token": "YOUR_DEVICE_FCM_TOKEN",
    "platform": "android"
  }'
```

**Réponse attendue:**
```json
{
  "success": true,
  "message": "FCM token registered successfully"
}
```

### 2. Vérifier les Tokens Enregistrés

```sql
-- Dans MySQL
SELECT * FROM user_fcm_tokens WHERE user_id = YOUR_USER_ID AND is_active = 1;
```

## 🧪 Tests par Catégorie

### 🛫 1. Notifications de Voyage (Admin)

#### Test 1.1: Approbation de Voyage

**Prérequis:**
- Un voyage avec `status = 'pending_approval'`
- Un compte admin

**Étapes:**
1. Se connecter en tant qu'admin
2. Approuver le voyage via le panel admin

**API Call:**
```bash
curl -X POST http://localhost:8080/api/v1/admin/trips/approve \
  -H "Authorization: Bearer ADMIN_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1
  }'
```

**Notification attendue:**
- **Titre**: ✅ Voyage approuvé
- **Corps**: Votre voyage a été approuvé par les modérateurs
- **Destinataire**: Propriétaire du voyage
- **Données**:
  ```json
  {
    "trip_id": 1,
    "trip_title": "Paris → Lyon",
    "departure_date": "15/12/2025",
    "message": "Votre voyage a été approuvé et est maintenant visible sur la plateforme !"
  }
  ```

#### Test 1.2: Rejet de Voyage

**API Call:**
```bash
curl -X POST http://localhost:8080/api/v1/admin/trips/reject \
  -H "Authorization: Bearer ADMIN_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": 2,
    "reason": "Photos non conformes aux règles de la communauté"
  }'
```

**Notification attendue:**
- **Titre**: ❌ Voyage refusé
- **Corps**: Votre voyage a été refusé par les modérateurs
- **Canaux**: Push + Email + In-App
- **Données**: Inclut la raison du rejet

### 📦 2. Notifications de Réservation

#### Test 2.1: Nouvelle Demande de Réservation

**Scénario:**
Un utilisateur (Fati) crée une demande de réservation pour un voyage d'Ali.

**API Call:**
```bash
curl -X POST http://localhost:8080/api/v1/bookings \
  -H "Authorization: Bearer FATI_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "trip_id": 1,
    "weight": 5,
    "package_description": "Vêtements et cadeaux",
    "pickup_address": "123 Rue de Paris, 75001",
    "delivery_address": "456 Avenue de Lyon, 69001"
  }'
```

**Notifications attendues:**

**Pour Ali (transporteur):**
- **Titre**: 📦 Nouvelle demande
- **Corps**: Vous avez reçu une nouvelle demande de réservation
- **Données**:
  ```json
  {
    "sender_name": "Fati Mohamed",
    "weight": 5,
    "price": 50,
    "package_description": "Vêtements et cadeaux"
  }
  ```

**Pour Fati (expéditeur):**
- **Titre**: 📦 Demande envoyée
- **Corps**: Votre demande de réservation a été envoyée

#### Test 2.2: Acceptation de Réservation

**Scénario:**
Ali accepte la demande de Fati.

**API Call:**
```bash
curl -X POST http://localhost:8080/api/v1/bookings/1/accept \
  -H "Authorization: Bearer ALI_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

**Notification attendue pour Fati:**
- **Titre**: ✅ Demande acceptée
- **Corps**: Votre demande de réservation a été acceptée
- **Canaux**: Push + Email + In-App
- **Données**:
  ```json
  {
    "trip_title": "Paris → Lyon",
    "total_amount": 50,
    "transporter_name": "Ali Sani"
  }
  ```

#### Test 2.3: Rejet de Réservation

**API Call:**
```bash
curl -X POST http://localhost:8080/api/v1/bookings/1/reject \
  -H "Authorization: Bearer ALI_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Espace insuffisant"
  }'
```

**Notification attendue pour Fati:**
- **Titre**: ❌ Demande refusée
- **Corps**: Votre demande de réservation a été refusée
- **Données**: Inclut le statut de remboursement

### 💬 3. Notifications de Messagerie

#### Test 3.1: Nouveau Message

**Scénario:**
Fati envoie un message à Ali dans la conversation de la réservation.

**API Call:**
```bash
curl -X POST http://localhost:8080/api/v1/conversations/1/messages \
  -H "Authorization: Bearer FATI_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Bonjour, pouvez-vous confirmer l'heure de livraison ?",
    "type": "text"
  }'
```

**Notification attendue pour Ali:**
- **Titre**: 💬 Nouveau message
- **Corps**: Fati Mohamed vous a envoyé un message
- **Données**:
  ```json
  {
    "sender_name": "Fati Mohamed",
    "message_preview": "Bonjour, pouvez-vous confirmer l'heure de livraison ?",
    "conversation_id": 1,
    "booking_id": 1,
    "trip_title": "Paris → Lyon"
  }
  ```

### 🔐 4. Notifications de Code de Livraison

#### Test 4.1: Code de Livraison Généré

**Scénario:**
Lorsqu'Ali accepte la réservation, un code est automatiquement généré et envoyé à Fati.

**Code automatique lors de l'acceptation de réservation** (voir Test 2.2)

**Notification attendue pour Fati:**
- **Titre**: 🔐 Code de livraison
- **Corps**: Votre code de livraison a été généré
- **Canaux**: Push + Email + In-App
- **Données**:
  ```json
  {
    "delivery_code": "062127",
    "booking_id": 1,
    "booking_reference": "BKG-ABC123",
    "package_description": "Vêtements et cadeaux",
    "receiver_name": "Ali",
    "trip_route": "Paris → Lyon"
  }
  ```

#### Test 4.2: Validation du Code de Livraison

**Scénario:**
Ali valide le code de livraison que Fati lui communique.

**API Call:**
```bash
curl -X POST http://localhost:8080/api/v1/bookings/1/delivery-code/validate \
  -H "Authorization: Bearer ALI_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "062127",
    "latitude": 48.8566,
    "longitude": 2.3522,
    "photos": []
  }'
```

**Notifications attendues:**

**Pour Fati (expéditeur):**
- **Titre**: ✅ Livraison confirmée
- **Corps**: La livraison a été confirmée avec succès
- **Email**: Confirmation détaillée avec infos du voyage

**Pour Ali (transporteur):**
- **Titre**: ✅ Livraison confirmée
- **Corps**: Livraison validée - Le paiement sera traité
- **Email**: Confirmation de validation

### 💳 5. Notifications de Paiement

Ces notifications sont déclenchées automatiquement par le système.

#### Test 5.1: Paiement Autorisé

**Déclenché automatiquement** lors de la création d'une réservation avec paiement.

**Notification attendue pour Fati:**
- **Titre**: 🔒 Paiement autorisé
- **Corps**: Votre paiement a été pré-autorisé
- **Canaux**: Push + In-App

#### Test 5.2: Paiement Capturé

**Déclenché automatiquement** lors de la validation du code de livraison.

**Notifications attendues:**

**Pour Fati:**
- **Titre**: 💳 Paiement effectué
- **Corps**: Le paiement a été effectué avec succès
- **Canaux**: Push + Email + In-App

**Pour Ali:**
- **Titre**: 💰 Paiement reçu
- **Corps**: Vous avez reçu un paiement
- **Canaux**: Push + In-App

## 🔍 Vérification des Notifications

### Logs Backend

```bash
# Voir les notifications envoyées
tail -f api/logs/error.log | grep "notification sent"

# Voir les erreurs FCM
tail -f api/logs/error.log | grep "FCM"

# Voir les notifications de livraison
tail -f api/logs/error.log | grep "Delivery code"
```

### Base de Données

```sql
-- Vérifier les notifications créées (in-app)
SELECT * FROM notifications
WHERE user_id = YOUR_USER_ID
ORDER BY created_at DESC
LIMIT 10;

-- Vérifier les logs d'envoi
SELECT * FROM notification_logs
WHERE user_id = YOUR_USER_ID
ORDER BY created_at DESC
LIMIT 10;

-- Vérifier les tokens FCM actifs
SELECT u.id, u.email, u.first_name, COUNT(f.id) as token_count
FROM users u
LEFT JOIN user_fcm_tokens f ON u.id = f.user_id AND f.is_active = 1
GROUP BY u.id
HAVING token_count > 0;
```

### Application Mobile

1. **Vérifier l'enregistrement du token:**
   - Logs Flutter: Rechercher "FCM Token"
   - Vérifier que le token est bien envoyé au backend

2. **Vérifier la réception:**
   - Android: Notifications système + logs Logcat
   - iOS: Notifications système + logs Xcode

3. **Tester les permissions:**
   - Vérifier que l'application a les permissions de notification
   - Vérifier que les notifications ne sont pas en mode silencieux

## 🧪 Test de Notification Manuel

Pour envoyer une notification de test manuelle:

```bash
curl -X POST http://localhost:8080/api/v1/fcm/test \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

**Notification de test reçue:**
- **Titre**: 🧪 Test KiloShare
- **Corps**: Cette notification confirme que votre système de notifications fonctionne correctement !

## 📊 Statistiques de Notifications

Pour voir les statistiques des tokens:

```bash
curl -X GET http://localhost:8080/api/v1/fcm/stats \
  -H "Authorization: Bearer ADMIN_JWT_TOKEN"
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "total_tokens": 45,
    "active_tokens": 38,
    "inactive_tokens": 7,
    "unique_users": 32
  }
}
```

## 🐛 Résolution de Problèmes

### Problème: Notification non reçue

**Checklist:**
1. ✅ Token FCM enregistré et actif
2. ✅ Firebase configuré correctement (`firebase-service-account.json`)
3. ✅ Permissions notifications activées sur l'appareil
4. ✅ Application en premier plan ou arrière-plan
5. ✅ Logs backend montrent "notification sent successfully"

### Problème: Token invalide

```sql
-- Vérifier les tokens invalides
SELECT * FROM user_fcm_tokens
WHERE is_active = 0
ORDER BY updated_at DESC;
```

Les tokens invalides sont automatiquement désactivés par le système.

### Problème: Notifications en double

Vérifier qu'un seul token est actif par utilisateur:

```sql
SELECT user_id, COUNT(*) as active_tokens
FROM user_fcm_tokens
WHERE is_active = 1
GROUP BY user_id
HAVING active_tokens > 1;
```

## ✅ Checklist de Test Complète

- [ ] Token FCM enregistré avec succès
- [ ] Notification de test reçue
- [ ] **Voyage**: Approbation reçue
- [ ] **Voyage**: Rejet reçu avec raison
- [ ] **Réservation**: Nouvelle demande reçue
- [ ] **Réservation**: Acceptation reçue
- [ ] **Réservation**: Rejet reçu
- [ ] **Message**: Nouveau message reçu
- [ ] **Code**: Code de livraison reçu
- [ ] **Livraison**: Confirmation reçue (expéditeur + transporteur)
- [ ] **Paiement**: Autorisation reçue
- [ ] **Paiement**: Capture reçue
- [ ] Notifications respectent les préférences utilisateur
- [ ] Notifications affichent les bonnes données
- [ ] Actions sur notification fonctionnent (ouvrir détails)

---

**Date de création**: 2025-11-11
**Dernière mise à jour**: 2025-11-11
