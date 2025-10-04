'use client';

import React, { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import {
  CheckCircle,
  XCircle,
  Loader2,
  Lock,
  ArrowRight,
  RefreshCw,
  Luggage,
  Download
} from 'lucide-react';

interface ResetResult {
  success: boolean;
  message: string;
  error_code?: string;
}

function ResetPasswordContent() {
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<'loading' | 'form' | 'success' | 'error' | 'missing-token'>('loading');
  const [result, setResult] = useState<ResetResult | null>(null);
  const [isResetting, setIsResetting] = useState(false);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  
  const token = searchParams.get('token');
  
  useEffect(() => {
    if (!token) {
      setStatus('missing-token');
      return;
    }
    
    // Simulate token validation
    setTimeout(() => {
      setStatus('form');
    }, 1000);
  }, [token]);
  
  const resetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (password !== confirmPassword) {
      setResult({
        success: false,
        message: 'Les mots de passe ne correspondent pas.',
        error_code: 'PASSWORDS_DONT_MATCH'
      });
      setStatus('error');
      return;
    }
    
    if (password.length < 6) {
      setResult({
        success: false,
        message: 'Le mot de passe doit contenir au moins 6 caractères.',
        error_code: 'PASSWORD_TOO_SHORT'
      });
      setStatus('error');
      return;
    }
    
    try {
      setIsResetting(true);
      
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/reset-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token: token,
          password: password
        })
      });
      
      const data: ResetResult = await response.json();
      setResult(data);
      
      if (data.success) {
        setStatus('success');
      } else {
        setStatus('error');
      }
    } catch (error) {
      console.error('Erreur lors de la réinitialisation:', error);
      setResult({
        success: false,
        message: 'Erreur de connexion. Veuillez réessayer.',
        error_code: 'CONNECTION_ERROR'
      });
      setStatus('error');
    } finally {
      setIsResetting(false);
    }
  };
  
  const openMobileApp = () => {
    // Try to open the mobile app with a deep link
    const appScheme = 'kiloshare://login';
    
    // Create a hidden iframe to try the app scheme
    const iframe = document.createElement('iframe');
    iframe.style.display = 'none';
    iframe.src = appScheme;
    document.body.appendChild(iframe);
    
    // Fallback: show instructions after 2 seconds
    setTimeout(() => {
      alert('Si l\'app ne s\'ouvre pas automatiquement, lancez KiloShare manuellement et connectez-vous avec votre nouveau mot de passe.');
      document.body.removeChild(iframe);
    }, 2000);
  };

  const renderContent = () => {
    switch (status) {
      case 'loading':
        return (
          <div className="text-center">
            <div className="bg-blue-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
              <Loader2 className="h-10 w-10 text-primary animate-spin" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Validation du lien...
            </h2>
            <p className="text-gray-600">
              Nous vérifions votre lien de réinitialisation, veuillez patienter.
            </p>
          </div>
        );
        
      case 'form':
        return (
          <div className="text-center">
            <div className="bg-green-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
              <Lock className="h-10 w-10 text-green-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Nouveau mot de passe
            </h2>
            <p className="text-gray-600 mb-6">
              Choisissez un nouveau mot de passe sécurisé pour votre compte.
            </p>
            
            <form onSubmit={resetPassword} className="space-y-4">
              <div className="text-left">
                <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
                  Nouveau mot de passe
                </label>
                <input
                  type="password"
                  id="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={6}
                  placeholder="Au moins 6 caractères"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent transition-colors"
                />
              </div>
              
              <div className="text-left">
                <label htmlFor="confirmPassword" className="block text-sm font-medium text-gray-700 mb-2">
                  Confirmer le mot de passe
                </label>
                <input
                  type="password"
                  id="confirmPassword"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  placeholder="Répéter le mot de passe"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent transition-colors"
                />
              </div>
              
              <button
                type="submit"
                disabled={isResetting}
                className="hero-gradient text-white px-6 py-3 rounded-lg font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center space-x-2 w-full"
              >
                {isResetting ? (
                  <Loader2 className="h-5 w-5 animate-spin" />
                ) : (
                  <Lock className="h-5 w-5" />
                )}
                <span>
                  {isResetting ? 'Réinitialisation en cours...' : 'Réinitialiser le mot de passe'}
                </span>
              </button>
            </form>
          </div>
        );
        
      case 'success':
        return (
          <div className="text-center">
            <div className="bg-green-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
              <CheckCircle className="h-10 w-10 text-green-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Mot de passe réinitialisé !
            </h2>
            <p className="text-gray-600 mb-6">
              Félicitations ! Votre mot de passe a été mis à jour avec succès. 
              Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.
            </p>
            
            {/* Call to actions */}
            <div className="space-y-4">
              <button 
                onClick={openMobileApp}
                className="hero-gradient text-white px-6 py-3 rounded-full font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center space-x-2 w-full sm:w-auto mx-auto"
              >
                <Download className="h-5 w-5" />
                <span>Ouvrir l'application mobile</span>
              </button>
              
              <div className="text-sm text-gray-500">
                ou
              </div>
              
              <a 
                href="/"
                className="inline-flex items-center space-x-2 text-primary hover:text-secondary transition-colors"
              >
                <span>Retour à l'accueil</span>
                <ArrowRight className="h-4 w-4" />
              </a>
            </div>
          </div>
        );
        
      case 'error':
        return (
          <div className="text-center">
            <div className="bg-red-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
              <XCircle className="h-10 w-10 text-red-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Erreur de réinitialisation
            </h2>
            <p className="text-gray-600 mb-6">
              {result?.message || 'Une erreur est survenue lors de la réinitialisation de votre mot de passe.'}
            </p>
            
            <div className="space-y-4">
              {result?.error_code === 'INVALID_TOKEN' && (
                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                  <p className="text-sm text-yellow-800">
                    Le lien de réinitialisation a peut-être expiré ou été déjà utilisé.
                  </p>
                </div>
              )}
              
              <button
                onClick={() => {
                  setStatus('form');
                  setResult(null);
                  setPassword('');
                  setConfirmPassword('');
                }}
                className="bg-primary text-white px-6 py-3 rounded-full font-semibold hover:bg-secondary transition-colors flex items-center justify-center space-x-2 w-full sm:w-auto mx-auto"
              >
                <RefreshCw className="h-5 w-5" />
                <span>Réessayer</span>
              </button>
              
              <div className="text-sm text-gray-500">
                ou
              </div>
              
              <a 
                href="/"
                className="inline-flex items-center space-x-2 text-primary hover:text-secondary transition-colors"
              >
                <span>Retour à l'accueil</span>
                <ArrowRight className="h-4 w-4" />
              </a>
            </div>
          </div>
        );
        
      case 'missing-token':
        return (
          <div className="text-center">
            <div className="bg-yellow-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
              <XCircle className="h-10 w-10 text-yellow-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Lien de réinitialisation manquant
            </h2>
            <p className="text-gray-600 mb-6">
              Il semble que le lien de réinitialisation soit incomplet. 
              Veuillez utiliser le lien complet reçu dans votre email.
            </p>
            
            <div className="space-y-4">
              <a 
                href="/"
                className="inline-flex items-center space-x-2 text-primary hover:text-secondary transition-colors"
              >
                <span>Retour à l'accueil</span>
                <ArrowRight className="h-4 w-4" />
              </a>
            </div>
          </div>
        );
        
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl p-8 w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center space-x-2 mb-4">
            <Luggage className="h-8 w-8 text-primary" />
            <h1 className="text-2xl font-bold gradient-text">KiloShare</h1>
          </div>
          <h2 className="text-lg text-gray-600">Réinitialisation du mot de passe</h2>
        </div>
        
        {/* Content */}
        {renderContent()}
        
        {/* Footer */}
        <div className="mt-8 pt-6 border-t border-gray-200">
          <p className="text-xs text-gray-500 text-center">
            Besoin d'aide ? {' '}
            <a href="mailto:support@kiloshare.com" className="text-primary hover:underline">
              Contactez notre support
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
        <div className="bg-white rounded-lg shadow-xl p-8 w-full max-w-md">
          <div className="text-center mb-8">
            <div className="flex items-center justify-center space-x-2 mb-4">
              <Luggage className="h-8 w-8 text-primary" />
              <h1 className="text-2xl font-bold gradient-text">KiloShare</h1>
            </div>
            <h2 className="text-lg text-gray-600">Réinitialisation du mot de passe</h2>
          </div>

          <div className="text-center">
            <div className="bg-blue-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
              <Loader2 className="h-10 w-10 text-primary animate-spin" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Validation du lien...
            </h2>
            <p className="text-gray-600">
              Nous vérifions votre lien de réinitialisation, veuillez patienter.
            </p>
          </div>
        </div>
      </div>
    }>
      <ResetPasswordContent />
    </Suspense>
  );
}