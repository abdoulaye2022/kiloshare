'use client';

import React, { useState, useEffect } from 'react';
import { 
  Plus, 
  Search, 
  Filter, 
  Edit3, 
  Eye, 
  Trash2, 
  Archive, 
  Heart, 
  MapPin, 
  Calendar, 
  Package2 as Weight, 
  DollarSign,
  Package,
  Users,
  Clock,
  AlertCircle,
  CheckCircle,
  XCircle,
  Pause as PauseCircle,
  RefreshCw
} from 'lucide-react';

interface Trip {
  id: number;
  uuid: string;
  departure_city: string;
  departure_country: string;
  arrival_city: string;
  arrival_country: string;
  departure_date: string;
  available_weight_kg: number;
  price_per_kg: number;
  currency: string;
  status: string;
  description?: string;
  created_at: string;
  updated_at: string;
  view_count: number;
  booking_count: number;
  favorite_count: number;
  remaining_weight?: number;
  is_featured: boolean;
  is_urgent: boolean;
}

type StatusFilter = 'all' | 'draft' | 'pending_review' | 'active' | 'paused' | 'completed' | 'cancelled';
type ViewMode = 'grid' | 'list';

export default function MyTripsPage() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [favoriteTrips, setFavoriteTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'my-trips' | 'favorites'>('my-trips');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [viewMode, setViewMode] = useState<ViewMode>('grid');
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    if (activeTab === 'my-trips') {
      fetchMyTrips();
    } else {
      fetchFavoriteTrips();
    }
  }, [activeTab]);

  const fetchMyTrips = async () => {
    setLoading(true);
    try {
      // Simuler l'appel API - remplacer par la vraie API
      const token = localStorage.getItem('auth_token') || 'demo_token';
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080'}/api/v1/user/trips`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        }
      });

      if (response.ok) {
        const data = await response.json();
        setTrips(data.trips || []);
      } else {
        console.error('Failed to fetch my trips');
        // Données de démonstration
        setTrips([
          {
            id: 1,
            uuid: 'trip-1',
            departure_city: 'Montreal',
            departure_country: 'Canada',
            arrival_city: 'Toronto',
            arrival_country: 'Canada',
            departure_date: '2025-09-15 10:00:00',
            available_weight_kg: 50,
            price_per_kg: 3.50,
            currency: 'CAD',
            status: 'active',
            description: 'Vol direct, possibilité colis fragiles',
            created_at: '2025-09-01 10:00:00',
            updated_at: '2025-09-01 10:00:00',
            view_count: 24,
            booking_count: 3,
            favorite_count: 8,
            remaining_weight: 35.5,
            is_featured: true,
            is_urgent: false
          },
          {
            id: 2,
            uuid: 'trip-2',
            departure_city: 'Paris',
            departure_country: 'France',
            arrival_city: 'Montreal',
            arrival_country: 'Canada',
            departure_date: '2025-09-25 11:00:00',
            available_weight_kg: 20,
            price_per_kg: 4.00,
            currency: 'CAD',
            status: 'draft',
            description: 'Brouillon - Vol Air France',
            created_at: '2025-08-30 15:30:00',
            updated_at: '2025-08-30 15:30:00',
            view_count: 0,
            booking_count: 0,
            favorite_count: 0,
            remaining_weight: 20,
            is_featured: false,
            is_urgent: false
          },
          {
            id: 3,
            uuid: 'trip-3',
            departure_city: 'Toronto',
            departure_country: 'Canada',
            arrival_city: 'Vancouver',
            arrival_country: 'Canada',
            departure_date: '2025-10-05 14:30:00',
            available_weight_kg: 30,
            price_per_kg: 2.75,
            currency: 'CAD',
            status: 'pending_review',
            description: 'En attente de modération',
            created_at: '2025-09-01 09:15:00',
            updated_at: '2025-09-01 09:15:00',
            view_count: 5,
            booking_count: 0,
            favorite_count: 2,
            remaining_weight: 30,
            is_featured: false,
            is_urgent: true
          }
        ]);
      }
    } catch (error) {
      console.error('Error fetching trips:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchFavoriteTrips = async () => {
    setLoading(true);
    try {
      // Simuler l'appel API pour les favoris
      const token = localStorage.getItem('auth_token') || 'demo_token';
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080'}/api/v1/user/favorites`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        }
      });

      if (response.ok) {
        const data = await response.json();
        setFavoriteTrips(data.trips || []);
      } else {
        // Données de démonstration pour les favoris
        setFavoriteTrips([
          {
            id: 101,
            uuid: 'fav-trip-1',
            departure_city: 'New York',
            departure_country: 'USA',
            arrival_city: 'Montreal',
            arrival_country: 'Canada',
            departure_date: '2025-09-20 16:00:00',
            available_weight_kg: 25,
            price_per_kg: 3.25,
            currency: 'CAD',
            status: 'active',
            description: 'Vol United Airlines, transporteur fiable',
            created_at: '2025-08-28 12:00:00',
            updated_at: '2025-08-28 12:00:00',
            view_count: 45,
            booking_count: 7,
            favorite_count: 15,
            remaining_weight: 12.5,
            is_featured: false,
            is_urgent: false
          }
        ]);
      }
    } catch (error) {
      console.error('Error fetching favorite trips:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredTrips = (activeTab === 'my-trips' ? trips : favoriteTrips).filter(trip => {
    const matchesStatus = statusFilter === 'all' || trip.status === statusFilter;
    const matchesSearch = searchTerm === '' || 
      trip.departure_city.toLowerCase().includes(searchTerm.toLowerCase()) ||
      trip.arrival_city.toLowerCase().includes(searchTerm.toLowerCase()) ||
      trip.description?.toLowerCase().includes(searchTerm.toLowerCase());
    
    return matchesStatus && matchesSearch;
  });

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'active': return <CheckCircle className="h-4 w-4 text-green-500" />;
      case 'draft': return <Edit3 className="h-4 w-4 text-gray-500" />;
      case 'pending_review': return <Clock className="h-4 w-4 text-yellow-500" />;
      case 'paused': return <PauseCircle className="h-4 w-4 text-blue-500" />;
      case 'completed': return <CheckCircle className="h-4 w-4 text-green-600" />;
      case 'cancelled': return <XCircle className="h-4 w-4 text-red-500" />;
      default: return <AlertCircle className="h-4 w-4 text-gray-500" />;
    }
  };

  const getStatusLabel = (status: string) => {
    const labels: Record<string, string> = {
      'active': 'Publié',
      'draft': 'Brouillon',
      'pending_review': 'En modération',
      'paused': 'En pause',
      'completed': 'Terminé',
      'cancelled': 'Annulé'
    };
    return labels[status] || status;
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'bg-green-50 text-green-700 border-green-200';
      case 'draft': return 'bg-gray-50 text-gray-700 border-gray-200';
      case 'pending_review': return 'bg-yellow-50 text-yellow-700 border-yellow-200';
      case 'paused': return 'bg-blue-50 text-blue-700 border-blue-200';
      case 'completed': return 'bg-green-50 text-green-700 border-green-200';
      case 'cancelled': return 'bg-red-50 text-red-700 border-red-200';
      default: return 'bg-gray-50 text-gray-700 border-gray-200';
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('fr-CA', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatPrice = (amount: number, currency: string = 'CAD') => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: currency
    }).format(amount);
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-2 border-blue-600 border-t-transparent"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header Mobile-First */}
      <div className="bg-white shadow-sm sticky top-0 z-10">
        <div className="px-4 py-4">
          <div className="flex items-center justify-between mb-4">
            <h1 className="text-2xl font-bold text-gray-900">
              {activeTab === 'my-trips' ? 'Mes voyages' : 'Mes favoris'}
            </h1>
            <button className="bg-blue-600 text-white p-2 rounded-lg">
              <Plus className="h-5 w-5" />
            </button>
          </div>

          {/* Tabs */}
          <div className="flex space-x-1 bg-gray-100 rounded-lg p-1 mb-4">
            <button
              onClick={() => setActiveTab('my-trips')}
              className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors ${
                activeTab === 'my-trips'
                  ? 'bg-white text-blue-600 shadow-sm'
                  : 'text-gray-600'
              }`}
            >
              Mes annonces
              {trips.filter(t => t.status === 'draft').length > 0 && (
                <span className="ml-2 bg-orange-100 text-orange-800 text-xs px-2 py-1 rounded-full">
                  {trips.filter(t => t.status === 'draft').length}
                </span>
              )}
            </button>
            <button
              onClick={() => setActiveTab('favorites')}
              className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors ${
                activeTab === 'favorites'
                  ? 'bg-white text-blue-600 shadow-sm'
                  : 'text-gray-600'
              }`}
            >
              <Heart className="h-4 w-4 inline mr-1" />
              Favoris ({favoriteTrips.length})
            </button>
          </div>

          {/* Search & Filters */}
          <div className="flex space-x-2">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-3 h-4 w-4 text-gray-400" />
              <input
                type="text"
                placeholder="Rechercher..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-9 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
              />
            </div>
            <button
              onClick={() => setShowFilters(!showFilters)}
              className="p-2 border border-gray-300 rounded-lg text-gray-600"
            >
              <Filter className="h-4 w-4" />
            </button>
          </div>

          {/* Status Filters (Collapsible) */}
          {showFilters && (
            <div className="mt-4 flex flex-wrap gap-2">
              {['all', 'active', 'draft', 'pending_review', 'paused'].map((status) => (
                <button
                  key={status}
                  onClick={() => setStatusFilter(status as StatusFilter)}
                  className={`px-3 py-1 text-xs rounded-full border transition-colors ${
                    statusFilter === status
                      ? 'bg-blue-600 text-white border-blue-600'
                      : 'bg-white text-gray-600 border-gray-300'
                  }`}
                >
                  {status === 'all' ? 'Tous' : getStatusLabel(status)}
                </button>
              ))}
            </div>
          )}

          {/* Results count */}
          <div className="mt-3 text-sm text-gray-500">
            {filteredTrips.length} résultat{filteredTrips.length !== 1 ? 's' : ''}
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="px-4 py-6">
        {filteredTrips.length === 0 ? (
          <div className="text-center py-12">
            <Package className="mx-auto h-12 w-12 text-gray-400 mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              {activeTab === 'my-trips' 
                ? statusFilter === 'draft' 
                  ? 'Aucun brouillon'
                  : 'Aucun voyage trouvé'
                : 'Aucun favori'}
            </h3>
            <p className="text-gray-500 mb-6">
              {activeTab === 'my-trips' 
                ? statusFilter === 'draft'
                  ? 'Vous n\'avez aucun voyage en brouillon'
                  : 'Créez votre première annonce de voyage'
                : 'Ajoutez des voyages à vos favoris depuis la recherche'}
            </p>
            {activeTab === 'my-trips' && (
              <button className="bg-blue-600 text-white px-6 py-3 rounded-lg font-medium">
                Créer une annonce
              </button>
            )}
          </div>
        ) : (
          <div className="space-y-4">
            {filteredTrips.map((trip) => (
              <div key={trip.id} className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
                {/* Trip Header */}
                <div className="p-4">
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex-1">
                      <div className="flex items-center mb-2">
                        <div className="flex items-center text-base font-semibold text-gray-900">
                          <MapPin className="h-4 w-4 text-green-500 mr-1" />
                          {trip.departure_city}
                          <span className="mx-2 text-gray-400">→</span>
                          <MapPin className="h-4 w-4 text-red-500 mr-1" />
                          {trip.arrival_city}
                        </div>
                      </div>
                      
                      <div className="flex items-center space-x-4 text-sm text-gray-600 mb-2">
                        <div className="flex items-center">
                          <Calendar className="h-4 w-4 mr-1" />
                          {formatDate(trip.departure_date)}
                        </div>
                      </div>

                      <div className="flex items-center space-x-4 text-sm text-gray-600">
                        <div className="flex items-center">
                          <Weight className="h-4 w-4 mr-1" />
                          {trip.remaining_weight}/{trip.available_weight_kg} kg
                        </div>
                        <div className="flex items-center">
                          <DollarSign className="h-4 w-4 mr-1" />
                          {formatPrice(trip.price_per_kg)}/kg
                        </div>
                      </div>
                    </div>

                    <div className="text-right">
                      <div className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium border ${getStatusColor(trip.status)}`}>
                        {getStatusIcon(trip.status)}
                        <span className="ml-1">{getStatusLabel(trip.status)}</span>
                      </div>
                      {trip.is_featured && (
                        <div className="mt-1">
                          <span className="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded-full">
                            ⭐ En vedette
                          </span>
                        </div>
                      )}
                      {trip.is_urgent && (
                        <div className="mt-1">
                          <span className="bg-red-100 text-red-800 text-xs px-2 py-1 rounded-full">
                            🔥 Urgent
                          </span>
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Description */}
                  {trip.description && (
                    <p className="text-sm text-gray-700 mb-3" style={{
                      display: '-webkit-box',
                      WebkitLineClamp: 2,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden'
                    }}>
                      {trip.description}
                    </p>
                  )}

                  {/* Stats */}
                  <div className="flex items-center space-x-4 text-xs text-gray-500 mb-4">
                    <div className="flex items-center">
                      <Eye className="h-3 w-3 mr-1" />
                      {trip.view_count} vues
                    </div>
                    <div className="flex items-center">
                      <Users className="h-3 w-3 mr-1" />
                      {trip.booking_count} propositions
                    </div>
                    <div className="flex items-center">
                      <Heart className="h-3 w-3 mr-1" />
                      {trip.favorite_count} favoris
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex space-x-2">
                    {trip.status === 'draft' ? (
                      <>
                        <button className="flex-1 bg-blue-600 text-white py-2 px-3 rounded-lg text-sm font-medium flex items-center justify-center">
                          <Edit3 className="h-4 w-4 mr-1" />
                          Continuer
                        </button>
                        <button className="p-2 text-gray-400 hover:text-red-500">
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </>
                    ) : (
                      <>
                        <button className="flex-1 bg-gray-100 text-gray-700 py-2 px-3 rounded-lg text-sm font-medium flex items-center justify-center">
                          <Eye className="h-4 w-4 mr-1" />
                          Voir
                        </button>
                        <button className="p-2 text-gray-400 hover:text-blue-500">
                          <Edit3 className="h-4 w-4" />
                        </button>
                        <button className="p-2 text-gray-400 hover:text-yellow-500">
                          <Archive className="h-4 w-4" />
                        </button>
                        <button className="p-2 text-gray-400 hover:text-red-500">
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Floating Action Button */}
      <button className="fixed bottom-6 right-6 bg-blue-600 text-white w-14 h-14 rounded-full shadow-lg flex items-center justify-center z-20">
        <Plus className="h-6 w-6" />
      </button>
    </div>
  );
}