'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import adminAuth from '../../../lib/admin-auth';

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

export default function AdminDashboard() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [admin, setAdmin] = useState<any>(null);
  const router = useRouter();

  useEffect(() => {
    if (!adminAuth.isAuthenticated()) {
      router.push('/admin/login');
      return;
    }

    const adminData = adminAuth.getAdminInfo();
    if (!adminData || adminData.role !== 'admin') {
      adminAuth.logout();
      return;
    }
    
    setAdmin(adminData);
    fetchPendingTrips();
  }, []);

  const fetchPendingTrips = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/admin/trips/pending');

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
      const response = await adminAuth.apiRequest('/api/admin/trips/approve', {
        method: 'POST',
        body: JSON.stringify({ id: tripId }),
      });

      if (response.ok) {
        // Refresh the list
        fetchPendingTrips();
      }
    } catch (error) {
      console.error('Error approving trip:', error);
    }
  };

  const handleRejectTrip = async (tripId: string) => {
    const reason = prompt('Raison du rejet (optionnel):');
    
    try {
      const response = await adminAuth.apiRequest('/api/admin/trips/reject', {
        method: 'POST',
        body: JSON.stringify({ id: tripId, reason }),
      });

      if (response.ok) {
        // Refresh the list
        fetchPendingTrips();
      }
    } catch (error) {
      console.error('Error rejecting trip:', error);
    }
  };

  const handleLogout = () => {
    adminAuth.logout();
  };

  const getTransportIcon = (transportType: string) => {
    switch (transportType.toLowerCase()) {
      case 'plane':
        return '✈️';
      case 'car':
        return '🚗';
      case 'bus':
        return '🚌';
      case 'train':
        return '🚆';
      default:
        return '🚗';
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
                KiloShare Admin
              </h1>
              <p className="text-sm text-gray-500">
                Bienvenue, {admin?.name}
              </p>
            </div>
            <button
              onClick={handleLogout}
              className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
            >
              Déconnexion
            </button>
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="mb-6">
            <h2 className="text-2xl font-bold text-gray-900">
              Voyages en attente d'approbation ({trips.length})
            </h2>
            <p className="text-gray-600">
              Gérez les voyages qui nécessitent une approbation manuelle
            </p>
          </div>

          {trips.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500 text-lg">
                Aucun voyage en attente d'approbation
              </p>
            </div>
          ) : (
            <div className="grid gap-6">
              {trips.map((trip) => (
                <div key={trip.id} className="bg-white shadow rounded-lg p-6">
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
                          <h4 className="font-medium text-gray-900 mb-3">Photos de l'annonce ({trip.image_count})</h4>
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
                        <h4 className="font-medium text-gray-900 mb-2">Informations utilisateur</h4>
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
                        className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                      >
                        ✓ Approuver
                      </button>
                      <button
                        onClick={() => handleRejectTrip(trip.id)}
                        className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                      >
                        ✗ Rejeter
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}