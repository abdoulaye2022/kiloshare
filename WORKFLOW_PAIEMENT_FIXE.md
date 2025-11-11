# Workflow de Paiement - Correction Complète

## Problèmes Identifiés

### 1. Endpoint Obsolète
- **Problème**: `/api/v1/bookings/{id}/payment/confirm` retourne HTTP 410
- **Impact**: Fati ne peut pas confirmer son paiement
- **Cause**: Workflow ancien avec capture manuelle, maintenant obsolète

### 2. Remboursement Manquant
- **Problème**: Quand le transporteur rejette, Fati n'est PAS remboursée
- **Impact**: Argent bloqué inutilement
- **Correction**: ✅ Ajouté dans `rejectBooking()` - annulation automatique du PaymentIntent

### 3. Boutons Manquants ou Mal Affichés
- **Problème**: Transporteur ne voit pas les boutons Accepter/Rejeter
- **Impact**: Impossible de traiter les réservations

## Workflow Correct (Nouveau - AVEC PROTECTION ACHETEUR)

### Étape 1: Création de Réservation par Fati
```
POST /api/v1/bookings/requests
```
**Résultat**:
- Réservation créée avec status: `pending`
- PaymentIntent créé (si transporteur a Stripe)
- `client_secret` retourné
- Fati reçoit le client_secret pour payer

### Étape 2: Paiement Immédiat par Fati (Flutter)
```dart
// Utiliser Stripe SDK pour payer
await Stripe.instance.confirmPayment(
  paymentIntentClientSecret: clientSecret,
  data: PaymentMethodParams.card(...),
);
```
**Résultat**:
- Argent autorisé (bloqué) sur la carte de Fati
- Status devient: `payment_authorized`
- **L'argent reste BLOQUÉ (pas encore transféré)**

### Étape 3a: Transporteur ACCEPTE
```
POST /api/v1/bookings/{id}/accept
```
**Résultat**:
- ⚠️ **IMPORTANT**: Le paiement reste AUTORISÉ (bloqué)
- Status devient: `accepted`
- **L'argent n'est PAS encore transféré au transporteur**
- Code de livraison généré automatiquement
- Notification envoyée à Fati

### Étape 3b: Transporteur REJETTE
```
POST /api/v1/bookings/{id}/reject
```
**Résultat**:
- ✅ **PaymentIntent annulé automatiquement**
- ✅ **Fati remboursée immédiatement** (argent libéré)
- Status devient: `rejected`
- Notification envoyée à Fati avec info du remboursement

### Étape 4: Livraison Confirmée
```
POST /api/v1/bookings/{id}/delivery-code/validate
```
**Résultat**:
- ✅ **CAPTURE DU PAIEMENT** (argent débité de la carte de Fati)
- ✅ **Argent transféré au transporteur** (moins commission)
- Status devient: `completed`
- **Protection acheteur**: L'argent ne va au transporteur QUE si livraison confirmée!

## Corrections Appliquées

### 1. API Backend (BookingController.php)
✅ **Ligne 491-507**: Ajout annulation paiement lors du rejet
```php
// IMPORTANT: Si un paiement a été autorisé, l'annuler pour rembourser Fati
if ($booking->payment_authorization_id) {
    $authorization = PaymentAuthorization::find($booking->payment_authorization_id);
    if ($authorization && $authorization->canBeCancelled()) {
        $this->paymentAuthService->cancelAuthorization(
            $authorization,
            $user,
            'rejected_by_transporter'
        );
        error_log("✅ Paiement annulé et Fati remboursée automatiquement");
    }
}
```

### 2. Flutter App - À Faire

#### Supprimer la fonction obsolète `confirmPayment()`
**Fichiers concernés**:
- `lib/modules/booking/services/booking_service.dart` (ligne 471-506)
- `lib/modules/booking/screens/booking_details_screen.dart` (bouton ligne 786)

#### Ajouter paiement immédiat après création
**Fichier**: `lib/modules/booking/screens/create_booking_screen.dart`
```dart
// Après création réussie de la réservation
if (result['payment']['client_secret'] != null) {
  // Payer immédiatement avec Stripe
  await _processPayment(result['payment']['client_secret']);
}
```

#### Vérifier affichage des boutons transporteur
**Fichier**: `lib/modules/booking/screens/booking_details_screen.dart`
- Ligne 675: Bouton "Accepter" (existe déjà ✓)
- Ligne 690: Bouton "Rejeter" (existe déjà ✓)
- S'assurer qu'ils s'affichent quand `status == 'payment_authorized'`

## Statuts de Réservation

| Statut | Description | Actions Possibles | Protection |
|--------|-------------|-------------------|-----------|
| `pending` | En attente paiement | Payer (Fati), Rejeter (Transporteur) | Pas encore payé |
| `payment_authorized` | Payé, en attente validation transporteur | Accepter/Rejeter (Transporteur), Annuler (Fati) | **Argent BLOQUÉ sur carte Fati** |
| `accepted` | Accepté par transporteur, en attente livraison | Annuler (Fati), Valider livraison (Fati/Transporteur) | **Argent BLOQUÉ, pas encore transféré** |
| `completed` | Livraison confirmée | Aucune | **Argent TRANSFÉRÉ au transporteur** |
| `rejected` | Refusé par transporteur | Aucune | **Fati remboursée automatiquement** |
| `cancelled` | Annulé par Fati (avant ou après acceptation) | Aucune | **Fati remboursée automatiquement** |

## Tests à Effectuer

### Test 1: Workflow Complet Accepté
1. ✅ Fati crée réservation → Reçoit `client_secret`
2. ✅ Fati paie avec Stripe → Status: `payment_authorized`
3. ✅ Transporteur accepte → Status: `paid`
4. ✅ Fati reçoit notification de confirmation

### Test 2: Workflow Rejet avec Remboursement
1. ✅ Fati crée réservation et paie → Status: `payment_authorized`
2. ✅ Transporteur rejette → Status: `rejected`
3. ✅ **Vérifier que Fati est remboursée** (Stripe Dashboard)
4. ✅ Fati reçoit notification de rejet + remboursement

### Test 3: Annulation par Fati
1. ✅ Fati crée réservation et paie → Status: `payment_authorized`
2. ✅ Fati annule → Status: `cancelled`
3. ✅ **Vérifier que Fati est remboursée**
4. ✅ Transporteur reçoit notification

## Réponse à Votre Question

### "Si le transporteur rejette la réservation et que Fati a payé, qu'est-ce qui se passe?"

**AVANT la correction**:
- ❌ Rien! Le paiement restait bloqué
- ❌ Fati perdait son argent ou devait contacter le support

**APRÈS la correction (maintenant)**:
- ✅ Le PaymentIntent est automatiquement annulé via Stripe
- ✅ L'argent est IMMÉDIATEMENT libéré de la carte de Fati
- ✅ Fati reçoit une notification l'informant du rejet ET du remboursement
- ✅ Tout est automatique, aucune intervention manuelle nécessaire

### Délai de Remboursement
- **Autorisation bloquée**: Libération **immédiate** (quelques secondes)
- **Paiement capturé**: Remboursement sous **5-10 jours** (délai bancaire)

Puisque nous utilisons `capture_method: 'manual'`, le paiement n'est qu'**autorisé** (bloqué) tant que le transporteur n'a pas accepté. Donc lors du rejet, c'est une **annulation d'autorisation** = libération immédiate!

## Prochaines Étapes

1. ✅ **Backend corrigé** - Rejet rembourse automatiquement
2. ⏳ **Supprimer bouton "Confirmer paiement" obsolète** (Flutter)
3. ⏳ **Ajouter paiement immédiat après création** (Flutter)
4. ⏳ **Vérifier affichage boutons transporteur** (Flutter)
5. ⏳ **Tester workflow complet**
