'use client';

import React, { useState, useEffect } from 'react';
import { Search, MapPin, Calendar, Package2 as Weight, DollarSign, User, MessageCircle, Eye } from 'lucide-react';
import { useRouter } from 'next/navigation';

interface Trip {
  id: number;
  uuid: string;
  user_id: number;
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
  user_name?: string;
  user_email?: string;
  remaining_weight?: number;
}

interface ProposalData {
  tripId: number;
  packageDescription: string;
  weightKg: number;
  proposedPrice: number;
  pickupAddress: string;
  deliveryAddress: string;
  specialInstructions?: string;
}

export default function TripsListPage() {
  const router = useRouter();
  const [trips, setTrips] = useState<Trip[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [showProposalModal, setShowProposalModal] = useState(false);
  const [selectedTrip, setSelectedTrip] = useState<Trip | null>(null);
  const [proposalData, setProposalData] = useState<ProposalData>({
    tripId: 0,
    packageDescription: '',
    weightKg: 0,
    proposedPrice: 0,
    pickupAddress: '',
    deliveryAddress: '',
    specialInstructions: ''
  });

  useEffect(() => {
    fetchPublicTrips();
  }, []);

  const fetchPublicTrips = async () => {
    try {
      // Utiliser l'API de recherche publique pour obtenir les voyages disponibles
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'}/api/v1/search/trips?status=active&limit=50`);
      
      if (response.ok) {
        const data = await response.json();
        setTrips(data.trips || []);
      } else {
        console.error('Failed to fetch trips');
      }
    } catch (error) {
      console.error('Error fetching trips:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleMakeProposal = (trip: Trip) => {
    setSelectedTrip(trip);
    setProposalData({
      tripId: trip.id,
      packageDescription: '',
      weightKg: 0,
      proposedPrice: trip.price_per_kg * 1, // Default to price per kg
      pickupAddress: '',
      deliveryAddress: '',
      specialInstructions: ''
    });
    setShowProposalModal(true);
  };

  const submitProposal = async () => {
    if (!selectedTrip) return;

    try {
      // On utilisera un token d'auth réel dans l'implémentation finale
      const token = localStorage.getItem('auth_token') || 'demo_token';
      
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8000'}/api/v1/bookings/request`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          trip_id: selectedTrip.id,
          receiver_id: selectedTrip.user_id,
          package_description: proposalData.packageDescription,
          weight_kg: proposalData.weightKg,
          proposed_price: proposalData.proposedPrice,
          pickup_address: proposalData.pickupAddress,
          delivery_address: proposalData.deliveryAddress,
          special_instructions: proposalData.specialInstructions
        })
      });

      if (response.ok) {
        alert('🎉 Proposition envoyée avec succès ! Le transporteur va recevoir une notification.');
        setShowProposalModal(false);
        setSelectedTrip(null);
      } else {
        const errorData = await response.json();
        alert('Erreur : ' + (errorData.error || 'Impossible d\'envoyer la proposition'));
      }
    } catch (error) {
      console.error('Error submitting proposal:', error);
      alert('Erreur lors de l\'envoi de la proposition');
    }
  };

  const filteredTrips = trips.filter(trip =>
    trip.departure_city.toLowerCase().includes(searchTerm.toLowerCase()) ||
    trip.arrival_city.toLowerCase().includes(searchTerm.toLowerCase()) ||
    trip.departure_country.toLowerCase().includes(searchTerm.toLowerCase()) ||
    trip.arrival_country.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('fr-CA', {
      day: 'numeric',
      month: 'long',
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
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <h1 className="text-3xl font-bold text-gray-900">
              Voyages disponibles
            </h1>
            <div className="text-sm text-gray-600">
              {filteredTrips.length} voyage{filteredTrips.length !== 1 ? 's' : ''} trouvé{filteredTrips.length !== 1 ? 's' : ''}
            </div>
          </div>
        </div>
      </header>

      {/* Search Bar */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="relative max-w-md">
          <Search className="absolute left-3 top-3 h-5 w-5 text-gray-400" />
          <input
            type="text"
            placeholder="Rechercher par ville..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* Trips List */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-12">
        {filteredTrips.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-gray-500 text-lg">
              Aucun voyage trouvé pour votre recherche
            </p>
          </div>
        ) : (
          <div className="grid gap-6">
            {filteredTrips.map((trip) => (
              <div key={trip.id} className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
                <div className="p-6">
                  {/* Header avec route */}
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center space-x-4">
                      <div className="flex items-center text-lg font-semibold text-gray-900">
                        <MapPin className="h-5 w-5 text-green-500 mr-1" />
                        {trip.departure_city}, {trip.departure_country}
                        <span className="mx-3 text-gray-400">→</span>
                        <MapPin className="h-5 w-5 text-red-500 mr-1" />
                        {trip.arrival_city}, {trip.arrival_country}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-2xl font-bold text-blue-600">
                        {formatPrice(trip.price_per_kg)}/kg
                      </div>
                      <div className="text-sm text-gray-500">
                        {trip.currency}
                      </div>
                    </div>
                  </div>

                  {/* Détails du voyage */}
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                    <div className="flex items-center text-gray-600">
                      <Calendar className="h-4 w-4 mr-2" />
                      <span className="text-sm">{formatDate(trip.departure_date)}</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <Weight className="h-4 w-4 mr-2" />
                      <span className="text-sm">{trip.available_weight_kg} kg disponibles</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <User className="h-4 w-4 mr-2" />
                      <span className="text-sm">{trip.user_name || 'Voyageur vérifié'}</span>
                    </div>
                  </div>

                  {/* Description */}
                  {trip.description && (
                    <div className="mb-4 p-3 bg-gray-50 rounded-lg">
                      <p className="text-sm text-gray-700">{trip.description}</p>
                    </div>
                  )}

                  {/* Actions */}
                  <div className="flex items-center justify-between pt-4 border-t border-gray-200">
                    <div className="flex items-center space-x-4">
                      <span className="text-sm text-gray-500">
                        Poids restant : {trip.remaining_weight || trip.available_weight_kg} kg
                      </span>
                    </div>
                    <div className="flex space-x-3">
                      <button
                        onClick={() => router.push(`/trips/${trip.id}`)}
                        className="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded-lg flex items-center space-x-2 transition-colors"
                      >
                        <Eye className="h-4 w-4" />
                        <span>Voir détails</span>
                      </button>
                      <button
                        onClick={() => handleMakeProposal(trip)}
                        className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg flex items-center space-x-2 transition-colors"
                      >
                        <MessageCircle className="h-4 w-4" />
                        <span>Proposition</span>
                      </button>
                      <button className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg flex items-center space-x-2 transition-colors">
                        <DollarSign className="h-4 w-4" />
                        <span>Payer</span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>

      {/* Modal de proposition */}
      {showProposalModal && selectedTrip && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6 max-h-[90vh] overflow-y-auto">
            <h2 className="text-2xl font-bold text-gray-800 mb-4">
              Faire une proposition
            </h2>
            
            {/* Résumé du voyage */}
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <h3 className="font-semibold text-blue-800 mb-2">Voyage sélectionné</h3>
              <p className="text-sm text-blue-700">
                {selectedTrip.departure_city} → {selectedTrip.arrival_city}
              </p>
              <p className="text-sm text-blue-700">
                {formatDate(selectedTrip.departure_date)}
              </p>
              <p className="text-sm text-blue-700">
                Prix affiché : {formatPrice(selectedTrip.price_per_kg)}/kg
              </p>
            </div>

            <div className="space-y-4">
              {/* Description du colis */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description du colis *
                </label>
                <textarea
                  value={proposalData.packageDescription}
                  onChange={(e) => setProposalData({...proposalData, packageDescription: e.target.value})}
                  placeholder="Ex: Vêtements, souvenirs, documents..."
                  rows={3}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>

              {/* Poids */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Poids (kg) *
                </label>
                <input
                  type="number"
                  step="0.1"
                  min="0.1"
                  max={selectedTrip.available_weight_kg}
                  value={proposalData.weightKg}
                  onChange={(e) => {
                    const weight = parseFloat(e.target.value);
                    setProposalData({
                      ...proposalData, 
                      weightKg: weight,
                      proposedPrice: weight * selectedTrip.price_per_kg
                    });
                  }}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
                <p className="text-xs text-gray-500 mt-1">
                  Maximum : {selectedTrip.available_weight_kg} kg
                </p>
              </div>

              {/* Prix proposé */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Prix total proposé *
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  value={proposalData.proposedPrice}
                  onChange={(e) => setProposalData({...proposalData, proposedPrice: parseFloat(e.target.value)})}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
                {proposalData.weightKg > 0 && (
                  <p className="text-xs text-gray-500 mt-1">
                    ≈ {formatPrice(proposalData.proposedPrice / proposalData.weightKg)}/kg
                    {proposalData.proposedPrice !== (proposalData.weightKg * selectedTrip.price_per_kg) && (
                      <span className="text-orange-600 font-medium">
                        {' '}(Prix différent du tarif affiché)
                      </span>
                    )}
                  </p>
                )}
              </div>

              {/* Adresse de récupération */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Adresse de récupération *
                </label>
                <input
                  type="text"
                  value={proposalData.pickupAddress}
                  onChange={(e) => setProposalData({...proposalData, pickupAddress: e.target.value})}
                  placeholder={`Adresse dans ${selectedTrip.departure_city}`}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>

              {/* Adresse de livraison */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Adresse de livraison *
                </label>
                <input
                  type="text"
                  value={proposalData.deliveryAddress}
                  onChange={(e) => setProposalData({...proposalData, deliveryAddress: e.target.value})}
                  placeholder={`Adresse dans ${selectedTrip.arrival_city}`}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>

              {/* Instructions spéciales */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Instructions spéciales (optionnel)
                </label>
                <textarea
                  value={proposalData.specialInstructions}
                  onChange={(e) => setProposalData({...proposalData, specialInstructions: e.target.value})}
                  placeholder="Détails sur la fragililité, horaires préférés..."
                  rows={2}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>

            {/* Boutons d'action */}
            <div className="flex justify-end space-x-3 mt-6">
              <button
                onClick={() => setShowProposalModal(false)}
                className="px-4 py-2 text-gray-600 bg-gray-200 rounded-lg hover:bg-gray-300 transition-colors"
              >
                Annuler
              </button>
              <button
                onClick={submitProposal}
                disabled={!proposalData.packageDescription || !proposalData.weightKg || !proposalData.pickupAddress || !proposalData.deliveryAddress}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Envoyer la proposition
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}