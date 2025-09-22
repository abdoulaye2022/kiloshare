# Système de Gestion Intelligente des Annulations - KiloShare

## Vue d'ensemble

Le système de gestion intelligente des annulations de KiloShare implémente des règles métier sophistiquées pour protéger l'expérience utilisateur tout en maintenant la fiabilité de la plateforme.

## Fonctionnalités Principales

### 1. Analyse Intelligente des Conditions d'Annulation

**Endpoint:** `GET /api/v1/trips/{id}/intelligent-cancellation-check`

Analyse automatiquement :
- Délai avant départ (48h+, 24-48h, <24h)
- Présence de réservations confirmées/payées
- Historique d'annulation de l'utilisateur
- Score de fiabilité actuel
- Limites d'annulation par profil utilisateur

**Réponse exemple :**
```json
{
  "success": true,
  "data": {
    "analysis": {
      "allowed": true,
      "category": "impact_cancellation",
      "severity": "medium",
      "hours_until_departure": 36,
      "bookings": {
        "total_count": 2,
        "confirmed_count": 2,
        "paid_count": 0,
        "affected_users": [15, 23]
      },
      "user_profile": {
        "user_type": "confirmed",
        "cancellations_this_month": 0,
        "max_allowed_cancellations": 2,
        "reliability_score": 85,
        "is_first_cancellation": true
      },
      "consequences": {
        "penalty_duration": 7,
        "reliability_impact": -2,
        "restriction_type": "publication_restriction",
        "refunds_required": false,
        "notifications_count": 2
      },
      "actions_required": ["notify_affected_users", "suggest_alternatives"]
    }
  }
}
```

### 2. Exécution d'Annulation Intelligente

**Endpoint:** `POST /api/v1/trips/{id}/intelligent-cancel`

**Body :**
```json
{
  "reason": "Changement imprévu de planning",
  "confirm_refunds": true
}
```

Actions automatiques selon le type d'annulation :
- **Annulation libre (48h+, pas de réservations)** : Aucune pénalité
- **Annulation avec impact (24-48h)** : Restriction 7 jours, score -2
- **Annulation critique (<24h, paiements)** : Suspension 30 jours, score -5, remboursements auto

### 3. Système de Scoring de Fiabilité

**Endpoint:** `GET /api/v1/user/reliability-score`

**Facteurs de calcul :**
- **Taux de completion (30%)** : Voyages complétés vs annulés
- **Taux d'annulation (25%)** : Fréquence des annulations sur 6 mois
- **Fiabilité réservations (20%)** : Comportement en tant qu'expéditeur
- **Évaluations utilisateurs (15%)** : Notes moyennes reçues
- **Ancienneté compte (10%)** : Bonus selon l'âge du compte

**Niveaux d'utilisateur :**
- **Nouveau (new)** : 1 annulation/mois max
- **Confirmé (confirmed)** : 2 annulations/mois max (3+ voyages, 2+ mois)
- **Expert (expert)** : 3 annulations/mois max (10+ voyages, 6+ mois)

### 4. Remboursements Automatiques

**Types de remboursement :**
- **Remboursement intégral** : Annulation par le voyageur
- **Remboursement standard** : Montant - frais KiloShare - frais Stripe
- **Remboursement partiel** : 50% expéditeur, 50% compensation voyageur
- **Pas de remboursement** : Compensation uniquement au voyageur

### 5. Notifications Intelligentes

Notifications contextuelles selon la gravité :
- **Severity faible** : Push + In-app
- **Severity élevée** : Push + In-app + Email
- **Critique** : Tous les canaux + Support automatique

### 6. Alternatives Automatiques

**Endpoint:** `GET /api/v1/trips/{id}/alternatives`

Suggestions basées sur :
- Même itinéraire (ville départ/arrivée)
- Dates similaires (±3 jours)
- Prix comparable (±20%)
- Capacité disponible suffisante

## Interface d'Administration

### Dashboard des Annulations

**Endpoint:** `GET /api/v1/admin/cancellations/dashboard`

Métriques incluses :
- Nombre total d'annulations par période
- Répartition par type et gravité
- Utilisateurs impactés
- Remboursements traités
- Pénalités appliquées
- Évolution des scores de fiabilité

### Gestion des Exceptions

**Endpoint:** `POST /api/v1/admin/cancellations/exceptions`

Types d'exceptions :
- **Force majeure** : Catastrophes naturelles, pandémie
- **Problème technique** : Bug application, panne système
- **Utilisateur première fois** : Clémence pour nouveaux utilisateurs

Actions disponibles :
- Suppression des pénalités
- Restauration du score de fiabilité
- Remboursement manuel
- Réinitialisation complète du profil

### Support Automatique

Tickets générés automatiquement pour :
- Annulations critiques avec montants élevés
- Utilisateurs récidivistes
- Problèmes de remboursement
- Disputes utilisateurs

## Workflow Utilisateur

### 1. Déclenchement de l'Annulation
```
Utilisateur → "Annuler voyage" → Analyse intelligente
```

### 2. Affichage des Conséquences
```
Interface → Montre impacts (pénalités, remboursements, restrictions)
```

### 3. Confirmation et Exécution
```
Utilisateur confirme → Traitement automatique → Notifications
```

### 4. Suivi Post-Annulation
```
Alternatives suggérées → Support si besoin → Suivi admin
```

## Configuration des Politiques

Les politiques d'annulation sont configurables via la table `cancellation_policies` :

```sql
-- Exemple de politique personnalisée
INSERT INTO cancellation_policies
(policy_name, hours_before_departure_min, hours_before_departure_max,
 has_bookings, has_payments, penalty_duration_days, reliability_impact,
 refund_percentage, restriction_type)
VALUES
('Politique VIP', 12, 24, TRUE, TRUE, 3, -1, 100.00, 'warning');
```

## Monitoring et Analytics

### Métriques Clés
- Taux d'annulation global par période
- Distribution des scores de fiabilité
- Efficacité des suggestions d'alternatives
- Temps de résolution des tickets support
- Impact financier des remboursements

### Alertes Automatiques
- Pic d'annulations anormal
- Utilisateur dépassant les seuils
- Problèmes de remboursement
- Scores de fiabilité en chute libre

## Intégration Frontend

### Composants Suggérés

1. **CancellationAnalysisModal** : Affiche l'analyse et les conséquences
2. **ReliabilityScoreWidget** : Montre le score utilisateur
3. **AlternativeSuggestions** : Liste des voyages alternatifs
4. **CancellationHistory** : Historique des annulations utilisateur
5. **AdminCancellationDashboard** : Interface de supervision

### États de l'Interface

```typescript
interface CancellationState {
  isAnalyzing: boolean;
  analysis: CancellationAnalysis | null;
  isProcessing: boolean;
  alternatives: TripAlternative[];
  userReliability: UserReliability;
}
```

## Sécurité et Conformité

### Protection Contre l'Abus
- Limites strictes par profil utilisateur
- Scoring de fiabilité avec impact durable
- Escalade automatique vers support humain
- Tracking détaillé de toutes les actions

### Conformité Réglementaire
- Respect des délais légaux de remboursement
- Transparence sur les frais appliqués
- Conservation des preuves d'annulation
- Possibilité d'export des données utilisateur

## Tests et Validation

### Scénarios de Test Recommandés

1. **Annulation libre** : Voyage 72h avant départ, aucune réservation
2. **Annulation impact** : Voyage 30h avant, 2 réservations non payées
3. **Annulation critique** : Voyage 12h avant, réservations payées
4. **Limite dépassée** : 3e annulation du mois pour utilisateur "confirmé"
5. **Exception admin** : Force majeure avec suppression pénalités

### Métriques de Performance
- Temps d'analyse < 500ms
- Traitement d'annulation < 5s
- Remboursements traités < 24h
- Notifications envoyées < 1min

Ce système offre une gestion complète et intelligente des annulations, protégeant à la fois les utilisateurs et la plateforme contre les abus tout en maintenant une expérience utilisateur optimale.