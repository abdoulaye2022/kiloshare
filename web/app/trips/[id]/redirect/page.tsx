'use client';

import { useParams, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

export default function TripRedirectPage() {
  const params = useParams();
  const router = useRouter();
  const tripId = params.id;
  const [countdown, setCountdown] = useState(3);
  const [appOpened, setAppOpened] = useState(false);

  useEffect(() => {
    const attemptAppOpen = () => {
      // Détecter le système d'exploitation
      const userAgent = navigator.userAgent || navigator.vendor;
      const isAndroid = /android/i.test(userAgent);
      const isIOS = /iPad|iPhone|iPod/.test(userAgent);

      // Deep link personnalisé pour chaque plateforme
      const deepLink = `kiloshare://trips/${tripId}`;

      // Tenter d'ouvrir l'app
      if (isIOS) {
        // Sur iOS, essayer directement le custom scheme
        // (Universal Link uniquement en production)
        window.location.href = deepLink;
      } else if (isAndroid) {
        // Sur Android, utiliser l'intent d'abord
        const intentUrl = `intent://trips/${tripId}#Intent;scheme=kiloshare;package=com.m2atech.kiloshare;end`;
        window.location.href = intentUrl;

        // Fallback au custom scheme
        setTimeout(() => {
          if (!appOpened) {
            window.location.href = deepLink;
          }
        }, 500);
      } else {
        // Desktop ou autre - essayer le custom scheme
        window.location.href = deepLink;
      }

      // Écouter si l'utilisateur revient (l'app ne s'est pas ouverte)
      const handleVisibilityChange = () => {
        if (document.hidden) {
          setAppOpened(true);
        }
      };

      const handleBlur = () => {
        setAppOpened(true);
      };

      document.addEventListener('visibilitychange', handleVisibilityChange);
      window.addEventListener('blur', handleBlur);

      return () => {
        document.removeEventListener('visibilitychange', handleVisibilityChange);
        window.removeEventListener('blur', handleBlur);
      };
    };

    const cleanup = attemptAppOpen();

    // Démarrer le compte à rebours
    const countdownInterval = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(countdownInterval);
          // Rediriger vers la page web après 3 secondes si l'app ne s'est pas ouverte
          if (!appOpened) {
            router.push(`/trips/${tripId}`);
          }
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    // Nettoyer l'intervalle au démontage
    return () => {
      clearInterval(countdownInterval);
      cleanup?.();
    };
  }, [tripId, router, appOpened]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-blue-100">
      <div className="max-w-md w-full mx-4">
        <div className="bg-white rounded-2xl shadow-xl p-8 text-center">
          {/* Logo/Icône */}
          <div className="w-20 h-20 bg-blue-600 rounded-full flex items-center justify-center mx-auto mb-6">
            <span className="text-4xl">🧳</span>
          </div>

          {/* Titre */}
          <h1 className="text-2xl font-bold text-gray-900 mb-4">
            Ouverture de KiloShare
          </h1>

          {/* Message */}
          <p className="text-gray-600 mb-6">
            Tentative d'ouverture de l'application...
          </p>

          {/* Spinner */}
          <div className="flex justify-center mb-6">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>

          {/* Compte à rebours */}
          <p className="text-sm text-gray-500 mb-6">
            Redirection vers le site web dans {countdown} seconde{countdown > 1 ? 's' : ''}...
          </p>

          {/* Boutons d'action */}
          <div className="space-y-3">
            <button
              onClick={() => router.push(`/trips/${tripId}`)}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-3 px-4 rounded-lg transition-colors"
            >
              Ouvrir sur le site web
            </button>

            <p className="text-xs text-gray-500">
              L'application ne s'ouvre pas? Cliquez sur le bouton ci-dessus.
            </p>
          </div>
        </div>

        {/* Instructions */}
        <div className="mt-6 text-center">
          <p className="text-sm text-gray-600">
            Vous n'avez pas l'application?
          </p>
          <div className="flex justify-center space-x-4 mt-3">
            <a
              href="https://play.google.com/store/apps/details?id=com.m2atech.kiloshare"
              className="text-blue-600 hover:text-blue-700 text-sm font-medium"
              target="_blank"
              rel="noopener noreferrer"
            >
              Google Play
            </a>
            <span className="text-gray-400">•</span>
            <a
              href="https://apps.apple.com/app/kiloshare/id123456789"
              className="text-blue-600 hover:text-blue-700 text-sm font-medium"
              target="_blank"
              rel="noopener noreferrer"
            >
              App Store
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
