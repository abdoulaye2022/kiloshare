'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface Trip {
  id: string;
  uuid: string;
  transport_type: string;
  departure_city: string;
  departure_country: string;
  arrival_city: string;
  arrival_country: string;
  departure_date: string;
  available_weight_kg: number;
  price_per_kg: number;
  currency: string;
  status: string;
  has_images: boolean;
  image_count: number;
  images: Array<{
    id: number;
    image_path: string;
    image_name: string;
    file_size: number;
    upload_order: number;
    image_url: string;
    formatted_file_size: string;
  }>;
  user: {
    first_name: string;
    last_name: string;
    email: string;
    trust_score: number;
    total_trips: number;
  };
  created_at: string;
}

interface TripModerationPanelProps {
  adminInfo: any;
  onLogout: () => void;
}

export default function TripModerationPanel({ adminInfo, onLogout }: TripModerationPanelProps) {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'urgent' | 'high' | 'normal'>('all');
  const [sortBy, setSortBy] = useState<'date' | 'price' | 'trust_score'>('date');

  useEffect(() => {
    fetchPendingTrips();
    // Rafraîchir toutes les 2 minutes
    const interval = setInterval(fetchPendingTrips, 2 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  const fetchPendingTrips = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/trips/pending');

      if (response.ok) {
        const data = await response.json();
        setTrips(data.trips || []);
      } else {
        console.error('Failed to fetch pending trips');
      }
    } catch (error) {
      console.error('Error fetching trips:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleApproveTrip = async (tripId: string) => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/trips/approve', {
        method: 'POST',
        body: JSON.stringify({ id: tripId }),
      });

      if (response.ok) {
        fetchPendingTrips();
      }
    } catch (error) {
      console.error('Error approving trip:', error);
    }
  };

  const handleRejectTrip = async (tripId: string) => {
    const reason = prompt('Raison du rejet (optionnel):');
    
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/trips/reject', {
        method: 'POST',
        body: JSON.stringify({ id: tripId, reason }),
      });

      if (response.ok) {
        fetchPendingTrips();
      }
    } catch (error) {
      console.error('Error rejecting trip:', error);
    }
  };

  const getTransportIcon = (transportType: string) => {
    const iconClass = "w-4 h-4";
    switch (transportType.toLowerCase()) {
      case 'plane': 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14M5 12l6-6m-6 6l6 6" />
          </svg>
        );
      case 'car': 
      default:
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 17a2 2 0 11-4 0 2 2 0 014 0zM19 17a2 2 0 11-4 0 2 2 0 014 0zM13 6h3l4 4v7H4V10l4-4h5z" />
          </svg>
        );
      case 'bus': 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 17a2 2 0 11-4 0 2 2 0 014 0zM19 17a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
        );
      case 'train': 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
    }
  };

  const getTrustLevelColor = (trustScore: number) => {
    if (trustScore < 30) return 'text-red-600 bg-red-100';
    if (trustScore <= 70) return 'text-yellow-600 bg-yellow-100';
    return 'text-green-600 bg-green-100';
  };

  const getTrustLevelLabel = (trustScore: number) => {
    if (trustScore < 30) return 'Nouveau';
    if (trustScore <= 70) return 'Vérifié';
    return 'Établi';
  };

  const getPriorityLevel = (trip: Trip) => {
    const now = new Date();
    const departureDate = new Date(trip.departure_date);
    const hoursUntilDeparture = (departureDate.getTime() - now.getTime()) / (1000 * 60 * 60);
    
    // Urgent si départ dans moins de 24h
    if (hoursUntilDeparture < 24) return 'urgent';
    
    // Haute priorité si gros montant ou nouveau utilisateur
    if (trip.price_per_kg * trip.available_weight_kg > 500 || trip.user.trust_score < 30) {
      return 'high';
    }
    
    return 'normal';
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'urgent': return 'bg-red-100 text-red-800 border-red-200';
      case 'high': return 'bg-orange-100 text-orange-800 border-orange-200';
      default: return 'bg-blue-100 text-blue-800 border-blue-200';
    }
  };

  const filteredAndSortedTrips = trips
    .filter(trip => {
      if (filter === 'all') return true;
      return getPriorityLevel(trip) === filter;
    })
    .sort((a, b) => {
      switch (sortBy) {
        case 'date':
          return new Date(a.departure_date).getTime() - new Date(b.departure_date).getTime();
        case 'price':
          return (b.price_per_kg * b.available_weight_kg) - (a.price_per_kg * a.available_weight_kg);
        case 'trust_score':
          return a.user.trust_score - b.user.trust_score;
        default:
          return 0;
      }
    });

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">
                Modération des Annonces
              </h1>
              <p className="text-sm text-gray-500">
                Gérer les voyages en attente d'approbation • {filteredAndSortedTrips.length} annonce(s)
              </p>
            </div>
            <button
              onClick={onLogout}
              className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium flex items-center gap-2"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
              Déconnexion
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          
          {/* Filtres et Actions */}
          <div className="mb-6 flex flex-wrap gap-4 items-center justify-between">
            <div className="flex flex-wrap gap-4 items-center">
              <div>
                <label className="text-sm font-medium text-gray-700 mr-2">Priorité :</label>
                <select
                  value={filter}
                  onChange={(e) => setFilter(e.target.value as any)}
                  className="border border-gray-300 rounded-md px-3 py-1 text-sm bg-white text-gray-900 selection:bg-blue-100 selection:text-blue-900"
                >
                  <option value="all">Toutes ({trips.length})</option>
                  <option value="urgent">Urgentes ({trips.filter(t => getPriorityLevel(t) === 'urgent').length})</option>
                  <option value="high">Haute priorité ({trips.filter(t => getPriorityLevel(t) === 'high').length})</option>
                  <option value="normal">Normale ({trips.filter(t => getPriorityLevel(t) === 'normal').length})</option>
                </select>
              </div>
              
              <div>
                <label className="text-sm font-medium text-gray-700 mr-2">Trier par :</label>
                <select
                  value={sortBy}
                  onChange={(e) => setSortBy(e.target.value as any)}
                  className="border border-gray-300 rounded-md px-3 py-1 text-sm bg-white text-gray-900 selection:bg-blue-100 selection:text-blue-900"
                >
                  <option value="date">Date de départ</option>
                  <option value="price">Montant total</option>
                  <option value="trust_score">Score de confiance</option>
                </select>
              </div>
            </div>

            <div className="flex gap-2">
              <button
                onClick={fetchPendingTrips}
                className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium flex items-center gap-2"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                Actualiser
              </button>
            </div>
          </div>

          {filteredAndSortedTrips.length === 0 ? (
            <div className="text-center py-12">
              <div className="mx-auto w-16 h-16 mb-4 flex items-center justify-center rounded-full bg-green-100">
                <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <p className="text-gray-500 text-lg mb-2">
                Aucun voyage en attente d'approbation
              </p>
              <p className="text-gray-400 text-sm">
                {filter !== 'all' ? `Aucune annonce avec priorité "${filter}"` : 'Toutes les annonces ont été traitées'}
              </p>
            </div>
          ) : (
            <div className="grid gap-6">
              {filteredAndSortedTrips.map((trip) => {
                const priority = getPriorityLevel(trip);
                const totalValue = trip.price_per_kg * trip.available_weight_kg;
                
                return (
                  <div key={trip.id} className="bg-white shadow rounded-lg p-6 border-l-4 border-l-blue-500">
                    {/* Priority Badge */}
                    <div className="flex items-start justify-between mb-4">
                      <div className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border ${getPriorityColor(priority)}`}>
                        {priority === 'urgent' && (
                          <>
                            <svg className="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 18.5c-.77.833.192 2.5 1.732 2.5z" />
                            </svg>
                            URGENT
                          </>
                        )}
                        {priority === 'high' && (
                          <>
                            <svg className="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                            </svg>
                            PRIORITÉ HAUTE
                          </>
                        )}
                        {priority === 'normal' && (
                          <>
                            <svg className="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                            </svg>
                            NORMALE
                          </>
                        )}
                      </div>
                      <div className="text-right">
                        <div className="text-lg font-bold text-green-600">
                          {totalValue.toFixed(2)} {trip.currency}
                        </div>
                        <div className="text-xs text-gray-500">Valeur totale</div>
                      </div>
                    </div>

                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center mb-4">
                          <span className="text-2xl mr-3">
                            {getTransportIcon(trip.transport_type)}
                          </span>
                          <div>
                            <h3 className="text-lg font-semibold text-gray-900">
                              {trip.departure_city} → {trip.arrival_city}
                            </h3>
                            <p className="text-sm text-gray-500">
                              {new Date(trip.departure_date).toLocaleDateString('fr-FR', {
                                day: 'numeric',
                                month: 'long',
                                year: 'numeric',
                                hour: '2-digit',
                                minute: '2-digit'
                              })}
                            </p>
                          </div>
                        </div>

                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
                          <div>
                            <p className="text-sm text-gray-500">Poids disponible</p>
                            <p className="font-medium">{trip.available_weight_kg} kg</p>
                          </div>
                          <div>
                            <p className="text-sm text-gray-500">Prix par kg</p>
                            <p className="font-medium">{trip.price_per_kg} {trip.currency}</p>
                          </div>
                          <div>
                            <p className="text-sm text-gray-500">Transport</p>
                            <p className="font-medium capitalize">{trip.transport_type}</p>
                          </div>
                          <div>
                            <p className="text-sm text-gray-500">Statut</p>
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                              {trip.status === 'pending_approval' ? 'En attente' : trip.status}
                            </span>
                          </div>
                        </div>

                        {/* Images section */}
                        {trip.has_images && trip.images.length > 0 && (
                          <div className="border-t pt-4 mb-4">
                            <h4 className="font-medium text-gray-900 mb-3 flex items-center gap-2">
                              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                              </svg>
                              Photos de l'annonce ({trip.image_count})
                            </h4>
                            <div className="flex flex-wrap gap-3">
                              {trip.images.map((image) => (
                                <div key={image.id} className="relative">
                                  <img
                                    src={image.image_url}
                                    alt={image.image_name}
                                    className="w-20 h-20 object-cover rounded-lg border border-gray-200 hover:shadow-md transition-shadow cursor-pointer"
                                    onClick={() => window.open(image.image_url, '_blank')}
                                  />
                                  <div className="absolute bottom-0 left-0 right-0 bg-black bg-opacity-70 text-white text-xs px-1 py-0.5 rounded-b-lg">
                                    {image.formatted_file_size}
                                  </div>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}

                        <div className="border-t pt-4">
                          <h4 className="font-medium text-gray-900 mb-2 flex items-center gap-2">
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                            </svg>
                            Informations utilisateur
                          </h4>
                          <div className="flex items-center justify-between">
                            <div>
                              <p className="text-sm">
                                <span className="font-medium">
                                  {trip.user.first_name} {trip.user.last_name}
                                </span>
                                <span className="text-gray-500 ml-2">
                                  ({trip.user.email})
                                </span>
                              </p>
                              <p className="text-sm text-gray-500">
                                {trip.user.total_trips} voyage(s) au total
                              </p>
                            </div>
                            <div className="flex items-center">
                              <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getTrustLevelColor(trip.user.trust_score)}`}>
                                Trust Score: {trip.user.trust_score} ({getTrustLevelLabel(trip.user.trust_score)})
                              </span>
                            </div>
                          </div>
                        </div>
                      </div>

                      <div className="ml-4 flex flex-col space-y-2">
                        <button
                          onClick={() => handleApproveTrip(trip.id)}
                          className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium flex items-center gap-2"
                        >
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                          </svg>
                          Approuver
                        </button>
                        <button
                          onClick={() => handleRejectTrip(trip.id)}
                          className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium flex items-center gap-2"
                        >
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                          </svg>
                          Rejeter
                        </button>
                        <button
                          onClick={() => alert('Fonctionnalité en cours de développement')}
                          className="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-md text-sm font-medium flex items-center gap-2"
                        >
                          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                          </svg>
                          Notes
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}