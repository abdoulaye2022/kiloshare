'use client';

import React, { useState, useEffect } from 'react';
import { useBooking } from '../../../hooks/useBooking';
import BookingNegotiationCard from '../../components/BookingNegotiationCard';
import StripeAccountSetupModal from '../../components/StripeAccountSetupModal';
import { MapPin, Calendar, Package, DollarSign, MessageCircle, Check, X, RefreshCw } from 'lucide-react';

interface Booking {
  id: number;
  trip_id: number;
  sender_id: number;
  receiver_id: number;
  package_description: string;
  weight_kg: number;
  proposed_price: number;
  final_price?: number;
  status: string;
  pickup_address?: string;
  delivery_address?: string;
  special_instructions?: string;
  created_at: string;
  // Infos du voyage
  departure_city?: string;
  arrival_city?: string;
  departure_date?: string;
  // Infos de l'expéditeur
  sender_name?: string;
  sender_email?: string;
  // Négociations
  negotiations?: Negotiation[];
}

interface Negotiation {
  id: number;
  booking_id: number;
  proposed_by: number;
  amount: number;
  message: string | null;
  is_accepted: boolean;
  created_at: string;
  first_name?: string;
  email?: string;
}

export default function ProposalsPage() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'received' | 'sent'>('received');
  const [showStripeModal, setShowStripeModal] = useState(false);
  const [stripeAccountData, setStripeAccountData] = useState<any>(null);
  const [motivationalMessage, setMotivationalMessage] = useState('');
  
  const { acceptBooking, acceptNegotiation, getUserBookings, loading: actionLoading } = useBooking();

  useEffect(() => {
    fetchBookings();
  }, [activeTab]);

  const fetchBookings = async () => {
    setLoading(true);
    const role = activeTab === 'received' ? 'receiver' : 'sender';
    const data = await getUserBookings(role);
    if (data) {
      setBookings(data);
    }
    setLoading(false);
  };

  const handleAcceptBooking = async (bookingId: number, finalPrice?: number) => {
    const result = await acceptBooking(bookingId, finalPrice);
    
    if (result?.success) {
      // Vérifier si un compte Stripe a été créé
      if (result.stripe_account_created && result.stripe_account) {
        setStripeAccountData(result.stripe_account);
        setMotivationalMessage(result.motivational_message || '');
        setShowStripeModal(true);
      }
      
      // Recharger les propositions
      fetchBookings();
    }
  };

  const handleAcceptNegotiation = async (bookingId: number, negotiationId: number) => {
    const result = await acceptNegotiation(bookingId, negotiationId);
    
    if (result?.success) {
      // Vérifier si un compte Stripe a été créé
      if (result.stripe_account_created && result.stripe_account) {
        setStripeAccountData(result.stripe_account);
        setMotivationalMessage(result.motivational_message || '');
        setShowStripeModal(true);
      }
      
      // Recharger les propositions
      fetchBookings();
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('fr-CA', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
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

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending':
        return 'bg-yellow-100 text-yellow-800';
      case 'accepted':
        return 'bg-green-100 text-green-800';
      case 'rejected':
        return 'bg-red-100 text-red-800';
      case 'payment_pending':
        return 'bg-blue-100 text-blue-800';
      case 'paid':
        return 'bg-purple-100 text-purple-800';
      case 'completed':
        return 'bg-green-100 text-green-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusLabel = (status: string) => {
    const labels: Record<string, string> = {
      'pending': 'En attente',
      'accepted': 'Acceptée',
      'rejected': 'Refusée',
      'payment_pending': 'Paiement en attente',
      'paid': 'Payée',
      'completed': 'Terminée',
    };
    return labels[status] || status;
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
            <div>
              <h1 className="text-3xl font-bold text-gray-900">
                Mes propositions
              </h1>
              <p className="text-gray-600 mt-1">
                Gérez vos demandes de transport et négociations
              </p>
            </div>
            <button
              onClick={fetchBookings}
              disabled={loading}
              className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50"
            >
              <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              <span>Actualiser</span>
            </button>
          </div>
        </div>
      </header>

      {/* Tabs */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="border-b border-gray-200">
          <nav className="-mb-px flex space-x-8">
            <button
              onClick={() => setActiveTab('received')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'received'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Propositions reçues
              {bookings.filter(b => b.status === 'pending').length > 0 && (
                <span className="ml-2 bg-red-100 text-red-800 text-xs font-medium px-2 py-1 rounded-full">
                  {bookings.filter(b => b.status === 'pending').length}
                </span>
              )}
            </button>
            <button
              onClick={() => setActiveTab('sent')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'sent'
                  ? 'border-blue-500 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              }`}
            >
              Propositions envoyées
            </button>
          </nav>
        </div>
      </div>

      {/* Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {bookings.length === 0 ? (
          <div className="text-center py-12">
            <Package className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">
              {activeTab === 'received' ? 'Aucune proposition reçue' : 'Aucune proposition envoyée'}
            </h3>
            <p className="mt-1 text-sm text-gray-500">
              {activeTab === 'received' 
                ? 'Vos voyages publics recevront des propositions ici.'
                : 'Vous n\'avez pas encore fait de propositions.'}
            </p>
          </div>
        ) : (
          <div className="space-y-6">
            {bookings.map((booking) => (
              <div key={booking.id} className="bg-white rounded-lg shadow-md overflow-hidden">
                <div className="p-6">
                  {/* Header avec route et statut */}
                  <div className="flex items-center justify-between mb-4">
                    <div className="flex items-center space-x-4">
                      <div className="flex items-center text-lg font-semibold text-gray-900">
                        <MapPin className="h-5 w-5 text-green-500 mr-1" />
                        {booking.departure_city || 'Départ'}
                        <span className="mx-3 text-gray-400">→</span>
                        <MapPin className="h-5 w-5 text-red-500 mr-1" />
                        {booking.arrival_city || 'Arrivée'}
                      </div>
                    </div>
                    <div className="flex items-center space-x-3">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(booking.status)}`}>
                        {getStatusLabel(booking.status)}
                      </span>
                      <div className="text-right">
                        <div className="text-lg font-bold text-blue-600">
                          {formatPrice(booking.final_price || booking.proposed_price)}
                        </div>
                        <div className="text-xs text-gray-500">
                          {booking.weight_kg} kg
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Infos de la proposition */}
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                    <div className="flex items-center text-gray-600">
                      <Calendar className="h-4 w-4 mr-2" />
                      <span className="text-sm">
                        {booking.departure_date 
                          ? formatDate(booking.departure_date)
                          : formatDate(booking.created_at)
                        }
                      </span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <Package className="h-4 w-4 mr-2" />
                      <span className="text-sm">{booking.package_description}</span>
                    </div>
                    <div className="flex items-center text-gray-600">
                      <DollarSign className="h-4 w-4 mr-2" />
                      <span className="text-sm">
                        {formatPrice(booking.proposed_price / booking.weight_kg)}/kg
                      </span>
                    </div>
                  </div>

                  {/* Adresses */}
                  {(booking.pickup_address || booking.delivery_address) && (
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4 p-3 bg-gray-50 rounded-lg">
                      {booking.pickup_address && (
                        <div>
                          <p className="text-xs text-gray-500 font-medium">Récupération</p>
                          <p className="text-sm text-gray-700">{booking.pickup_address}</p>
                        </div>
                      )}
                      {booking.delivery_address && (
                        <div>
                          <p className="text-xs text-gray-500 font-medium">Livraison</p>
                          <p className="text-sm text-gray-700">{booking.delivery_address}</p>
                        </div>
                      )}
                    </div>
                  )}

                  {/* Instructions spéciales */}
                  {booking.special_instructions && (
                    <div className="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
                      <p className="text-xs text-blue-600 font-medium mb-1">Instructions spéciales</p>
                      <p className="text-sm text-blue-800">{booking.special_instructions}</p>
                    </div>
                  )}

                  {/* Infos de l'expéditeur/destinataire */}
                  <div className="mb-4 flex items-center text-sm text-gray-600">
                    <span className="font-medium">
                      {activeTab === 'received' ? 'Expéditeur' : 'Transporteur'} : 
                    </span>
                    <span className="ml-2">
                      {booking.sender_name || 'Utilisateur'} ({booking.sender_email})
                    </span>
                  </div>

                  {/* Négociations */}
                  {booking.negotiations && booking.negotiations.length > 0 && (
                    <div className="mb-4">
                      <h4 className="text-sm font-medium text-gray-700 mb-3 flex items-center">
                        <MessageCircle className="h-4 w-4 mr-2" />
                        Négociations ({booking.negotiations.length})
                      </h4>
                      <div className="space-y-3">
                        {booking.negotiations.map((negotiation) => (
                          <BookingNegotiationCard
                            key={negotiation.id}
                            negotiation={negotiation}
                            bookingId={booking.id}
                            canAccept={activeTab === 'received' && booking.status === 'pending'}
                            onAccepted={() => handleAcceptNegotiation(booking.id, negotiation.id)}
                          />
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Actions pour propositions reçues */}
                  {activeTab === 'received' && booking.status === 'pending' && (
                    <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                      <button
                        className="flex items-center space-x-2 px-4 py-2 text-red-600 bg-red-50 rounded-lg hover:bg-red-100 transition-colors"
                      >
                        <X className="h-4 w-4" />
                        <span>Refuser</span>
                      </button>
                      <button
                        onClick={() => handleAcceptBooking(booking.id)}
                        disabled={actionLoading}
                        className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors"
                      >
                        <Check className="h-4 w-4" />
                        <span>Accepter</span>
                        {actionLoading && <RefreshCw className="h-4 w-4 animate-spin" />}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </main>

      {/* Modal Stripe */}
      {showStripeModal && stripeAccountData && (
        <StripeAccountSetupModal
          isOpen={showStripeModal}
          onClose={() => setShowStripeModal(false)}
          stripeAccount={stripeAccountData}
          motivationalMessage={motivationalMessage}
        />
      )}
    </div>
  );
}