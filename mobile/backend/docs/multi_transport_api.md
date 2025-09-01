# API Multi-Transport KiloShare

## Vue d'ensemble
Cette API permet de gérer les fonctionnalités multi-transport de KiloShare, supportant les types de transport suivants :
- **Avion** (flight) - Limite: 23kg
- **Voiture** (car) - Limite: 100kg  
- **Train** (train) - Limite: 40kg
- **Bus** (bus) - Limite: 30kg
- **Bateau** (boat) - Limite: 50kg

## Endpoints

### 1. Récupérer les limites de transport

#### GET `/api/trips/transport-limits`
Récupère les limites de tous les types de transport.

**Réponse:**
```json
{
  "success": true,
  "data": {
    "limits": [
      {
        "type": "flight",
        "name": "Avion",
        "max_weight_kg": 23.0,
        "base_rate_per_kg": 3.00,
        "commission_rate": 0.15,
        "features": {
          "flexible_departure": false,
          "intermediate_stops": false,
          "vehicle_info_required": false,
          "flight_info_required": true,
          "ticket_validation_supported": true
        }
      }
    ]
  }
}
```

#### GET `/api/trips/transport-limits/{type}`
Récupère les limites d'un type de transport spécifique.

**Paramètres:**
- `type` : Type de transport (flight, car, train, bus, boat)

### 2. Calcul de prix suggéré multi-transport

#### POST `/api/trips/price-suggestion-multi`
Calcule un prix suggéré en fonction du type de transport et de la distance.

**Body:**
```json
{
  "transport_type": "car",
  "departure_city": "Halifax",
  "arrival_city": "Moncton",
  "weight_kg": 15.5,
  "currency": "CAD"
}
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "price_suggestion": {
      "suggested_price_per_kg": 1.20,
      "total_price": 18.60,
      "commission": 2.23,
      "net_earnings": 16.37,
      "currency": "CAD",
      "transport_type": "car",
      "distance_km": 270,
      "weight_kg": 15.5,
      "base_rate": 1.50,
      "commission_rate": 0.12,
      "explanation": "Tarif de base Voiture: 1.50 CAD/kg • Réduction voiture longue distance (-20%)"
    }
  }
}
```

### 3. Recommandations de transport

#### POST `/api/trips/transport-recommendations`
Génère des recommandations de transport optimales selon le trajet et le poids.

**Body:**
```json
{
  "departure_city": "Halifax",
  "arrival_city": "Toronto",
  "weight_kg": 20.0
}
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "recommendations": [
      {
        "transport_type": "car",
        "name": "Voiture",
        "price_per_kg": 1.95,
        "total_price": 39.00,
        "net_earnings": 34.32,
        "suitability_score": 85,
        "pros": ["Flexible", "Grande capacité", "Porte à porte"],
        "cons": ["Dépendant du trafic", "Émissions CO2"]
      }
    ]
  }
}
```

### 4. Validation de véhicule

#### POST `/api/trips/{id}/validate-vehicle`
Valide les informations de véhicule pour un voyage en voiture.

**Paramètres:**
- `id` : ID du voyage

**Body:**
```json
{
  "make": "Toyota",
  "model": "Corolla",
  "license_plate": "ABC-123",
  "year": "2020",
  "color": "Noir"
}
```

**Réponse:**
```json
{
  "success": true,
  "message": "Véhicule validé avec succès",
  "data": {
    "trip": {
      "id": "123",
      "vehicle_make": "Toyota",
      "vehicle_model": "Corolla",
      "license_plate": "ABC-123",
      "vehicle_verified": true,
      "vehicle_verification_date": "2024-01-15 10:30:00"
    }
  }
}
```

### 5. Liste des voyages par transport

#### GET `/api/trips/list-by-transport/{type}?status={status}&page={page}&limit={limit}`
Récupère les voyages filtrés par type de transport.

**Paramètres:**
- `type` : Type de transport ou "all"
- `status` : Statut du voyage (optionnel)
- `page` : Numéro de page (défaut: 1)
- `limit` : Nombre de résultats par page (défaut: 20)

## Codes d'erreur

- `400` : Données invalides ou paramètres manquants
- `404` : Voyage non trouvé
- `500` : Erreur interne du serveur

## Fonctionnalités spécialisées

### Transport Voiture
- Informations véhicule requises
- Départ flexible supporté
- Arrêts intermédiaires possibles
- Limite de poids élevée (100kg)

### Transport Avion
- Informations de vol requises
- Validation de billet supportée
- Limite de poids stricte (23kg)
- Tarif premium pour courtes distances

### Transport Train/Bus/Bateau
- Horaires fixes
- Tarifs économiques
- Validation de billet supportée (train/bus)
- Capacités de poids modérées

## Intégration Frontend

Les endpoints sont utilisés par :
- `MultiTransportService` (Flutter)
- `TripTypeSelectionScreen` pour la sélection du transport
- `PriceCalculatorWidget` pour les calculs de prix
- `VehicleInfoForm` et `FlightInfoForm` pour les validations