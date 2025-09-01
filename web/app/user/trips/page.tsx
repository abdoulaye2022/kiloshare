'use client';

import { useState, useEffect } from 'react';

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
  created_at: string;
  updated_at: string;
}

export default function UserTrips() {
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingTrip, setEditingTrip] = useState<Trip | null>(null);

  useEffect(() => {
    fetchUserTrips();
  }, []);

  const fetchUserTrips = async () => {
    try {
      // Pour cette démo, nous utilisons le token admin
      // Dans une vraie application, le token viendrait de l'authentification utilisateur
      const token = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJraWxvc2hhcmUtYXBpIiwiYXVkIjoia2lsb3NoYXJlLWFwcCIsImlhdCI6MTc1NjU5MzAyMywiZXhwIjoxNzU2NTk2NjIzLCJzdWIiOiI4ZTUwM2E3ZS02YmU5LTRlMzgtODE2Ny1iMDkwYmFmOTQzNTkiLCJ1c2VyIjp7ImlkIjoxLCJ1dWlkIjoiOGU1MDNhN2UtNmJlOS00ZTM4LTgxNjctYjA5MGJhZjk0MzU5IiwiZW1haWwiOiJhZG1pbkBnbWFpbC5jb20iLCJwaG9uZSI6bnVsbCwiZmlyc3RfbmFtZSI6IkFsaSIsImxhc3RfbmFtZSI6IlNhbmkiLCJpc192ZXJpZmllZCI6dHJ1ZSwicm9sZSI6ImFkbWluIn0sInR5cGUiOiJhY2Nlc3MifQ.ONhQBkQh7fNvzzYco961gP2eh1Zr5ZbKcSTFwN65bF4'; 
      
      const response = await fetch('/api/user/trips', {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (response.ok) {
        const data = await response.json();
        setTrips(data.trips || []);
      } else {
        console.error('Failed to fetch user trips');
      }
    } catch (error) {
      console.error('Error fetching trips:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateTrip = async (tripId: string, updateData: Partial<Trip>) => {
    try {
      const token = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJraWxvc2hhcmUtYXBpIiwiYXVkIjoia2lsb3NoYXJlLWFwcCIsImlhdCI6MTc1NjU5MzAyMywiZXhwIjoxNzU2NTk2NjIzLCJzdWIiOiI4ZTUwM2E3ZS02YmU5LTRlMzgtODE2Ny1iMDkwYmFmOTQzNTkiLCJ1c2VyIjp7ImlkIjoxLCJ1dWlkIjoiOGU1MDNhN2UtNmJlOS00ZTM4LTgxNjctYjA5MGJhZjk0MzU5IiwiZW1haWwiOiJhZG1pbkBnbWFpbC5jb20iLCJwaG9uZSI6bnVsbCwiZmlyc3RfbmFtZSI6IkFsaSIsImxhc3RfbmFtZSI6IlNhbmkiLCJpc192ZXJpZmllZCI6dHJ1ZSwicm9sZSI6ImFkbWluIn0sInR5cGUiOiJhY2Nlc3MifQ.ONhQBkQh7fNvzzYco961gP2eh1Zr5ZbKcSTFwN65bF4';
      const response = await fetch('/api/user/trips/update', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ id: tripId, ...updateData }),
      });

      if (response.ok) {
        fetchUserTrips();
        setEditingTrip(null);
        alert('Voyage mis à jour avec succès!');
      } else {
        alert('Erreur lors de la mise à jour');
      }
    } catch (error) {
      console.error('Error updating trip:', error);
      alert('Erreur lors de la mise à jour');
    }
  };

  const handleDeleteTrip = async (tripId: string) => {
    if (!confirm('Êtes-vous sûr de vouloir supprimer ce voyage ?')) {
      return;
    }

    try {
      const token = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJraWxvc2hhcmUtYXBpIiwiYXVkIjoia2lsb3NoYXJlLWFwcCIsImlhdCI6MTc1NjU5MzAyMywiZXhwIjoxNzU2NTk2NjIzLCJzdWIiOiI4ZTUwM2E3ZS02YmU5LTRlMzgtODE2Ny1iMDkwYmFmOTQzNTkiLCJ1c2VyIjp7ImlkIjoxLCJ1dWlkIjoiOGU1MDNhN2UtNmJlOS00ZTM4LTgxNjctYjA5MGJhZjk0MzU5IiwiZW1haWwiOiJhZG1pbkBnbWFpbC5jb20iLCJwaG9uZSI6bnVsbCwiZmlyc3RfbmFtZSI6IkFsaSIsImxhc3RfbmFtZSI6IlNhbmkiLCJpc192ZXJpZmllZCI6dHJ1ZSwicm9sZSI6ImFkbWluIn0sInR5cGUiOiJhY2Nlc3MifQ.ONhQBkQh7fNvzzYco961gP2eh1Zr5ZbKcSTFwN65bF4';
      const response = await fetch('/api/user/trips/delete', {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ id: tripId }),
      });

      if (response.ok) {
        fetchUserTrips();
        alert('Voyage supprimé avec succès!');
      } else {
        alert('Erreur lors de la suppression');
      }
    } catch (error) {
      console.error('Error deleting trip:', error);
      alert('Erreur lors de la suppression');
    }
  };

  const handleArchiveTrip = async (tripId: string) => {
    if (!confirm('Êtes-vous sûr de vouloir archiver ce voyage ?')) {
      return;
    }

    try {
      const token = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJraWxvc2hhcmUtYXBpIiwiYXVkIjoia2lsb3NoYXJlLWFwcCIsImlhdCI6MTc1NjU5MzAyMywiZXhwIjoxNzU2NTk2NjIzLCJzdWIiOiI4ZTUwM2E3ZS02YmU5LTRlMzgtODE2Ny1iMDkwYmFmOTQzNTkiLCJ1c2VyIjp7ImlkIjoxLCJ1dWlkIjoiOGU1MDNhN2UtNmJlOS00ZTM4LTgxNjctYjA5MGJhZjk0MzU5IiwiZW1haWwiOiJhZG1pbkBnbWFpbC5jb20iLCJwaG9uZSI6bnVsbCwiZmlyc3RfbmFtZSI6IkFsaSIsImxhc3RfbmFtZSI6IlNhbmkiLCJpc192ZXJpZmllZCI6dHJ1ZSwicm9sZSI6ImFkbWluIn0sInR5cGUiOiJhY2Nlc3MifQ.ONhQBkQh7fNvzzYco961gP2eh1Zr5ZbKcSTFwN65bF4';
      const response = await fetch('/api/user/trips/archive', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ id: tripId }),
      });

      if (response.ok) {
        fetchUserTrips();
        alert('Voyage archivé avec succès!');
      } else {
        alert('Erreur lors de l\'archivage');
      }
    } catch (error) {
      console.error('Error archiving trip:', error);
      alert('Erreur lors de l\'archivage');
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'published':
        return 'bg-green-100 text-green-800';
      case 'pending_approval':
        return 'bg-yellow-100 text-yellow-800';
      case 'rejected':
        return 'bg-red-100 text-red-800';
      case 'archived':
        return 'bg-gray-100 text-gray-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'published':
        return 'Publié';
      case 'pending_approval':
        return 'En attente';
      case 'rejected':
        return 'Rejeté';
      case 'archived':
        return 'Archivé';
      default:
        return status;
    }
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
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <h1 className="text-3xl font-bold text-gray-900">
              Mes Voyages
            </h1>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          {trips.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-500 text-lg">
                Aucun voyage trouvé
              </p>
            </div>
          ) : (
            <div className="grid gap-6">
              {trips.map((trip) => (
                <div key={trip.id} className="bg-white shadow rounded-lg p-6">
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center mb-4">
                        <span className="text-2xl mr-3">✈️</span>
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
                          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(trip.status)}`}>
                            {getStatusLabel(trip.status)}
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="ml-4 flex flex-col space-y-2">
                      {trip.status === 'published' && (
                        <>
                          <button
                            onClick={() => setEditingTrip(trip)}
                            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                          >
                            ✏️ Modifier
                          </button>
                          <button
                            onClick={() => handleArchiveTrip(trip.id)}
                            className="bg-yellow-600 hover:bg-yellow-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                          >
                            📦 Archiver
                          </button>
                        </>
                      )}
                      <button
                        onClick={() => handleDeleteTrip(trip.id)}
                        className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                      >
                        🗑️ Supprimer
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>

      {/* Modal de modification */}
      {editingTrip && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <h3 className="text-lg font-medium text-gray-900 mb-4">
                Modifier le voyage
              </h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Poids disponible (kg)
                  </label>
                  <input
                    type="number"
                    value={editingTrip.available_weight_kg}
                    onChange={(e) => setEditingTrip({
                      ...editingTrip,
                      available_weight_kg: parseFloat(e.target.value)
                    })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Prix par kg
                  </label>
                  <input
                    type="number"
                    value={editingTrip.price_per_kg}
                    onChange={(e) => setEditingTrip({
                      ...editingTrip,
                      price_per_kg: parseFloat(e.target.value)
                    })}
                    className="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2"
                  />
                </div>
              </div>

              <div className="flex justify-end space-x-3 mt-6">
                <button
                  onClick={() => setEditingTrip(null)}
                  className="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400"
                >
                  Annuler
                </button>
                <button
                  onClick={() => handleUpdateTrip(editingTrip.id, {
                    available_weight_kg: editingTrip.available_weight_kg,
                    price_per_kg: editingTrip.price_per_kg
                  })}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  Sauvegarder
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}