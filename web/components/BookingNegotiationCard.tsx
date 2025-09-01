'use client';

import React, { useState } from 'react';
import { useBooking } from '../hooks/useBooking';
import StripeAccountSetupModal from './StripeAccountSetupModal';

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

interface BookingNegotiationCardProps {
  negotiation: Negotiation;
  bookingId: number;
  canAccept: boolean; // true si l'utilisateur connecté est le receiver
  onAccepted?: () => void;
}

export default function BookingNegotiationCard({
  negotiation,
  bookingId,
  canAccept,
  onAccepted
}: BookingNegotiationCardProps) {
  const { acceptNegotiation, loading } = useBooking();
  const [showStripeModal, setShowStripeModal] = useState(false);
  const [stripeAccountData, setStripeAccountData] = useState<any>(null);
  const [motivationalMessage, setMotivationalMessage] = useState('');

  const formatAmount = (amount: number) => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: 'CAD'
    }).format(amount);
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

  const handleAcceptNegotiation = async () => {
    const result = await acceptNegotiation(bookingId, negotiation.id);
    
    if (result?.success) {
      // Vérifier si un compte Stripe a été créé
      if (result.stripe_account_created && result.stripe_account) {
        setStripeAccountData(result.stripe_account);
        setMotivationalMessage(result.motivational_message || '');
        setShowStripeModal(true);
      }
      
      if (onAccepted) {
        onAccepted();
      }
    }
  };

  return (
    <>
      <div className={`border rounded-lg p-4 ${
        negotiation.is_accepted 
          ? 'bg-green-50 border-green-200' 
          : 'bg-white border-gray-200'
      }`}>
        <div className="flex justify-between items-start mb-3">
          <div>
            <div className="flex items-center mb-1">
              <span className="font-semibold text-gray-800">
                {negotiation.first_name || 'Utilisateur'}
              </span>
              {negotiation.is_accepted && (
                <span className="ml-2 bg-green-100 text-green-800 text-xs font-medium px-2 py-1 rounded-full">
                  ✅ Acceptée
                </span>
              )}
            </div>
            <p className="text-sm text-gray-600">{negotiation.email}</p>
          </div>
          
          <div className="text-right">
            <div className="text-2xl font-bold text-blue-600">
              {formatAmount(negotiation.amount)}
            </div>
            <div className="text-xs text-gray-500">
              {formatDate(negotiation.created_at)}
            </div>
          </div>
        </div>

        {negotiation.message && (
          <div className="mb-3 p-3 bg-gray-50 rounded-lg">
            <p className="text-sm text-gray-700 italic">
              "{negotiation.message}"
            </p>
          </div>
        )}

        {canAccept && !negotiation.is_accepted && (
          <div className="flex justify-end">
            <button
              onClick={handleAcceptNegotiation}
              disabled={loading}
              className="bg-green-500 hover:bg-green-600 text-white font-medium py-2 px-4 rounded-lg transition duration-200 flex items-center disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent mr-2"></div>
                  Acceptation...
                </>
              ) : (
                <>
                  <span className="mr-1">✅</span>
                  Accepter cette offre
                </>
              )}
            </button>
          </div>
        )}
      </div>

      {/* Modal de configuration Stripe */}
      {showStripeModal && stripeAccountData && (
        <StripeAccountSetupModal
          isOpen={showStripeModal}
          onClose={() => setShowStripeModal(false)}
          stripeAccount={stripeAccountData}
          motivationalMessage={motivationalMessage}
        />
      )}
    </>
  );
}