'use client';

import React from 'react';

interface StripeAccountSetupModalProps {
  isOpen: boolean;
  onClose: () => void;
  stripeAccount: {
    onboarding_url: string;
    expected_amount: number;
  };
  motivationalMessage: string;
}

export default function StripeAccountSetupModal({
  isOpen,
  onClose,
  stripeAccount,
  motivationalMessage
}: StripeAccountSetupModalProps) {
  
  if (!isOpen) return null;

  const handleSetupAccount = () => {
    window.open(stripeAccount.onboarding_url, '_blank');
  };

  const formatAmount = (amount: number) => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: 'CAD'
    }).format(amount);
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-md w-full p-6 shadow-2xl">
        {/* Header avec emoji de félicitations */}
        <div className="text-center mb-6">
          <div className="text-6xl mb-4">🎉</div>
          <h2 className="text-2xl font-bold text-gray-800 mb-2">
            Félicitations !
          </h2>
          <p className="text-lg text-gray-600">
            Votre négociation a été acceptée !
          </p>
        </div>

        {/* Message de motivation */}
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
          <div className="flex items-start">
            <div className="text-2xl mr-3 mt-1">💰</div>
            <div>
              <h3 className="font-semibold text-green-800 mb-1">
                Prêt à recevoir votre paiement ?
              </h3>
              <p className="text-green-700 text-sm leading-relaxed">
                Pour recevoir votre paiement de{' '}
                <span className="font-bold">
                  {formatAmount(stripeAccount.expected_amount)}
                </span>
                , vous devez configurer votre compte de paiement.
              </p>
            </div>
          </div>
        </div>

        {/* Avantages rapides */}
        <div className="space-y-3 mb-6">
          <div className="flex items-center text-sm text-gray-600">
            <div className="text-green-500 text-lg mr-3">⚡</div>
            <span>Configuration en 2 minutes seulement</span>
          </div>
          <div className="flex items-center text-sm text-gray-600">
            <div className="text-blue-500 text-lg mr-3">🔒</div>
            <span>Sécurisé et conforme aux normes bancaires</span>
          </div>
          <div className="flex items-center text-sm text-gray-600">
            <div className="text-purple-500 text-lg mr-3">📱</div>
            <span>Recevez vos paiements directement sur votre compte</span>
          </div>
        </div>

        {/* Boutons d'action */}
        <div className="flex flex-col space-y-3">
          <button
            onClick={handleSetupAccount}
            className="bg-gradient-to-r from-blue-500 to-blue-600 text-white font-semibold py-3 px-6 rounded-lg hover:from-blue-600 hover:to-blue-700 transition duration-200 flex items-center justify-center"
          >
            <span className="mr-2">🚀</span>
            Configurer mon compte (2 min)
          </button>
          
          <button
            onClick={onClose}
            className="text-gray-500 text-sm underline hover:text-gray-700 transition duration-200"
          >
            Je le ferai plus tard
          </button>
        </div>

        {/* Note en bas */}
        <div className="mt-4 p-3 bg-gray-50 rounded-lg">
          <p className="text-xs text-gray-500 text-center leading-relaxed">
            💡 <strong>Conseil :</strong> Configurez votre compte maintenant pour recevoir vos paiements sans délai. 
            Vous pouvez fermer cette fenêtre et revenir à votre configuration plus tard.
          </p>
        </div>
      </div>
    </div>
  );
}