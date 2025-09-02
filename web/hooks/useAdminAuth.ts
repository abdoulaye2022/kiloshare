'use client';

import { useEffect } from 'react';
import { useAdminAuthStore } from '../stores/adminAuthStore';

export const useAdminAuth = () => {
  const store = useAdminAuthStore();

  useEffect(() => {
    // Initialize auth check on app startup
    const initializeAuth = async () => {
      try {
        await store.checkAuth();
      } catch (error) {
        console.error('Failed to initialize auth:', error);
      }
    };

    initializeAuth();
  }, []);

  return store;
};