'use client';

import React, { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import 'bootstrap/dist/css/bootstrap.min.css';
import 'bootstrap-icons/font/bootstrap-icons.css';

interface VerificationResult {
  success: boolean;
  message: string;
  error_code?: string;
}

function VerifyEmailContent() {
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
            <div className="bg-primary bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <div className="spinner-border text-primary" role="status" style={{ width: '40px', height: '40px' }}>
                <span className="visually-hidden">Chargement...</span>
              </div>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Vérification en cours...
            </h2>
            <p className="text-muted">
              Nous vérifions votre adresse email, veuillez patienter.
            </p>
          </div>
        );
        
      case 'success':
        return (
          <div className="text-center">
            <div className="bg-success bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <i className="bi bi-check-circle-fill text-success" style={{ fontSize: '40px' }}></i>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Email vérifié avec succès !
            </h2>
            <p className="text-muted mb-4">
              Félicitations ! Votre adresse email a été vérifiée.
              Vous pouvez maintenant utiliser toutes les fonctionnalités de KiloShare.
            </p>

            <div className="d-flex flex-column gap-3 align-items-center">
              <button className="btn btn-primary btn-lg rounded-pill px-4 d-inline-flex align-items-center gap-2">
                <i className="bi bi-download"></i>
                <span>Ouvrir l'application mobile</span>
              </button>

              <div className="text-muted small">ou</div>

              <a href="/" className="text-decoration-none text-primary d-inline-flex align-items-center gap-2">
                <span>Retour à l'accueil</span>
                <i className="bi bi-arrow-right"></i>
              </a>
            </div>
          </div>
        );
        
      case 'error':
        return (
          <div className="text-center">
            <div className="bg-danger bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <i className="bi bi-x-circle-fill text-danger" style={{ fontSize: '40px' }}></i>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Erreur de vérification
            </h2>
            <p className="text-muted mb-4">
              {result?.message || 'Une erreur est survenue lors de la vérification de votre email.'}
            </p>

            {result?.error_code === 'EMAIL_VERIFICATION_FAILED' && (
              <div className="alert alert-warning mb-4" role="alert">
                <i className="bi bi-exclamation-triangle-fill me-2"></i>
                Le lien de vérification a peut-être expiré ou été déjà utilisé.
              </div>
            )}

            <div className="d-flex flex-column gap-3 align-items-center">
              <button
                onClick={resendVerification}
                disabled={isResending}
                className="btn btn-primary btn-lg rounded-pill px-4 d-inline-flex align-items-center gap-2"
              >
                {isResending ? (
                  <div className="spinner-border spinner-border-sm" role="status">
                    <span className="visually-hidden">Chargement...</span>
                  </div>
                ) : (
                  <i className="bi bi-arrow-clockwise"></i>
                )}
                <span>
                  {isResending ? 'Envoi en cours...' : 'Renvoyer le lien de vérification'}
                </span>
              </button>

              <div className="text-muted small">ou</div>

              <a href="/" className="text-decoration-none text-primary d-inline-flex align-items-center gap-2">
                <span>Retour à l'accueil</span>
                <i className="bi bi-arrow-right"></i>
              </a>
            </div>
          </div>
        );
        
      case 'missing-token':
        return (
          <div className="text-center">
            <div className="bg-warning bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <i className="bi bi-envelope-fill text-warning" style={{ fontSize: '40px' }}></i>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Lien de vérification manquant
            </h2>
            <p className="text-muted mb-4">
              Il semble que le lien de vérification soit incomplet.
              Veuillez utiliser le lien complet reçu dans votre email.
            </p>

            <div className="d-flex flex-column gap-3 align-items-center">
              <button
                onClick={resendVerification}
                disabled={isResending}
                className="btn btn-primary btn-lg rounded-pill px-4 d-inline-flex align-items-center gap-2"
              >
                {isResending ? (
                  <div className="spinner-border spinner-border-sm" role="status">
                    <span className="visually-hidden">Chargement...</span>
                  </div>
                ) : (
                  <i className="bi bi-envelope"></i>
                )}
                <span>
                  {isResending ? 'Envoi en cours...' : 'Recevoir un nouveau lien'}
                </span>
              </button>

              <div className="text-muted small">ou</div>

              <a href="/" className="text-decoration-none text-primary d-inline-flex align-items-center gap-2">
                <span>Retour à l'accueil</span>
                <i className="bi bi-arrow-right"></i>
              </a>
            </div>
          </div>
        );
        
      default:
        return null;
    }
  };

  return (
    <div className="min-vh-100 d-flex align-items-center justify-content-center p-4 bg-white">
      <div className="bg-white rounded-4 shadow-lg p-5 w-100" style={{ maxWidth: '500px' }}>
        {/* Header */}
        <div className="text-center mb-5">
          <div className="d-flex align-items-center justify-content-center gap-2 mb-3">
            <i className="bi bi-luggage text-primary" style={{ fontSize: '32px' }}></i>
            <h1 className="h3 fw-bold mb-0 text-primary">KiloShare</h1>
          </div>
          <h2 className="h5 text-muted">Vérification d'email</h2>
        </div>

        {/* Content */}
        {renderContent()}

        {/* Footer */}
        <div className="mt-5 pt-4 border-top">
          <p className="text-center text-muted small mb-0">
            Besoin d'aide ?{' '}
            <a href="mailto:support@kiloshare.com" className="text-primary text-decoration-none">
              Contactez notre support
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}

export default function VerifyEmailPage() {
  return (
    <Suspense fallback={
      <div className="min-vh-100 d-flex align-items-center justify-content-center p-4 bg-white">
        <div className="bg-white rounded-4 shadow-lg p-5 w-100" style={{ maxWidth: '500px' }}>
          <div className="text-center mb-5">
            <div className="d-flex align-items-center justify-content-center gap-2 mb-3">
              <i className="bi bi-luggage text-primary" style={{ fontSize: '32px' }}></i>
              <h1 className="h3 fw-bold mb-0 text-primary">KiloShare</h1>
            </div>
            <h2 className="h5 text-muted">Vérification d'email</h2>
          </div>

          <div className="text-center">
            <div className="bg-primary bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <div className="spinner-border text-primary" role="status" style={{ width: '40px', height: '40px' }}>
                <span className="visually-hidden">Chargement...</span>
              </div>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Vérification en cours...
            </h2>
            <p className="text-muted">
              Nous vérifions votre adresse email, veuillez patienter.
            </p>
          </div>
        </div>
      </div>
    }>
      <VerifyEmailContent />
    </Suspense>
  );
}