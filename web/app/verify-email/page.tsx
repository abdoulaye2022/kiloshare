'use client';

import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { 
  CheckCircle, 
  XCircle, 
  Loader2, 
  Mail, 
  ArrowRight,
  RefreshCw,
  Luggage,
  Download
} from 'lucide-react';

interface VerificationResult {
  success: boolean;
  message: string;
  error_code?: string;
}

export default function VerifyEmailPage() {
  const searchParams = useSearchParams();
  const [status, setStatus] = useState<'loading' | 'success' | 'error' | 'missing-token'>('loading');
  const [result, setResult] = useState<VerificationResult | null>(null);
  const [isResending, setIsResending] = useState(false);
  
  const token = searchParams.get('token') || searchParams.get('code');
  
  useEffect(() => {
    if (!token) {
      setStatus('missing-token');
      return;
    }
    
    verifyEmail(token);
  }, [token]);
  
  const verifyEmail = async (verificationToken: string) => {
    try {
      setStatus('loading');
      
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/verify-email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          code: verificationToken
        })
      });
      
      const data: VerificationResult = await response.json();
      setResult(data);
      
      if (data.success) {
        setStatus('success');
      } else {
        setStatus('error');
      }
    } catch (error) {
      console.error('Erreur lors de la vérification:', error);
      setResult({
        success: false,
        message: 'Erreur de connexion. Veuillez réessayer.',
        error_code: 'CONNECTION_ERROR'
      });
      setStatus('error');
    }
  };
  
  const resendVerification = async () => {
    setIsResending(true);
    try {
      // Vous devrez implémenter cette fonction côté backend si nécessaire
      // Pour l'instant, on simule une action
      await new Promise(resolve => setTimeout(resolve, 2000));
      alert('Un nouveau lien de vérification a été envoyé !');
    } catch (error) {
      alert('Erreur lors de l\'envoi. Veuillez réessayer.');
    }
    setIsResending(false);
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
              Vérification en cours...
            </h2>
            <p className="text-gray-600">
              Nous vérifions votre adresse email, veuillez patienter.
            </p>
          </div>
        );
        
      case 'success':
        return (
          <div className="text-center">
            <div className="bg-green-100 p-4 rounded-full w-20 h-20 flex items-center justify-center mx-auto mb-6">
              <CheckCircle className="h-10 w-10 text-green-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Email vérifié avec succès !
            </h2>
            <p className="text-gray-600 mb-6">
              Félicitations ! Votre adresse email a été vérifiée. 
              Vous pouvez maintenant utiliser toutes les fonctionnalités de KiloShare.
            </p>
            
            {/* Call to actions */}
            <div className="space-y-4">
              <button className="hero-gradient text-white px-6 py-3 rounded-full font-semibold hover:shadow-lg transform hover:scale-105 transition-all duration-200 flex items-center justify-center space-x-2 w-full sm:w-auto mx-auto">
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
              Erreur de vérification
            </h2>
            <p className="text-gray-600 mb-6">
              {result?.message || 'Une erreur est survenue lors de la vérification de votre email.'}
            </p>
            
            <div className="space-y-4">
              {result?.error_code === 'EMAIL_VERIFICATION_FAILED' && (
                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                  <p className="text-sm text-yellow-800">
                    Le lien de vérification a peut-être expiré ou été déjà utilisé.
                  </p>
                </div>
              )}
              
              <button
                onClick={resendVerification}
                disabled={isResending}
                className="bg-primary text-white px-6 py-3 rounded-full font-semibold hover:bg-secondary transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2 w-full sm:w-auto mx-auto"
              >
                {isResending ? (
                  <Loader2 className="h-5 w-5 animate-spin" />
                ) : (
                  <RefreshCw className="h-5 w-5" />
                )}
                <span>
                  {isResending ? 'Envoi en cours...' : 'Renvoyer le lien de vérification'}
                </span>
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
              <Mail className="h-10 w-10 text-yellow-600" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-4">
              Lien de vérification manquant
            </h2>
            <p className="text-gray-600 mb-6">
              Il semble que le lien de vérification soit incomplet. 
              Veuillez utiliser le lien complet reçu dans votre email.
            </p>
            
            <div className="space-y-4">
              <button
                onClick={resendVerification}
                disabled={isResending}
                className="bg-primary text-white px-6 py-3 rounded-full font-semibold hover:bg-secondary transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2 w-full sm:w-auto mx-auto"
              >
                {isResending ? (
                  <Loader2 className="h-5 w-5 animate-spin" />
                ) : (
                  <Mail className="h-5 w-5" />
                )}
                <span>
                  {isResending ? 'Envoi en cours...' : 'Recevoir un nouveau lien'}
                </span>
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
          <h2 className="text-lg text-gray-600">Vérification d'email</h2>
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