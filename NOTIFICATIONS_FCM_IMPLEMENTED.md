# Notifications FCM Implémentées - KiloShare

Ce document liste toutes les notifications push FCM qui ont été activées dans l'application.

## ✅ Infrastructure

- **SmartNotificationService**: Service intelligent qui gère les préférences utilisateur et envoie via multiple canaux (push, email, in-app, SMS)
- **FirebaseNotificationService**: Service Firebase complet avec gestion des tokens FCM
- **PushNotificationChannel**: Canal de notification push intégré

## 📱 Notifications Implémentées

### 1. 🛫 Notifications de Voyage (Admin)

#### ✅ Voyage Approuvé
- **Fichier**: `api/src/Controllers/AdminController.php:547-566`
- **Type**: `trip_approved`
- **Quand**: Lorsqu'un admin approuve un voyage en attente
- **Destinataire**: Propriétaire du voyage
- **Canaux**: Push + In-App
- **Priorité**: High
- **Message**: "Votre voyage a été approuvé et est maintenant visible sur la plateforme !"

#### ❌ Voyage Rejeté
- **Fichier**: `api/src/Controllers/AdminController.php:613-633`
- **Type**: `trip_rejected`
- **Quand**: Lorsqu'un admin rejette un voyage
- **Destinataire**: Propriétaire du voyage
- **Canaux**: Push + In-App + Email
- **Priorité**: High
- **Message**: "Votre voyage a été rejeté par l'équipe de modération."
- **Données**: Inclut la raison du rejet

### 2. 📦 Notifications de Réservation

#### 📝 Nouvelle Demande de Réservation
- **Fichier**: `api/src/Controllers/BookingController.php:125-148`
- **Types**:
  - `new_booking_request` (pour le transporteur)
  - `booking_request_received` (pour l'expéditeur)
- **Quand**: Lorsqu'un utilisateur crée une nouvelle demande de réservation
- **Destinataire**: Propriétaire du voyage (transporteur)
- **Canaux**: Push + In-App + Email
- **Priorité**: Normal
- **Données**:
  - Nom de l'expéditeur
  - Poids demandé
  - Prix total
  - Description du colis

#### ✅ Réservation Acceptée
- **Fichier**: `api/src/Controllers/BookingController.php:452-461`
- **Type**: `booking_accepted`
- **Quand**: Lorsque le transporteur accepte une demande de réservation
- **Destinataire**: Expéditeur (celui qui a fait la demande)
- **Canaux**: Push + In-App + Email
- **Priorité**: High
- **Message**: "Votre demande de réservation a été acceptée"
- **Données**:
  - Titre du voyage
  - Montant total
  - Nom du transporteur

#### ❌ Réservation Rejetée
- **Fichier**: `api/src/Controllers/BookingController.php:565-573`
- **Type**: `booking_rejected`
- **Quand**: Lorsque le transporteur refuse une demande de réservation
- **Destinataire**: Expéditeur
- **Canaux**: Push + In-App + Email
- **Priorité**: High
- **Message**: "Votre demande de réservation a été refusée"
- **Données**:
  - Nom du transporteur
  - Titre du voyage
  - Statut de remboursement

### 3. 💬 Notifications de Messagerie

#### 💬 Nouveau Message
- **Fichier**: `api/src/Services/MessagingService.php:118-138`
- **Type**: `new_message`
- **Quand**: Lorsqu'un utilisateur envoie un message dans une conversation
- **Destinataire**: Destinataire du message
- **Canaux**: Push + In-App
- **Priorité**: Normal
- **Données**:
  - Nom de l'expéditeur
  - Aperçu du message
  - ID de la conversation
  - ID de la réservation
  - Titre du voyage

### 4. 🔐 Notifications de Code de Livraison

#### 🔐 Code de Livraison Généré
- **Fichier**: `api/src/Services/DeliveryCodeService.php:162-184`
- **Type**: `delivery_code_generated`
- **Quand**: Lorsque le transporteur accepte une réservation (génération automatique)
- **Destinataire**: Expéditeur (qui recevra le code)
- **Canaux**: Push + In-App + Email
- **Priorité**: High
- **Message**: "Votre code de livraison a été généré"
- **Données**:
  - Code de livraison (6 chiffres)
  - Référence de réservation
  - Description du colis
  - Nom du transporteur
  - Trajet du voyage

#### ✅ Livraison Confirmée
- **Fichier**: `api/src/Services/DeliveryCodeService.php:474-475`
- **Type**: `delivery_confirmed`
- **Quand**: Lorsque le code de livraison est validé avec succès
- **Destinataires**: Expéditeur ET Transporteur
- **Canaux**: Push + In-App + Email
- **Priorité**: High
- **Message**: "La livraison a été confirmée avec succès"
- **Données**:
  - Référence de réservation
  - Description du colis
  - Nom expéditeur/transporteur
  - Trajet du voyage
  - Date de confirmation

### 5. 💳 Notifications de Paiement

Ces notifications sont déjà implémentées dans `SmartNotificationService.php`:

#### 🔒 Paiement Autorisé
- **Type**: `payment_authorized`
- **Méthode**: `sendPaymentAuthorizationNotification()`
- **Canaux**: Push + In-App

#### ✅ Paiement Confirmé
- **Type**: `payment_confirmed`
- **Méthode**: `sendPaymentConfirmedNotification()`
- **Canaux**: Push + In-App

#### 💳 Paiement Capturé
- **Type**: `payment_captured`
- **Méthode**: `sendPaymentCapturedNotification()`
- **Canaux**: Push + In-App + Email

#### ❌ Paiement Annulé
- **Type**: `payment_cancelled`
- **Méthode**: `sendPaymentCancelledNotification()`
- **Canaux**: Push + In-App + Email

#### ⏰ Paiement Expiré
- **Type**: `payment_expired`
- **Méthode**: `sendPaymentExpiredNotification()`
- **Canaux**: Push + In-App + Email

## 📋 Templates de Notifications

Tous les templates sont définis dans:
- **Fichier**: `api/src/Services/SmartNotificationService.php:362-435`

Les templates incluent:
- Titre personnalisé avec emoji
- Message descriptif
- Support multilingue (FR par défaut)
- Support multi-canal (push, email, in-app)

## 🔧 Configuration Requise

### Côté Backend (PHP)

1. **Firebase Service Account**: Configuré dans `config/firebase-service-account.json`
2. **Table `user_fcm_tokens`**: Pour stocker les tokens FCM des utilisateurs
3. **Table `user_notification_preferences`**: Pour gérer les préférences de notification

### Côté Frontend (Flutter)

1. **Firebase Messaging**: Package `firebase_messaging` installé
2. **Token FCM**: Enregistré automatiquement au démarrage de l'app
3. **Endpoint**: `POST /api/v1/fcm/register` pour enregistrer le token

## 📊 Préférences Utilisateur

Les utilisateurs peuvent contrôler:
- **Canaux**: Push, Email, SMS, In-App
- **Types de notifications**:
  - Mises à jour de voyage
  - Mises à jour de réservation
  - Mises à jour de paiement
  - Mises à jour de livraison
  - Alertes de sécurité
- **Heures calmes**: Bloquer les notifications pendant certaines heures
- **Langue**: FR (par défaut), autres langues à ajouter

## 🧪 Test des Notifications

### Test Manuel

1. **Enregistrer un token FCM**:
```bash
curl -X POST http://localhost:8080/api/v1/fcm/register \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"fcm_token": "YOUR_FCM_TOKEN", "platform": "android"}'
```

2. **Envoyer une notification de test**:
```bash
curl -X POST http://localhost:8080/api/v1/fcm/test \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Scénarios de Test

1. ✅ **Approbation de voyage**: Admin approuve un voyage → Propriétaire reçoit notification
2. ❌ **Rejet de voyage**: Admin rejette un voyage → Propriétaire reçoit notification avec raison
3. 📦 **Nouvelle réservation**: Utilisateur crée réservation → Transporteur reçoit notification
4. ✅ **Acceptation réservation**: Transporteur accepte → Expéditeur reçoit notification
5. 💬 **Nouveau message**: Utilisateur envoie message → Destinataire reçoit notification
6. 🔐 **Code généré**: Réservation acceptée → Expéditeur reçoit code de livraison
7. ✅ **Livraison confirmée**: Code validé → Expéditeur et Transporteur reçoivent confirmation

## 🚀 Prochaines Étapes

1. **Tester dans l'application mobile** (iOS + Android)
2. **Vérifier les préférences utilisateur** dans le profil
3. **Monitorer les logs** pour détecter les erreurs d'envoi
4. **Ajouter des statistiques** sur les notifications envoyées/reçues/ouvertes
5. **Implémenter les actions rapides** (répondre, voir détails depuis la notification)

## 📝 Notes Importantes

- Les notifications respectent les préférences utilisateur (sauf notifications critiques)
- En mode développement, les emails incluent une note indiquant le destinataire réel
- Les tokens FCM invalides sont automatiquement désactivés
- Les notifications utilisent des emojis pour une meilleure visibilité
- Le système supporte le multilingue (actuellement FR uniquement)

## 🔍 Logs et Debugging

Pour déboguer les notifications FCM:

```bash
# Logs Firebase
tail -f /path/to/logs/firebase.log

# Logs des notifications envoyées
grep "notification sent" /path/to/logs/api.log

# Logs des erreurs FCM
grep "FCM" /path/to/logs/error.log
```

## ✅ Checklist de Vérification

- [x] Infrastructure FCM configurée
- [x] SmartNotificationService opérationnel
- [x] Notifications voyage admin implémentées
- [x] Notifications réservations implémentées
- [x] Notifications messages implémentées
- [x] Notifications codes livraison implémentées
- [x] Notifications paiement implémentées (déjà existantes)
- [x] Templates de fallback créés
- [x] Syntaxe PHP validée
- [ ] Tests sur application mobile iOS
- [ ] Tests sur application mobile Android
- [ ] Vérification statistiques d'envoi

---

**Date de création**: 2025-11-11
**Dernière mise à jour**: 2025-11-11
**Statut**: ✅ Implémentation complète - Prêt pour les tests
