'use client';

import React, { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { MapPin, Calendar, Package2 as Weight, DollarSign, User, MessageCircle, ArrowLeft, ImageIcon } from 'lucide-react';
import ImageUpload from '../../../components/ImageUpload';

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
  images?: string[];
}

interface ProposalData {
  tripId: number;
  packageDescription: string;
  weightKg: number;
  pickupAddress: string;
  deliveryAddress: string;
  specialInstructions?: string;
}

export default function TripDetailClient() {
  const params = useParams();
  const router = useRouter();
  const tripId = params.id;

  const [trip, setTrip] = useState<Trip | null>(null);
  const [loading, setLoading] = useState(true);
  const [showProposalModal, setShowProposalModal] = useState(false);
  const [showAppBanner, setShowAppBanner] = useState(true);
  const [isFromExternalLink, setIsFromExternalLink] = useState(false);
  const [proposalData, setProposalData] = useState<ProposalData>({
    tripId: 0,
    packageDescription: '',
    weightKg: 0,
    pickupAddress: '',
    deliveryAddress: '',
    specialInstructions: ''
  });
  const [isOwner, setIsOwner] = useState(false);

  useEffect(() => {
    // Détecter si l'utilisateur vient d'un lien externe (pas de referrer interne)
    const referrer = document.referrer;
    const isExternal = !referrer || (!referrer.includes('localhost:3000') && !referrer.includes('kiloshare.com'));
    setIsFromExternalLink(isExternal);

    // Si l'utilisateur vient d'un lien externe, rediriger vers la page /redirect
    // pour tenter d'ouvrir l'app automatiquement
    if (isExternal && tripId) {
      // Rediriger immédiatement vers la page de redirection
      router.push(`/trips/${tripId}/redirect`);
      return;
    }

    // Sinon, charger les détails du voyage normalement
    if (tripId) {
      fetchTripDetails();
    }
  }, [tripId, router]);

  useEffect(() => {
    if (trip) {
      checkOwnership();
    }
  }, [trip]);

  const fetchTripDetails = async () => {
    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080'}/api/v1/trips/${tripId}`);

      if (response.ok) {
        const data = await response.json();
        const tripData = data.data?.trip || data.trip || data;
        setTrip(tripData);
      } else {
        console.error('Failed to fetch trip details');
      }
    } catch (error) {
      console.error('Error fetching trip details:', error);
    } finally {
      setLoading(false);
    }
  };

  const checkOwnership = async () => {
    try {
      const token = localStorage.getItem('auth_token');
      if (!token) return;

      const userResponse = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080'}/api/v1/user/profile`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      if (userResponse.ok) {
        const userData = await userResponse.json();
        const currentUserId = userData.user?.id || userData.id;

        if (trip && currentUserId) {
          setIsOwner(trip.user_id === currentUserId);
        }
      }
    } catch (error) {
      console.error('Error checking ownership:', error);
    }
  };

  const handleOpenInApp = () => {
    // Deep link vers l'app
    window.location.href = `kiloshare://trips/${tripId}`;

    // Fallback vers le store après 2 secondes si l'app n'est pas installée
    setTimeout(() => {
      if (navigator.userAgent.match(/Android/i)) {
        window.location.href = 'https://play.google.com/store/apps/details?id=com.m2atech.kiloshare';
      } else if (navigator.userAgent.match(/iPhone|iPad|iPod/i)) {
        window.location.href = 'https://apps.apple.com/app/kiloshare/id123456789';
      }
    }, 2000);
  };

  const handleMakeProposal = (trip: Trip) => {
    setProposalData({
      tripId: trip.id,
      packageDescription: '',
      weightKg: 0,
      pickupAddress: '',
      deliveryAddress: '',
      specialInstructions: ''
    });
    setShowProposalModal(true);
  };

  const submitProposal = async () => {
    if (!trip) return;

    try {
      const token = localStorage.getItem('auth_token') || 'demo_token';

      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080'}/api/v1/bookings/request`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          trip_id: trip.id,
          receiver_id: trip.user_id,
          package_description: proposalData.packageDescription,
          weight: proposalData.weightKg,
          pickup_address: proposalData.pickupAddress,
          delivery_address: proposalData.deliveryAddress,
          pickup_notes: proposalData.specialInstructions
        })
      });

      if (response.ok) {
        alert('🎉 Proposition envoyée avec succès ! Le transporteur va recevoir une notification.');
        setShowProposalModal(false);
      } else {
        const errorData = await response.json();
        alert('Erreur : ' + (errorData.error || 'Impossible d\'envoyer la proposition'));
      }
    } catch (error) {
      console.error('Error submitting proposal:', error);
      alert('Erreur lors de l\'envoi de la proposition');
    }
  };

  const handleImagesChange = (images: string[]) => {
    if (trip) {
      setTrip({ ...trip, images });
    }
  };

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

  if (!trip) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <h2 className="text-2xl font-bold text-gray-900 mb-4">Voyage non trouvé</h2>
          <p className="text-gray-600 mb-6">Ce voyage n'existe pas ou a été supprimé.</p>
          <button
            onClick={() => router.push(isFromExternalLink ? '/' : '/trips')}
            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg"
          >
            {isFromExternalLink ? 'Retour à l\'accueil' : 'Retour aux voyages'}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Banner pour ouvrir dans l'app */}
      {showAppBanner && (
        <div className="bg-gradient-to-r from-blue-600 to-blue-700 text-white px-4 py-3 shadow-lg">
          <div className="max-w-7xl mx-auto flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-white rounded-lg flex items-center justify-center">
                <span className="text-2xl">🧳</span>
              </div>
              <div>
                <p className="font-semibold">KiloShare</p>
                <p className="text-sm text-blue-100">Meilleure expérience dans l'app</p>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <button
                onClick={handleOpenInApp}
                className="bg-white text-blue-600 px-4 py-2 rounded-lg font-medium hover:bg-blue-50 transition-colors"
              >
                Ouvrir
              </button>
              <button
                onClick={() => setShowAppBanner(false)}
                className="text-white hover:text-blue-100 p-2"
              >
                ✕
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center py-6">
            <button
              onClick={() => {
                // Si l'utilisateur vient d'un lien externe, retourner à l'accueil
                // Sinon, retourner à la liste des voyages
                if (isFromExternalLink) {
                  router.push('/');
                } else {
                  router.push('/trips');
                }
              }}
              className="mr-4 p-2 rounded-lg hover:bg-gray-100 transition-colors"
              title={isFromExternalLink ? 'Retour à l\'accueil' : 'Retour aux voyages'}
            >
              <ArrowLeft className="h-5 w-5 text-gray-600" />
            </button>
            <h1 className="text-3xl font-bold text-gray-900">
              Détails du voyage
            </h1>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Colonne principale */}
          <div className="lg:col-span-2 space-y-6">
            {/* Informations du voyage */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <div className="flex items-center justify-between mb-6">
                <div className="flex items-center text-2xl font-bold text-gray-900">
                  <MapPin className="h-6 w-6 text-green-500 mr-2" />
                  {trip.departure_city}, {trip.departure_country}
                  <span className="mx-4 text-gray-400">→</span>
                  <MapPin className="h-6 w-6 text-red-500 mr-2" />
                  {trip.arrival_city}, {trip.arrival_country}
                </div>
                <div className="text-right">
                  <div className="text-3xl font-bold text-blue-600">
                    {formatPrice(trip.price_per_kg)}/kg
                  </div>
                  <div className="text-sm text-gray-500">
                    {trip.currency}
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
                <div className="flex items-center text-gray-600">
                  <Calendar className="h-5 w-5 mr-3" />
                  <div>
                    <div className="font-medium">Date de départ</div>
                    <div className="text-sm">{formatDate(trip.departure_date)}</div>
                  </div>
                </div>
                <div className="flex items-center text-gray-600">
                  <Weight className="h-5 w-5 mr-3" />
                  <div>
                    <div className="font-medium">Poids disponible</div>
                    <div className="text-sm">{trip.available_weight_kg} kg</div>
                  </div>
                </div>
                <div className="flex items-center text-gray-600">
                  <User className="h-5 w-5 mr-3" />
                  <div>
                    <div className="font-medium">Transporteur</div>
                    <div className="text-sm">{trip.user_name || 'Voyageur vérifié'}</div>
                  </div>
                </div>
              </div>

              {trip.description && (
                <div className="mb-6">
                  <h3 className="font-semibold text-gray-900 mb-2">Description</h3>
                  <p className="text-gray-700 bg-gray-50 p-4 rounded-lg">{trip.description}</p>
                </div>
              )}

              {/* Section des images */}
              <div className="mb-6">
                <h3 className="font-semibold text-gray-900 mb-4 flex items-center">
                  <ImageIcon className="h-5 w-5 mr-2" />
                  Images du voyage
                </h3>

                {/* Affichage des images existantes */}
                {trip.images && trip.images.length > 0 && (
                  <div className="mb-6">
                    <h4 className="text-sm font-medium text-gray-700 mb-3">Images actuelles :</h4>
                    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                      {trip.images.map((image, index) => (
                        <div key={index} className="aspect-square rounded-lg overflow-hidden bg-gray-100 border-2 border-gray-200">
                          <img
                            src={image}
                            alt={`Image ${index + 1} du voyage`}
                            className="w-full h-full object-cover"
                          />
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Composant d'upload pour le propriétaire */}
                {isOwner && (
                  <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-3">
                      {trip.images && trip.images.length > 0 ? 'Ajouter plus d\'images :' : 'Ajouter des images :'}
                    </h4>
                    <ImageUpload
                      tripId={trip.id}
                      existingImages={trip.images}
                      onImagesChange={handleImagesChange}
                      maxImages={5}
                      maxFileSize={5}
                    />
                  </div>
                )}

                {/* Message si pas d'images et pas propriétaire */}
                {!trip.images?.length && !isOwner && (
                  <div className="text-center py-8 border-2 border-dashed border-gray-300 rounded-lg">
                    <ImageIcon className="mx-auto h-12 w-12 text-gray-400 mb-2" />
                    <p className="text-gray-500">Aucune image disponible pour ce voyage</p>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Statut et poids restant */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="font-semibold text-gray-900 mb-4">Disponibilité</h3>
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-gray-600">Statut :</span>
                  <span className="font-medium capitalize text-green-600">
                    {trip.status === 'active' ? 'Actif' : trip.status}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Poids restant :</span>
                  <span className="font-medium">
                    {trip.remaining_weight || trip.available_weight_kg} kg
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Prix total max :</span>
                  <span className="font-medium text-blue-600">
                    {formatPrice((trip.remaining_weight || trip.available_weight_kg) * trip.price_per_kg)}
                  </span>
                </div>
              </div>
            </div>

            {/* Actions */}
            {!isOwner && (
              <div className="bg-white rounded-lg shadow-md p-6">
                <h3 className="font-semibold text-gray-900 mb-4">Actions</h3>
                <div className="space-y-3">
                  <button
                    onClick={() => handleMakeProposal(trip)}
                    className="w-full bg-blue-600 hover:bg-blue-700 text-white px-4 py-3 rounded-lg flex items-center justify-center space-x-2 transition-colors"
                  >
                    <MessageCircle className="h-5 w-5" />
                    <span>Faire une proposition</span>
                  </button>
                  <button className="w-full bg-green-600 hover:bg-green-700 text-white px-4 py-3 rounded-lg flex items-center justify-center space-x-2 transition-colors">
                    <DollarSign className="h-5 w-5" />
                    <span>Payer directement</span>
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>

      {/* Modal de proposition */}
      {showProposalModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl max-w-md w-full p-6 max-h-[90vh] overflow-y-auto">
            <h2 className="text-2xl font-bold text-gray-800 mb-4">
              Faire une proposition
            </h2>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <h3 className="font-semibold text-blue-800 mb-2">Voyage sélectionné</h3>
              <p className="text-sm text-blue-700">
                {trip.departure_city} → {trip.arrival_city}
              </p>
              <p className="text-sm text-blue-700">
                {formatDate(trip.departure_date)}
              </p>
              <p className="text-sm text-blue-700">
                Prix affiché : {formatPrice(trip.price_per_kg)}/kg
              </p>
            </div>

            <div className="space-y-4">
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

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Poids (kg) *
                </label>
                <input
                  type="number"
                  step="0.1"
                  min="0.1"
                  max={trip.available_weight_kg}
                  value={proposalData.weightKg}
                  onChange={(e) => {
                    const weight = parseFloat(e.target.value);
                    setProposalData({
                      ...proposalData,
                      weightKg: weight
                    });
                  }}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
                <p className="mt-1 text-sm text-gray-600">
                  Prix total: {(proposalData.weightKg * trip.price_per_kg).toFixed(2)} CAD
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Adresse de récupération *
                </label>
                <input
                  type="text"
                  value={proposalData.pickupAddress}
                  onChange={(e) => setProposalData({...proposalData, pickupAddress: e.target.value})}
                  placeholder={`Adresse dans ${trip.departure_city}`}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Adresse de livraison *
                </label>
                <input
                  type="text"
                  value={proposalData.deliveryAddress}
                  onChange={(e) => setProposalData({...proposalData, deliveryAddress: e.target.value})}
                  placeholder={`Adresse dans ${trip.arrival_city}`}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Instructions spéciales (optionnel)
                </label>
                <textarea
                  value={proposalData.specialInstructions}
                  onChange={(e) => setProposalData({...proposalData, specialInstructions: e.target.value})}
                  placeholder="Détails sur la fragilité, horaires préférés..."
                  rows={2}
                  className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>

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
