# KiloShare Database Documentation

## Vue d'ensemble

Base de données MySQL pour la plateforme KiloShare - Service de transport collaboratif de colis.

**Dernière mise à jour**: 2025-11-12
**Total des tables**: 35 tables

---

## 📊 Structure de la base de données

### 🔐 Authentification & Utilisateurs (5 tables)
- `users` - Comptes utilisateurs (transporteurs et expéditeurs)
- `user_tokens` - Tokens JWT pour l'authentification
- `user_fcm_tokens` - Tokens Firebase Cloud Messaging pour notifications push
- `email_verifications` - Vérifications d'emails
- `verification_codes` - Codes de vérification (email, téléphone, livraison)

### 💳 Paiements Stripe (3 tables)
- `user_stripe_accounts` - Comptes Stripe Connect des transporteurs
- `payment_authorizations` - Autorisations de paiement (PaymentIntent)
- `transactions` - Historique des transactions (captures, transfers, refunds)

### ✈️ Voyages & Réservations (6 tables)
- `trips` - Voyages créés par les transporteurs
- `trip_images` - Photos des voyages
- `bookings` - Réservations de transport de colis
- `trip_favorites` - Voyages favoris des utilisateurs
- `trip_views` - Statistiques de vues des voyages
- `trip_shares` - Partages de voyages

### 📦 Livraison (1 table)
- `delivery_codes` - Codes de livraison pour validation

### 💬 Messagerie (4 tables)
- `conversations` - Conversations entre utilisateurs
- `conversation_participants` - Participants aux conversations
- `messages` - Messages envoyés
- `message_reads` - Statuts de lecture des messages

### 🔔 Notifications (4 tables)
- `notifications` - Notifications système
- `notification_logs` - Logs d'envoi de notifications
- `notification_templates` - Templates d'emails/notifications
- `user_notification_preferences` - Préférences de notification par utilisateur

### ⭐ Évaluations (4 tables)
- `reviews` - Avis laissés après livraison
- `user_ratings` - Notes globales des utilisateurs
- `user_reliability_history` - Historique de fiabilité
- `review_reminders` - Rappels pour laisser un avis

### 🛠️ Administration (2 tables)
- `admin_actions` - Actions effectuées par les administrateurs
- `payment_events_log` - Logs des événements Stripe

### 📋 Autres (6 tables)
- `contact_revelations` - Révélations de contact (téléphone)
- `cancellation_attempts` - Tentatives d'annulation
- `escrow_accounts` - Comptes d'entiercement (legacy)
- `payment_configurations` - Configurations de paiement
- `scheduled_jobs` - Tâches planifiées
- `trip_reports` - Signalements de voyages

---

## 🗂️ Tables principales

### `users`
Table centrale des utilisateurs.

**Colonnes clés**:
- `role` - Rôle: user, admin
- `email` - Email unique
- `phone` - Téléphone (optionnel)
- `is_verified` - Compte vérifié
- `profile_picture` - Photo de profil (Google Cloud Storage)

**Indexes**:
- `email` (UNIQUE)
- `phone` (UNIQUE)
- `uuid` (UNIQUE)

---

### `trips`
Voyages créés par les transporteurs.

**Colonnes clés**:
- `user_id` - ID du transporteur
- `transport_type` - Type: plane, train, car, bus
- `departure_city` / `arrival_city` - Villes de départ/arrivée
- `departure_date` / `arrival_date` - Dates de voyage
- `available_weight_kg` - Poids disponible
- `price_per_kg` - Prix par kg
- `status` - Statut: draft, active, completed, cancelled

**Relations**:
- `user_id` → `users.id`

---

### `bookings`
Réservations de transport.

**Colonnes clés**:
- `trip_id` - Voyage réservé
- `sender_id` - Expéditeur du colis
- `receiver_id` - Transporteur (propriétaire du voyage)
- `package_description` - Description du colis
- `weight_kg` - Poids
- `total_price` - Prix total
- `status` - Statut du booking (15 états possibles)
- `commission_rate` - Taux de commission (défaut: 15%)

**Status possibles**:
- `pending` - En attente d'acceptation
- `accepted` - Accepté par le transporteur
- `rejected` - Refusé
- `payment_authorized` - Paiement autorisé (non capturé)
- `payment_confirmed` - Paiement confirmé
- `paid` - Paiement capturé
- `in_transit` - En transit
- `delivered` - Livré
- `completed` - Complété (code validé)
- `cancelled` - Annulé
- `payment_failed` / `payment_expired` / `payment_cancelled` - Échecs de paiement
- `refunded` - Remboursé

**Relations**:
- `trip_id` → `trips.id`
- `sender_id` → `users.id`
- `receiver_id` → `users.id`
- `payment_authorization_id` → `payment_authorizations.id`

---

### `payment_authorizations`
Autorisations de paiement Stripe.

**Colonnes clés**:
- `booking_id` - Réservation associée
- `payment_intent_id` - ID PaymentIntent Stripe
- `stripe_account_id` - Compte Stripe Connect du transporteur
- `amount_cents` - Montant total en cents
- `platform_fee_cents` - Commission plateforme en cents
- `status` - Statut: pending, authorized, captured, cancelled, failed, expired, refunded
- `captured_at` - Date de capture
- `transferred_at` - Date de transfert au transporteur
- `transfer_id` - ID du Transfer Stripe

**Workflow de paiement**:
1. Création → `status = pending`
2. Autorisation → `status = authorized`
3. Capture → `status = captured` + `captured_at`
4. Transfert → `transferred_at` + `transfer_id`

---

### `delivery_codes`
Codes de livraison pour validation.

**Colonnes clés**:
- `booking_id` - Réservation associée
- `code` - Code à 6 chiffres
- `validated_at` - Date de validation
- `validated_by` - Utilisateur qui a validé

**Process**:
1. Généré automatiquement à la création du booking
2. Communiqué au destinataire
3. Validé par le transporteur à la livraison

---

### `conversations` & `messages`
Système de messagerie interne.

**`conversations`**:
- `title` - Titre de la conversation
- `last_message_at` - Dernier message envoyé

**`messages`**:
- `conversation_id` - Conversation
- `sender_id` - Expéditeur
- `content` - Contenu du message
- `read_at` - Date de lecture

---

## 🔗 Relations importantes

```
users (1) ←→ (N) trips
users (1) ←→ (N) bookings (sender)
users (1) ←→ (N) bookings (receiver)
trips (1) ←→ (N) bookings
bookings (1) ←→ (1) payment_authorizations
bookings (1) ←→ (1) delivery_codes
users (1) ←→ (1) user_stripe_accounts
payment_authorizations (1) ←→ (N) transactions
```

---

## 📝 Utilisation

### Importer le schéma
```bash
mysql -u root kiloshare < schema.sql
```

### Exporter le schéma mis à jour
```bash
mysqldump -u root --no-data --skip-comments kiloshare > schema.sql
```

### Sauvegarder les données
```bash
mysqldump -u root kiloshare > backup_$(date +%Y%m%d_%H%M%S).sql
```

---

## 🔐 Sécurité

- ✅ Tous les mots de passe hashés avec bcrypt
- ✅ Tokens JWT avec expiration
- ✅ Foreign keys avec CASCADE pour intégrité référentielle
- ✅ Indexes sur colonnes fréquemment requêtées
- ✅ UTF8MB4 pour support emoji et caractères internationaux

---

## 📊 Performance

### Indexes principaux

**users**:
- `email`, `phone`, `uuid` (UNIQUE)

**trips**:
- `user_id`, `status`, `departure_date`

**bookings**:
- `trip_id`, `sender_id`, `receiver_id`, `status`, `uuid`

**payment_authorizations**:
- `booking_id`, `payment_intent_id` (UNIQUE)

---

## 🚀 Évolutions futures possibles

- [ ] Table `disputes` pour litiges
- [ ] Table `refund_requests` pour demandes de remboursement
- [ ] Table `promotions` pour codes promo
- [ ] Table `user_documents` pour documents d'identité
- [ ] Table `push_notifications` pour historique des push
- [ ] Partitionnement de `messages` par date
- [ ] Archivage des anciens `trips` et `bookings`

---

**Maintenu par**: Équipe KiloShare
**Contact**: admin@kiloshare.com
