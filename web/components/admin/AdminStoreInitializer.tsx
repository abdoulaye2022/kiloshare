'use client';

import { useEffect } from 'react';
import { useAdminAuthStore } from '../../stores/adminAuthStore';

export default function AdminStoreInitializer() {
  const { setLoading, checkAuth } = useAdminAuthStore();

  useEffect(() => {
    const initializeStore = async () => {
      // Wait for hydration to complete
      await new Promise(resolve => setTimeout(resolve, 200));
      
      
      try {
        // Only access storage after hydration
        if (typeof window !== 'undefined') {
          const localToken = localStorage.getItem('admin_token');
          const sessionToken = sessionStorage.getItem('admin_token');
          const cookieExists = document.cookie.includes('admin_token=');
          
          // If we find tokens, sync them with the store
          if (localToken || sessionToken || cookieExists) {
            // Use the first available token and check auth
            const tokenToUse = localToken || sessionToken;
            if (tokenToUse) {
              const authResult = await checkAuth();
              if (!authResult) {
                // Clear invalid tokens from all locations
                localStorage.removeItem('admin_token');
                localStorage.removeItem('admin_refresh_token');
                sessionStorage.removeItem('admin_token');
                sessionStorage.removeItem('admin_refresh_token');
                document.cookie = 'admin_token=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
              }
            }
          } else {
            setLoading(false);
          }
        }
        
      } catch (error) {
        console.error('❌ Error initializing admin store:', error);
        setLoading(false);
      }
    };

    // Only run on client side
    if (typeof window !== 'undefined') {
      initializeStore();
    }
  }, [setLoading, checkAuth]);

  return null;
}