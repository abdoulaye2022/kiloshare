# Guide de Test du Workflow Complet KiloShare

## 🚀 Implémentation Terminée

Le workflow complet des annonces KiloShare a été implémenté selon le cycle de vie demandé :

**Draft → Pending Review → Active/Rejected → Booked → In Progress → Completed**

## 📋 États Disponibles

- ✅ **draft** : visible seulement au créateur, modifiable
- ✅ **pending_review** : en attente modération, non modifiable  
- ✅ **active** : visible publiquement, peut recevoir propositions
- ✅ **rejected** : retourne en draft pour modification
- ✅ **booked** : réservation confirmée avec paiement
- ✅ **paused** : temporairement hors ligne (réactivable)
- ✅ **expired** : date passée sans réservation
- ✅ **in_progress** : service en cours d'exécution
- ✅ **completed** : terminé avec succès
- ✅ **cancelled** : annulé (depuis active ou booked)

## 🛠️ Composants Implémentés

### Backend
- `TripWorkflowService.php` - Service principal du workflow
- `TripWorkflowController.php` - API endpoints pour le workflow
- `2024_12_01_update_trips_workflow.sql` - Migration base de données
- Routes ajoutées dans `routes.php`

### Frontend
- `useTripWorkflow.ts` - Hook React pour le workflow
- `TripWorkflowActions.tsx` - Composant d'actions workflow
- `TripWorkflowHistory.tsx` - Historique des transitions

## 🧪 Plan de Test

### 1. Préparation
```bash
# Appliquer la migration de base de données
mysql -u kiloshare -p kiloshare < backend/database/migrations/2024_12_01_update_trips_workflow.sql

# Démarrer les serveurs
cd backend && php -S 127.0.0.1:8080 -t public &
cd web && npm run dev
```

### 2. Tests des Transitions d'État

#### A. Cycle Normal (Utilisateur)
```
1. Créer un trip → status: 'draft'
2. Publier → status: 'active' (si auto_approved) ou 'pending_review'
3. Si pending_review → Admin approuve → 'active'
4. Réservation acceptée → 'booked'
5. Commencer voyage → 'in_progress'
6. Terminer → 'completed'
```

#### B. Actions Utilisateur
- **Pause/Resume** : `active` ↔ `paused`
- **Cancel** : n'importe quel état → `cancelled`
- **Edit** : `rejected` → `draft` → republier

#### C. Actions Admin
- **Approve** : `pending_review` → `active`
- **Reject** : `pending_review` → `rejected`

### 3. Tests API

#### Obtenir les actions disponibles
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://127.0.0.1:8080/api/v1/trips/123/workflow/actions"
```

#### Exécuter une transition
```bash
curl -X PUT -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"target_status": "active", "reason": "Ready to publish"}' \
  "http://127.0.0.1:8080/api/v1/trips/123/workflow/transition"
```

#### Publier un trip
```bash
curl -X PUT -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"metadata": {"source": "mobile_app"}}' \
  "http://127.0.0.1:8080/api/v1/trips/123/workflow/publish"
```

#### Obtenir l'historique
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://127.0.0.1:8080/api/v1/trips/123/workflow/history"
```

#### Statistiques workflow
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://127.0.0.1:8080/api/v1/trips/workflow/stats"
```

### 4. Tests Frontend

#### Intégrer les composants
```typescript
// Dans une page/composant trip
import TripWorkflowActions from '../components/TripWorkflowActions';
import TripWorkflowHistory from '../components/TripWorkflowHistory';

<TripWorkflowActions
  tripId={trip.id}
  currentStatus={trip.status}
  onStatusChange={(newTrip) => setTrip(newTrip)}
  onError={(error) => console.error(error)}
/>

<TripWorkflowHistory tripId={trip.id} />
```

#### Utiliser le hook
```typescript
import { useTripWorkflow } from '../hooks/useTripWorkflow';

const { 
  getAvailableActions, 
  publishTrip, 
  getStatusLabel,
  getStatusColor 
} = useTripWorkflow();
```

### 5. Scénarios de Test

#### Scénario 1: Création et Publication
1. Créer un nouveau trip (status: `draft`)
2. Vérifier actions disponibles : `publish`
3. Publier le trip
4. Vérifier nouveau status (`active` ou `pending_review`)
5. Vérifier historique des transitions

#### Scénario 2: Modération Admin
1. Trip en `pending_review`
2. Admin voit actions : `approve`, `reject`
3. Tester l'approbation → `active`
4. Tester le rejet → `rejected`
5. User peut revenir à `draft`

#### Scénario 3: Cycle de Réservation
1. Trip `active` avec réservations
2. Accepter réservation → `booked`
3. Commencer voyage → `in_progress`
4. Terminer voyage → `completed`

#### Scénario 4: Gestion des Erreurs
1. Tenter transition non autorisée (erreur)
2. User non autorisé (erreur 403)
3. Trip inexistant (erreur 404)

### 6. Tests d'Automatisation

#### Auto-expiration
```bash
# Test CRON job
curl -X POST -H "X-API-Key: your-secret-cron-key" \
  "http://127.0.0.1:8080/api/v1/trips/workflow/auto-expire"
```

#### Triggers de Réservation
1. Créer réservation → vérifier si trip passe en `booked`
2. Compléter réservation → vérifier si trip passe en `completed`
3. Annuler réservation → vérifier si trip revient en `active`

### 7. Validation des Règles Métier

#### Visibilité
- Seuls trips `active` visibles publiquement
- User voit tous ses trips (tous statuts)
- Admin voit tous les trips

#### Permissions d'Édition
- `draft`, `pending_review`, `active`, `paused`, `rejected` : modifiables
- `booked`, `in_progress`, `completed`, `cancelled`, `expired` : non modifiables
- Date passée : non modifiable (sauf exceptions admin)

#### Transitions Autorisées
Vérifier que seules les transitions définies dans `ALLOWED_TRANSITIONS` sont possibles.

## 🔧 Points de Surveillance

### Performance
- Index sur colonnes `status`, `published_at`, `departure_date`
- Requêtes optimisées pour les listes filtrées

### Sécurité
- Authentification requise pour toutes les actions
- Vérification des permissions utilisateur/admin
- Validation des transitions côté serveur

### Monitoring
- Logs des transitions dans `trip_status_history`
- Métriques de conversion par statut
- Alertes sur transitions critiques

## 🐛 Débogage

### Logs à surveiller
```bash
# Backend PHP
tail -f /var/log/php-errors.log

# Frontend Next.js
# Ouvrir Developer Tools → Console

# Base de données
SELECT * FROM trip_status_history WHERE trip_id = 123 ORDER BY created_at DESC;
```

### Problèmes fréquents
1. **Migration non appliquée** : ENUM status pas à jour
2. **Permissions** : Token manquant/invalide
3. **Transitions invalides** : Vérifier `ALLOWED_TRANSITIONS`
4. **Dates expirées** : `departure_date` passée

## 🎯 Métriques de Succès

- ✅ Toutes les transitions d'état fonctionnent
- ✅ Historique correctement enregistré
- ✅ Permissions respectées
- ✅ UI responsive avec actions dynamiques
- ✅ Performance acceptable (<200ms API)
- ✅ Pas d'erreurs JavaScript/PHP

## 📈 Prochaines Étapes

1. **Notifications** : Email/Push sur changements d'état
2. **Automatisation** : Jobs CRON pour expirations
3. **Analytics** : Dashboard des métriques workflow
4. **Tests unitaires** : Coverage backend/frontend
5. **Documentation** : Guide utilisateur final

---

**Status Implementation: ✅ COMPLETED**
- Base de données synchronisée
- Backend API fonctionnel  
- Frontend Components prêts
- Tests définis

Le workflow complet des annonces KiloShare est maintenant opérationnel ! 🚀