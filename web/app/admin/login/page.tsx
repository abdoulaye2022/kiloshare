'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Shield, Mail, Lock, Eye, EyeOff, Loader } from 'lucide-react';
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
    <div className="min-h-screen bg-gray-100 flex items-center justify-center px-4">
      <div className="max-w-md w-full">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex justify-center items-center space-x-3 mb-4">
            <Shield className="h-12 w-12 text-blue-600" />
            <div>
              <h1 className="text-3xl font-bold text-gray-900">KiloShare</h1>
              <p className="text-sm text-blue-600 font-medium">Administration</p>
            </div>
          </div>
          <h2 className="text-2xl font-bold text-gray-700">Connexion Admin</h2>
          <p className="text-gray-500 mt-2">Connectez-vous à votre espace d'administration</p>
        </div>

        {/* Login Form */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Email Field */}
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                Email
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
                <input
                  type="email"
                  id="email"
                  name="email"
                  value={formData.email}
                  onChange={handleInputChange}
                  required
                  className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors bg-white text-gray-900 placeholder-gray-500"
                  placeholder="admin@kiloshare.com"
                />
              </div>
            </div>

            {/* Password Field */}
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
                Mot de passe
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  id="password"
                  name="password"
                  value={formData.password}
                  onChange={handleInputChange}
                  required
                  className="w-full pl-10 pr-12 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors bg-white text-gray-900 placeholder-gray-500"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                >
                  {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                </button>
              </div>
            </div>

            {/* Error Message */}
            {error && (
              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg text-sm">
                {error}
              </div>
            )}

            {/* Submit Button */}
            <button
              type="submit"
              disabled={localLoading}
              className="w-full bg-blue-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center space-x-2"
            >
              {localLoading && <Loader className="h-4 w-4 animate-spin" />}
              <span>{localLoading ? 'Connexion...' : 'Se connecter'}</span>
            </button>
          </form>
        </div>


        {/* Footer */}
        <div className="text-center mt-6">
          <p className="text-sm text-gray-500">
            © 2024 KiloShare. Tous droits réservés.
          </p>
        </div>
      </div>
    </div>
  );
}