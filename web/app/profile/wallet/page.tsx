'use client'

import React, { useEffect, useState, Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { CheckCircle, AlertCircle, Smartphone, Wallet, ArrowRight, RefreshCw } from 'lucide-react';

function WalletContent() {
  const [status, setStatus] = useState<'loading' | 'success' | 'error' | 'refresh'>('loading');
  const searchParams = useSearchParams();
  const router = useRouter();

  useEffect(() => {
    const success = searchParams.get('success');
    const refresh = searchParams.get('refresh');

    if (success === 'true') {
      setStatus('success');
    } else if (refresh === 'true') {
      setStatus('refresh');
    } else {
      setStatus('loading');
    }
  }, [searchParams]);

  const handleOpenMobileApp = () => {
    // Tentative d'ouverture de l'app mobile avec deep link
    // Le schéma kiloshare:// ouvre l'application mobile KiloShare
    window.location.href = 'kiloshare://profile/wallet';

    // Fallback après 2.5 secondes si l'app ne s'ouvre pas
    setTimeout(() => {
      // Show a styled notification instead of alert
      const notification = document.createElement('div');
      notification.className = 'fixed top-4 left-1/2 transform -translate-x-1/2 bg-white shadow-lg rounded-lg p-4 max-w-md z-50 border-l-4 border-blue-500 animate-slide-down';
      notification.innerHTML = `
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm font-medium text-gray-900">Application non détectée</p>
            <p class="mt-1 text-sm text-gray-600">Veuillez ouvrir manuellement l'application KiloShare et aller dans votre portefeuille.</p>
          </div>
        </div>
      `;
      document.body.appendChild(notification);
      setTimeout(() => notification.remove(), 5000);
    }, 2500);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50 flex items-center justify-center p-4">
      {/* Logo KiloShare en haut */}
      <div className="absolute top-8 left-1/2 transform -translate-x-1/2">
        <div className="flex items-center space-x-2">
          <Wallet className="h-8 w-8 text-blue-600" />
          <span className="text-2xl font-bold text-gray-900">KiloShare</span>
        </div>
      </div>

      <div className="max-w-lg w-full">
        {status === 'loading' && (
          <div className="bg-white rounded-2xl shadow-2xl p-8 text-center">
            <div className="relative">
              <div className="animate-spin rounded-full h-16 w-16 border-4 border-blue-200 border-t-blue-600 mx-auto mb-6"></div>
              <Wallet className="h-6 w-6 text-blue-600 absolute top-5 left-1/2 transform -translate-x-1/2" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-3">Chargement...</h2>
            <p className="text-gray-600">Vérification du statut de votre configuration Stripe</p>
          </div>
        )}

        {status === 'success' && (
          <div className="bg-white rounded-2xl shadow-2xl p-8">
            <div className="text-center mb-6">
              <div className="inline-flex items-center justify-center w-20 h-20 bg-green-100 rounded-full mb-4">
                <CheckCircle className="h-12 w-12 text-green-600" />
              </div>
              <h2 className="text-3xl font-bold text-gray-900 mb-3">Configuration réussie !</h2>
              <p className="text-lg text-gray-600">
                Votre compte Stripe a été configuré avec succès.
              </p>
            </div>

            <div className="bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-xl p-5 mb-6">
              <div className="flex items-start">
                <div className="flex-shrink-0 bg-blue-100 rounded-lg p-2">
                  <Smartphone className="h-6 w-6 text-blue-600" />
                </div>
                <div className="ml-4 flex-1">
                  <h3 className="font-semibold text-gray-900 mb-2">Prochaines étapes</h3>
                  <ul className="space-y-2 text-sm text-gray-700">
                    <li className="flex items-start">
                      <ArrowRight className="h-4 w-4 text-blue-500 mr-2 mt-0.5 flex-shrink-0" />
                      <span>Retournez dans l'application mobile</span>
                    </li>
                    <li className="flex items-start">
                      <ArrowRight className="h-4 w-4 text-blue-500 mr-2 mt-0.5 flex-shrink-0" />
                      <span>Accédez à votre portefeuille pour voir le statut</span>
                    </li>
                    <li className="flex items-start">
                      <ArrowRight className="h-4 w-4 text-blue-500 mr-2 mt-0.5 flex-shrink-0" />
                      <span>Complétez la vérification d'identité si nécessaire</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            <button
              onClick={handleOpenMobileApp}
              className="w-full bg-gradient-to-r from-blue-600 to-blue-700 text-white px-6 py-4 rounded-xl font-semibold hover:from-blue-700 hover:to-blue-800 transition-all duration-200 flex items-center justify-center shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
            >
              <Smartphone className="h-5 w-5 mr-2" />
              Ouvrir l'application KiloShare
            </button>

            <p className="text-xs text-gray-500 mt-4 text-center">
              Le bouton ouvrira automatiquement votre application mobile
            </p>
          </div>
        )}

        {status === 'refresh' && (
          <div className="bg-white rounded-2xl shadow-2xl p-8">
            <div className="text-center mb-6">
              <div className="inline-flex items-center justify-center w-20 h-20 bg-orange-100 rounded-full mb-4">
                <RefreshCw className="h-12 w-12 text-orange-600" />
              </div>
              <h2 className="text-3xl font-bold text-gray-900 mb-3">Actualisation nécessaire</h2>
              <p className="text-lg text-gray-600">
                Veuillez retourner dans l'application pour continuer la configuration.
              </p>
            </div>

            <div className="bg-orange-50 border border-orange-200 rounded-xl p-5 mb-6">
              <div className="flex items-start">
                <div className="flex-shrink-0 bg-orange-100 rounded-lg p-2">
                  <AlertCircle className="h-6 w-6 text-orange-600" />
                </div>
                <div className="ml-4 flex-1">
                  <h3 className="font-semibold text-gray-900 mb-2">Information</h3>
                  <p className="text-sm text-gray-700">
                    La configuration de votre compte Stripe nécessite des informations supplémentaires. Retournez dans l'application pour continuer.
                  </p>
                </div>
              </div>
            </div>

            <button
              onClick={handleOpenMobileApp}
              className="w-full bg-gradient-to-r from-orange-600 to-orange-700 text-white px-6 py-4 rounded-xl font-semibold hover:from-orange-700 hover:to-orange-800 transition-all duration-200 flex items-center justify-center shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
            >
              <Smartphone className="h-5 w-5 mr-2" />
              Retourner à l'application
            </button>
          </div>
        )}

        {status === 'error' && (
          <div className="bg-white rounded-2xl shadow-2xl p-8">
            <div className="text-center mb-6">
              <div className="inline-flex items-center justify-center w-20 h-20 bg-red-100 rounded-full mb-4">
                <AlertCircle className="h-12 w-12 text-red-600" />
              </div>
              <h2 className="text-3xl font-bold text-gray-900 mb-3">Erreur de configuration</h2>
              <p className="text-lg text-gray-600">
                Un problème est survenu lors de la configuration de votre compte Stripe.
              </p>
            </div>

            <div className="bg-red-50 border border-red-200 rounded-xl p-5 mb-6">
              <div className="flex items-start">
                <div className="flex-shrink-0 bg-red-100 rounded-lg p-2">
                  <AlertCircle className="h-6 w-6 text-red-600" />
                </div>
                <div className="ml-4 flex-1">
                  <h3 className="font-semibold text-gray-900 mb-2">Que faire ?</h3>
                  <p className="text-sm text-gray-700 mb-3">
                    Retournez dans l'application mobile et réessayez la configuration depuis votre portefeuille.
                  </p>
                  <p className="text-xs text-gray-600">
                    Si le problème persiste, contactez notre support.
                  </p>
                </div>
              </div>
            </div>

            <button
              onClick={handleOpenMobileApp}
              className="w-full bg-gradient-to-r from-gray-700 to-gray-800 text-white px-6 py-4 rounded-xl font-semibold hover:from-gray-800 hover:to-gray-900 transition-all duration-200 flex items-center justify-center shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
            >
              <Smartphone className="h-5 w-5 mr-2" />
              Retourner à l'application
            </button>
          </div>
        )}

        {/* Footer */}
        <p className="text-center text-gray-500 text-sm mt-6">
          © 2025 KiloShare. Tous droits réservés.
        </p>
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