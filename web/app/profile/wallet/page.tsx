'use client'

import React, { useEffect, useState, Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { CheckCircle, AlertCircle, Smartphone } from 'lucide-react';

function WalletContent() {
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');
  const searchParams = useSearchParams();
  const router = useRouter();

  useEffect(() => {
    const success = searchParams.get('success');
    
    if (success === 'true') {
      setStatus('success');
    } else {
      setStatus('error');
    }
  }, [searchParams]);

  const handleOpenMobileApp = () => {
    // Tentative d'ouverture de l'app mobile avec deep link
    // Remplacez 'kiloshare' par votre schéma d'URL personnalisé si vous en avez un
    window.location.href = 'kiloshare://wallet?refresh=true';
    
    // Fallback après 3 secondes si l'app ne s'ouvre pas
    setTimeout(() => {
      alert('Si l\'application KiloShare ne s\'est pas ouverte automatiquement, veuillez l\'ouvrir manuellement et aller dans votre portefeuille.');
    }, 3000);
  };

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-6">
        {status === 'loading' && (
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Chargement...</h2>
            <p className="text-gray-600">Vérification du statut de votre configuration Stripe</p>
          </div>
        )}

        {status === 'success' && (
          <div className="text-center">
            <CheckCircle className="h-16 w-16 text-green-500 mx-auto mb-4" />
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Configuration réussie !</h2>
            <p className="text-gray-600 mb-6">
              Votre compte Stripe a été configuré avec succès. Vous pouvez maintenant continuer dans l'application mobile.
            </p>
            
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <div className="flex items-start">
                <Smartphone className="h-5 w-5 text-blue-500 mt-0.5 mr-3 flex-shrink-0" />
                <div className="text-left">
                  <h3 className="font-medium text-blue-900 mb-1">Étapes suivantes</h3>
                  <p className="text-sm text-blue-700">
                    Si une vérification d'identité est requise, vous pouvez la compléter directement depuis l'application mobile en allant dans votre portefeuille.
                  </p>
                </div>
              </div>
            </div>

            <button
              onClick={handleOpenMobileApp}
              className="w-full bg-blue-600 text-white px-4 py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors duration-200 flex items-center justify-center"
            >
              <Smartphone className="h-5 w-5 mr-2" />
              Ouvrir l'application KiloShare
            </button>

            <p className="text-xs text-gray-500 mt-4">
              Si le bouton ne fonctionne pas, ouvrez manuellement l'application et allez dans votre portefeuille.
            </p>
          </div>
        )}

        {status === 'error' && (
          <div className="text-center">
            <AlertCircle className="h-16 w-16 text-red-500 mx-auto mb-4" />
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Erreur de configuration</h2>
            <p className="text-gray-600 mb-6">
              Il semble y avoir eu un problème avec votre configuration Stripe. Veuillez réessayer depuis l'application mobile.
            </p>
            
            <button
              onClick={handleOpenMobileApp}
              className="w-full bg-gray-600 text-white px-4 py-3 rounded-lg font-medium hover:bg-gray-700 transition-colors duration-200 flex items-center justify-center"
            >
              <Smartphone className="h-5 w-5 mr-2" />
              Retourner à l'application
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

export default function WalletPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-6">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Chargement...</h2>
            <p className="text-gray-600">Vérification du statut de votre configuration Stripe</p>
          </div>
        </div>
      </div>
    }>
      <WalletContent />
    </Suspense>
  );
}