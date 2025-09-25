'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAdminAuthStore } from '../../../stores/adminAuthStore';
import { useClientOnly } from '../../../hooks/useClientOnly';
import { AUTH_ENDPOINTS, getDefaultHeaders } from '../../../lib/api-config';

export default function AdminLogin() {
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();
  const mounted = useClientOnly(100); // Wait 100ms after hydration

  const { login, isAuthenticated } = useAdminAuthStore();
  const [localLoading, setLocalLoading] = useState(false);

  useEffect(() => {
    // Only run after hydration
    if (!mounted) return;
    
    
    // Simple redirect if authenticated
    if (isAuthenticated) {
      setLocalLoading(false);
      router.replace('/admin/dashboard');
    }
  }, [isAuthenticated, router, mounted]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLocalLoading(true);
    setError('');

    try {
      const response = await fetch(AUTH_ENDPOINTS.ADMIN_LOGIN, {
        method: 'POST',
        headers: getDefaultHeaders(),
        body: JSON.stringify(formData)
      });

      const data = await response.json();

      if (response.ok && data.success && data.data?.tokens?.access_token && data.data?.user) {
        
        // Use Zustand store for login with refresh token
        const result = login(data.data.tokens.access_token, data.data.user, data.data.tokens.refresh_token);
        
        // Also manually set in storage as backup
        try {
          localStorage.setItem('admin_token', data.data.tokens.access_token);
          sessionStorage.setItem('admin_token', data.data.tokens.access_token);
          if (data.data.tokens.refresh_token) {
            localStorage.setItem('admin_refresh_token', data.data.tokens.refresh_token);
            sessionStorage.setItem('admin_refresh_token', data.data.tokens.refresh_token);
          }
        } catch (err) {
          console.error('Manual storage failed:', err);
        }
        
        // Redirection will be handled by useEffect when isAuthenticated changes
      } else {
        setError(data.error || data.message || 'Identifiants invalides');
        setLocalLoading(false);
      }
    } catch (err) {
      console.error('Login error:', err);
      setError('Erreur de connexion. Veuillez réessayer.');
      setLocalLoading(false);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };


  return (
    <div className="min-vh-100 bg-light d-flex align-items-center justify-content-center">
      <div className="container">
        <div className="row justify-content-center">
          <div className="col-md-6 col-lg-4">
            {/* Header */}
            <div className="text-center mb-4">
              <div className="d-flex justify-content-center align-items-center mb-3">
                <i className="bi bi-shield-check fs-1 text-primary me-2"></i>
                <div>
                  <h1 className="h2 fw-bold text-dark mb-0">KiloShare</h1>
                  <p className="text-primary small fw-medium mb-0">Administration</p>
                </div>
              </div>
              <h2 className="h4 fw-bold text-secondary">Connexion Admin</h2>
              <p className="text-muted">Connectez-vous à votre espace d'administration</p>
            </div>

            {/* Login Form */}
            <div className="card shadow">
              <div className="card-body p-4">
                <form onSubmit={handleSubmit}>
                  {/* Email Field */}
                  <div className="mb-3">
                    <label htmlFor="email" className="form-label fw-medium">
                      Email
                    </label>
                    <div className="input-group">
                      <span className="input-group-text">
                        <i className="bi bi-envelope text-muted"></i>
                      </span>
                      <input
                        type="email"
                        id="email"
                        name="email"
                        className="form-control"
                        value={formData.email}
                        onChange={handleInputChange}
                        required
                        placeholder="admin@kiloshare.com"
                      />
                    </div>
                  </div>

                  {/* Password Field */}
                  <div className="mb-3">
                    <label htmlFor="password" className="form-label fw-medium">
                      Mot de passe
                    </label>
                    <div className="input-group">
                      <span className="input-group-text">
                        <i className="bi bi-lock text-muted"></i>
                      </span>
                      <input
                        type={showPassword ? 'text' : 'password'}
                        id="password"
                        name="password"
                        className="form-control"
                        value={formData.password}
                        onChange={handleInputChange}
                        required
                        placeholder="••••••••"
                      />
                      <button
                        type="button"
                        className="btn btn-outline-secondary"
                        onClick={() => setShowPassword(!showPassword)}
                      >
                        <i className={`bi ${showPassword ? 'bi-eye-slash' : 'bi-eye'}`}></i>
                      </button>
                    </div>
                  </div>

                  {/* Error Message */}
                  {error && (
                    <div className="alert alert-danger" role="alert">
                      <i className="bi bi-exclamation-triangle me-2"></i>
                      {error}
                    </div>
                  )}

                  {/* Submit Button */}
                  <div className="d-grid">
                    <button
                      type="submit"
                      disabled={localLoading}
                      className="btn btn-primary btn-lg"
                    >
                      {localLoading ? (
                        <>
                          <span className="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>
                          Connexion...
                        </>
                      ) : (
                        'Se connecter'
                      )}
                    </button>
                  </div>
                </form>
              </div>
            </div>

            {/* Footer */}
            <div className="text-center mt-4">
              <p className="text-muted small">
                © 2024 KiloShare. Tous droits réservés.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}