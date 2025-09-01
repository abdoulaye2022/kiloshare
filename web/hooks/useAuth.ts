'use client';

import { useState, useEffect } from 'react';

interface User {
  id: number;
  uuid: string;
  email: string;
  first_name?: string;
  last_name?: string;
  phone?: string;
  is_verified: boolean;
  role: string;
}

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Simuler la récupération du token depuis localStorage
    const savedToken = localStorage.getItem('auth_token');
    if (savedToken) {
      setToken(savedToken);
      // Dans une vraie app, on décoderait le JWT pour obtenir l'utilisateur
      setUser({
        id: 1,
        uuid: 'user-demo-uuid',
        email: 'demo@kiloshare.com',
        first_name: 'Demo',
        last_name: 'User',
        is_verified: true,
        role: 'user'
      });
    } else {
      // Token de démonstration pour les tests
      const demoToken = 'demo_token_for_testing';
      setToken(demoToken);
      localStorage.setItem('auth_token', demoToken);
      setUser({
        id: 1,
        uuid: 'user-demo-uuid',
        email: 'demo@kiloshare.com',
        first_name: 'Demo',
        last_name: 'User',
        is_verified: true,
        role: 'user'
      });
    }
    setLoading(false);
  }, []);

  const logout = () => {
    localStorage.removeItem('auth_token');
    setToken(null);
    setUser(null);
  };

  const login = (newToken: string, userData: User) => {
    localStorage.setItem('auth_token', newToken);
    setToken(newToken);
    setUser(userData);
  };

  return {
    user,
    token,
    loading,
    isAuthenticated: !!token && !!user,
    login,
    logout
  };
}