'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface Trip {
  id: number;
  uuid: string;
  title?: string;
  description?: string;
  transport_type: string | null;
  departure_city: string;
  departure_country: string;
  arrival_city: string;
  arrival_country: string;
  departure_date: string;
  arrival_date?: string;
  max_weight?: number;
  available_weight_kg?: string;
  price_per_kg: string;
  total_reward?: number;
  currency: string;
  status: string;
  is_domestic?: boolean;
  restrictions?: any;
  special_instructions?: string;
  published_at?: string;
  expires_at?: string;
  created_at: string;
  updated_at: string;
  user: {
    first_name: string;
    last_name: string;
    email: string;
    trust_score?: number;
    total_trips?: number;
  };
  trips_count?: number;
  bookings_count?: number;
}

export default function TripManagement() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'draft' | 'pending_review' | 'published' | 'active' | 'rejected' | 'paused' | 'completed' | 'cancelled' | 'expired'>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedTrip, setSelectedTrip] = useState<Trip | null>(null);
  const [showTripDetails, setShowTripDetails] = useState(false);

  useEffect(() => {
    fetchTrips();
  }, [filter]);

  const fetchTrips = async () => {
    try {
      setLoading(true);
      const endpoint = filter === 'pending_review' 
        ? `/api/v1/admin/trips/pending`
        : `/api/v1/admin/trips?status=${filter}&limit=50`;
      
      const response = await adminAuth.apiRequest(endpoint);
      
      if (response.ok) {
        const data = await response.json();
        console.log('Trips API response:', data);
        setTrips(data.data?.trips || data.trips || []);
      } else {
        console.error('Failed to fetch trips');
      }
    } catch (error) {
      console.error('Error fetching trips:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleTripAction = async (tripId: number, action: 'approve' | 'reject' | 'publish' | 'pause' | 'resume' | 'cancel') => {
    try {
      let endpoint = '';
      let body: any = { id: tripId };

      switch (action) {
        case 'approve':
          endpoint = '/api/v1/admin/trips/approve';
          break;
        case 'reject':
          const reason = prompt('Raison du rejet (optionnel):');
          endpoint = '/api/v1/admin/trips/reject';
          body.reason = reason;
          break;
        default:
          console.error('Action not supported:', action);
          return;
      }

      const response = await adminAuth.apiRequest(endpoint, {
        method: 'POST',
        body: JSON.stringify(body),
      });

      if (response.ok) {
        fetchTrips();
        if (selectedTrip && selectedTrip.id === tripId) {
          setSelectedTrip(null);
          setShowTripDetails(false);
        }
      }
    } catch (error) {
      console.error(`Error ${action}ing trip:`, error);
    }
  };

  const getTripStatusBadge = (status: string) => {
    const badgeClasses = {
      draft: 'bg-gray-100 text-gray-800',
      pending_review: 'bg-yellow-100 text-yellow-800',
      published: 'bg-green-100 text-green-800',
      active: 'bg-blue-100 text-blue-800',
      rejected: 'bg-red-100 text-red-800',
      paused: 'bg-orange-100 text-orange-800',
      completed: 'bg-purple-100 text-purple-800',
      cancelled: 'bg-gray-100 text-gray-800',
      expired: 'bg-red-100 text-red-800'
    };
    
    const statusLabels = {
      draft: 'Brouillon',
      pending_review: 'En attente',
      published: 'Publié',
      active: 'Actif',
      rejected: 'Rejeté',
      paused: 'En pause',
      completed: 'Terminé',
      cancelled: 'Annulé',
      expired: 'Expiré'
    };
    
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${badgeClasses[status as keyof typeof badgeClasses] || 'bg-gray-100 text-gray-800'}`}>
        {statusLabels[status as keyof typeof statusLabels] || status}
      </span>
    );
  };

  const getTransportIcon = (type: string | null) => {
    switch (type) {
      case 'plane': return '✈️';
      case 'train': return '🚂';
      case 'bus': return '🚌';
      case 'car': return '🚗';
      default: return '🎒';
    }
  };

  const formatCurrency = (amount: string | number, currency: string = 'CAD') => {
    const value = typeof amount === 'string' ? parseFloat(amount) : amount;
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: currency
    }).format(value || 0);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const filteredTrips = trips.filter(trip => {
    const matchesSearch = searchTerm === '' || 
      trip.departure_city.toLowerCase().includes(searchTerm.toLowerCase()) ||
      trip.arrival_city.toLowerCase().includes(searchTerm.toLowerCase()) ||
      `${trip.user.first_name} ${trip.user.last_name}`.toLowerCase().includes(searchTerm.toLowerCase()) ||
      trip.user.email.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesSearch;
  });

  if (loading) {
    return (
      <div className="p-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-64 mb-6"></div>
          <div className="flex space-x-4 mb-6">
            <div className="h-10 bg-gray-200 rounded w-32"></div>
            <div className="h-10 bg-gray-200 rounded w-64"></div>
          </div>
          <div className="space-y-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="h-24 bg-gray-200 rounded-lg"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 bg-gray-100 min-h-screen">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Gestion des voyages
        </h1>
        <p className="text-gray-700">
          Gérez tous les voyages de la plateforme
        </p>
      </div>

      {/* Filters and Search */}
      <div className="bg-white p-6 rounded-lg border border-gray-200 mb-6">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between space-y-4 md:space-y-0 md:space-x-4">
          {/* Status Filter */}
          <div className="flex items-center space-x-2">
            <label className="text-sm font-medium text-gray-700">Statut:</label>
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value as any)}
              className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white text-gray-900 selection:bg-blue-100 selection:text-blue-900"
            >
              <option value="all">Tous</option>
              <option value="pending_review">En attente de révision</option>
              <option value="published">Publiés</option>
              <option value="active">Actifs</option>
              <option value="draft">Brouillons</option>
              <option value="paused">En pause</option>
              <option value="completed">Terminés</option>
              <option value="cancelled">Annulés</option>
              <option value="rejected">Rejetés</option>
              <option value="expired">Expirés</option>
            </select>
          </div>

          {/* Search */}
          <div className="flex-1 max-w-md">
            <input
              type="text"
              placeholder="Rechercher par ville, utilisateur, email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Stats */}
          <div className="text-sm text-gray-700 font-medium">
            {filteredTrips.length} voyage{filteredTrips.length !== 1 ? 's' : ''}
          </div>
        </div>
      </div>

      {/* Trips List */}
      <div className="bg-white rounded-lg border border-gray-200 overflow-hidden">
        {filteredTrips.length === 0 ? (
          <div className="p-12 text-center">
            <div className="text-gray-400 text-6xl mb-4">✈️</div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">Aucun voyage trouvé</h3>
            <p className="text-gray-700">
              {searchTerm ? 'Essayez de modifier vos critères de recherche' : 'Aucun voyage ne correspond aux filtres sélectionnés'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                    Voyage
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                    Route
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                    Prix
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                    Statut
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                    Utilisateur
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                    Date création
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredTrips.map((trip) => (
                  <tr key={trip.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <div className="flex items-center">
                        <div className="text-2xl mr-3">
                          {getTransportIcon(trip.transport_type)}
                        </div>
                        <div>
                          <div className="text-sm font-medium text-gray-900">
                            {trip.title || `${trip.departure_city} → ${trip.arrival_city}`}
                          </div>
                          <div className="text-sm text-gray-500">
                            Départ: {formatDate(trip.departure_date)}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900">
                        <div className="font-medium">
                          {trip.departure_city}, {trip.departure_country}
                        </div>
                        <div className="text-gray-500">
                          ↓ {trip.arrival_city}, {trip.arrival_country}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm font-medium text-gray-900">
                        {formatCurrency(trip.price_per_kg, trip.currency)}/kg
                      </div>
                      {trip.available_weight_kg && (
                        <div className="text-xs text-gray-500">
                          {trip.available_weight_kg} kg disponible
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {getTripStatusBadge(trip.status)}
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900">
                        <div className="font-medium">
                          {trip.user.first_name} {trip.user.last_name}
                        </div>
                        <div className="text-gray-500">
                          {trip.user.email}
                        </div>
                        {trip.user.total_trips && (
                          <div className="text-xs text-blue-600">
                            {trip.user.total_trips} voyage{trip.user.total_trips !== 1 ? 's' : ''}
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {formatDate(trip.created_at)}
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center space-x-2">
                        <button
                          onClick={() => {
                            setSelectedTrip(trip);
                            setShowTripDetails(true);
                          }}
                          className="text-blue-600 hover:text-blue-900 text-sm font-medium"
                        >
                          Voir
                        </button>
                        
                        {trip.status === 'pending_review' && (
                          <>
                            <button
                              onClick={() => handleTripAction(trip.id, 'approve')}
                              className="text-green-600 hover:text-green-900 text-sm font-medium"
                            >
                              Approuver
                            </button>
                            <button
                              onClick={() => handleTripAction(trip.id, 'reject')}
                              className="text-red-600 hover:text-red-900 text-sm font-medium"
                            >
                              Rejeter
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Trip Details Modal */}
      {showTripDetails && selectedTrip && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-11/12 md:w-3/4 lg:w-1/2 shadow-lg rounded-lg bg-white">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-900">
                Détails du voyage
              </h3>
              <button
                onClick={() => setShowTripDetails(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12"></path>
                </svg>
              </button>
            </div>

            <div className="space-y-4">
              {/* Basic Info */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-800 mb-1">
                    Route
                  </label>
                  <p className="text-sm text-gray-900">
                    {getTransportIcon(selectedTrip.transport_type)} {selectedTrip.departure_city}, {selectedTrip.departure_country} → {selectedTrip.arrival_city}, {selectedTrip.arrival_country}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-800 mb-1">
                    Statut
                  </label>
                  {getTripStatusBadge(selectedTrip.status)}
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-800 mb-1">
                    Prix par kg
                  </label>
                  <p className="text-sm text-gray-900">
                    {formatCurrency(selectedTrip.price_per_kg, selectedTrip.currency)}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-800 mb-1">
                    Poids disponible
                  </label>
                  <p className="text-sm text-gray-900">
                    {selectedTrip.available_weight_kg || 'Non spécifié'} kg
                  </p>
                </div>
              </div>

              {/* Dates */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-800 mb-1">
                    Date de départ
                  </label>
                  <p className="text-sm text-gray-900">
                    {formatDate(selectedTrip.departure_date)}
                  </p>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-800 mb-1">
                    Date de création
                  </label>
                  <p className="text-sm text-gray-900">
                    {formatDate(selectedTrip.created_at)}
                  </p>
                </div>
              </div>

              {/* Description */}
              {selectedTrip.description && (
                <div>
                  <label className="block text-sm font-medium text-gray-800 mb-1">
                    Description
                  </label>
                  <p className="text-sm text-gray-900 bg-gray-50 p-3 rounded-md">
                    {selectedTrip.description}
                  </p>
                </div>
              )}

              {/* User Info */}
              <div className="border-t pt-4">
                <h4 className="text-md font-medium text-gray-900 mb-2">
                  Informations utilisateur
                </h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-800 mb-1">
                      Nom complet
                    </label>
                    <p className="text-sm text-gray-900">
                      {selectedTrip.user.first_name} {selectedTrip.user.last_name}
                    </p>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-800 mb-1">
                      Email
                    </label>
                    <p className="text-sm text-gray-900">
                      {selectedTrip.user.email}
                    </p>
                  </div>
                  {selectedTrip.user.total_trips && (
                    <div>
                      <label className="block text-sm font-medium text-gray-800 mb-1">
                        Voyages publiés
                      </label>
                      <p className="text-sm text-gray-900">
                        {selectedTrip.user.total_trips}
                      </p>
                    </div>
                  )}
                </div>
              </div>

              {/* Actions */}
              {selectedTrip.status === 'pending_review' && (
                <div className="border-t pt-4">
                  <div className="flex space-x-3">
                    <button
                      onClick={() => handleTripAction(selectedTrip.id, 'approve')}
                      className="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 transition-colors"
                    >
                      Approuver le voyage
                    </button>
                    <button
                      onClick={() => handleTripAction(selectedTrip.id, 'reject')}
                      className="flex-1 bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 transition-colors"
                    >
                      Rejeter le voyage
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}