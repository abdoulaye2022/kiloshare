'use client';

import React, { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import 'bootstrap/dist/css/bootstrap.min.css';
import 'bootstrap-icons/font/bootstrap-icons.css';

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
            <div className="bg-primary bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <div className="spinner-border text-primary" role="status" style={{ width: '40px', height: '40px' }}>
                <span className="visually-hidden">Chargement...</span>
              </div>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Validation du lien...
            </h2>
            <p className="text-muted">
              Nous vérifions votre lien de réinitialisation, veuillez patienter.
            </p>
          </div>
        );

      case 'form':
        return (
          <div className="text-center">
            <div className="bg-success bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <i className="bi bi-lock-fill text-success" style={{ fontSize: '40px' }}></i>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Nouveau mot de passe
            </h2>
            <p className="text-muted mb-4">
              Choisissez un nouveau mot de passe sécurisé pour votre compte.
            </p>

            <form onSubmit={resetPassword} className="text-start">
              <div className="mb-3">
                <label htmlFor="password" className="form-label">
                  Nouveau mot de passe
                </label>
                <input
                  type="password"
                  id="password"
                  className="form-control form-control-lg"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={6}
                  placeholder="Au moins 6 caractères"
                />
              </div>

              <div className="mb-4">
                <label htmlFor="confirmPassword" className="form-label">
                  Confirmer le mot de passe
                </label>
                <input
                  type="password"
                  id="confirmPassword"
                  className="form-control form-control-lg"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  placeholder="Répéter le mot de passe"
                />
              </div>

              <button
                type="submit"
                disabled={isResetting}
                className="btn btn-primary btn-lg w-100 d-flex align-items-center justify-content-center gap-2"
              >
                {isResetting ? (
                  <div className="spinner-border spinner-border-sm" role="status">
                    <span className="visually-hidden">Chargement...</span>
                  </div>
                ) : (
                  <i className="bi bi-lock"></i>
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
            <div className="bg-success bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <i className="bi bi-check-circle-fill text-success" style={{ fontSize: '40px' }}></i>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Mot de passe réinitialisé !
            </h2>
            <p className="text-muted mb-4">
              Félicitations ! Votre mot de passe a été mis à jour avec succès.
              Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.
            </p>

            <div className="d-flex flex-column gap-3 align-items-center">
              <button
                onClick={openMobileApp}
                className="btn btn-primary btn-lg rounded-pill px-4 d-inline-flex align-items-center gap-2"
              >
                <i className="bi bi-download"></i>
                <span>Ouvrir l'application mobile</span>
              </button>

              <div className="text-muted small">ou</div>

              <a
                href="/"
                className="text-decoration-none text-primary d-inline-flex align-items-center gap-2"
              >
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
              Erreur de réinitialisation
            </h2>
            <p className="text-muted mb-4">
              {result?.message || 'Une erreur est survenue lors de la réinitialisation de votre mot de passe.'}
            </p>

            {result?.error_code === 'INVALID_TOKEN' && (
              <div className="alert alert-warning mb-4" role="alert">
                <i className="bi bi-exclamation-triangle-fill me-2"></i>
                Le lien de réinitialisation a peut-être expiré ou été déjà utilisé.
              </div>
            )}

            <div className="d-flex flex-column gap-3 align-items-center">
              <button
                onClick={() => {
                  setStatus('form');
                  setResult(null);
                  setPassword('');
                  setConfirmPassword('');
                }}
                className="btn btn-primary btn-lg rounded-pill px-4 d-inline-flex align-items-center gap-2"
              >
                <i className="bi bi-arrow-clockwise"></i>
                <span>Réessayer</span>
              </button>

              <div className="text-muted small">ou</div>

              <a
                href="/"
                className="text-decoration-none text-primary d-inline-flex align-items-center gap-2"
              >
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
              <i className="bi bi-x-circle-fill text-warning" style={{ fontSize: '40px' }}></i>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Lien de réinitialisation manquant
            </h2>
            <p className="text-muted mb-4">
              Il semble que le lien de réinitialisation soit incomplet.
              Veuillez utiliser le lien complet reçu dans votre email.
            </p>

            <div className="d-flex flex-column gap-3 align-items-center">
              <a
                href="/"
                className="text-decoration-none text-primary d-inline-flex align-items-center gap-2"
              >
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
          <h2 className="h5 text-muted">Réinitialisation du mot de passe</h2>
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

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={
      <div className="min-vh-100 d-flex align-items-center justify-content-center p-4 bg-white">
        <div className="bg-white rounded-4 shadow-lg p-5 w-100" style={{ maxWidth: '500px' }}>
          <div className="text-center mb-5">
            <div className="d-flex align-items-center justify-content-center gap-2 mb-3">
              <i className="bi bi-luggage text-primary" style={{ fontSize: '32px' }}></i>
              <h1 className="h3 fw-bold mb-0 text-primary">KiloShare</h1>
            </div>
            <h2 className="h5 text-muted">Réinitialisation du mot de passe</h2>
          </div>

          <div className="text-center">
            <div className="bg-primary bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-4" style={{ width: '80px', height: '80px' }}>
              <div className="spinner-border text-primary" role="status" style={{ width: '40px', height: '40px' }}>
                <span className="visually-hidden">Chargement...</span>
              </div>
            </div>
            <h2 className="h3 fw-bold text-dark mb-3">
              Validation du lien...
            </h2>
            <p className="text-muted">
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
