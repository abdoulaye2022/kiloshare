'use client';

import { create } from 'zustand';
import Cookies from 'js-cookie';
import { AUTH_ENDPOINTS, getDefaultHeaders } from '../lib/api-config';

interface AdminUser {
  id: number;
  email: string;
  role: string;
  first_name?: string;
  last_name?: string;
}

interface AdminAuthState {
  user: AdminUser | null;
  token: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  _isCheckingAuth?: boolean; // Internal flag
  login: (token: string, user: AdminUser, refreshToken?: string) => void;
  logout: () => void;
  setLoading: (loading: boolean) => void;
  checkAuth: () => Promise<boolean>;
}

const ADMIN_TOKEN_KEY = 'admin_token';
const ADMIN_REFRESH_TOKEN_KEY = 'admin_refresh_token';

// Create the store without persist first for testing  
export const useAdminAuthStore = create<AdminAuthState>((set, get) => ({
      user: null,
      token: null,
      refreshToken: null,
      isAuthenticated: false,
      isLoading: false, // Start as false, will be set by initializer
      _isCheckingAuth: false, // Internal flag to prevent multiple simultaneous checks

      login: (token: string, user: AdminUser, refreshToken?: string) => {
        console.log('🔑 ZUSTAND LOGIN CALLED', { 
          userEmail: user.email, 
          tokenLength: token.length,
          tokenPreview: token.substring(0, 20) + '...',
          hasRefreshToken: !!refreshToken
        });
        
        try {
          // Update Zustand state FIRST
          set({ 
            token, 
            user,
            refreshToken: refreshToken || null,
            isAuthenticated: true,
            isLoading: false 
          });
          
          console.log('✅ Zustand state updated');
          
          // Then store in all locations
          if (typeof window !== 'undefined') {
            localStorage.setItem(ADMIN_TOKEN_KEY, token);
            sessionStorage.setItem(ADMIN_TOKEN_KEY, token);
            
            // Store refresh token if provided
            if (refreshToken) {
              localStorage.setItem(ADMIN_REFRESH_TOKEN_KEY, refreshToken);
              sessionStorage.setItem(ADMIN_REFRESH_TOKEN_KEY, refreshToken);
            }
            
            // Set cookie
            Cookies.set(ADMIN_TOKEN_KEY, token, { 
              expires: 7,
              secure: false,
              sameSite: 'lax',
              path: '/'
            });

            console.log('💾 Storage updated:', {
              localStorage: localStorage.getItem(ADMIN_TOKEN_KEY)?.substring(0, 10) + '...',
              sessionStorage: sessionStorage.getItem(ADMIN_TOKEN_KEY)?.substring(0, 10) + '...',
              cookie: Cookies.get(ADMIN_TOKEN_KEY)?.substring(0, 10) + '...',
              refreshToken: !!refreshToken
            });
          }
          
          console.log('🎉 LOGIN COMPLETE - User authenticated');
        } catch (error) {
          console.error('❌ Error during login:', error);
        }
      },

      logout: () => {
        // Clear from all storage locations
        localStorage.removeItem(ADMIN_TOKEN_KEY);
        sessionStorage.removeItem(ADMIN_TOKEN_KEY);
        localStorage.removeItem(ADMIN_REFRESH_TOKEN_KEY);
        sessionStorage.removeItem(ADMIN_REFRESH_TOKEN_KEY);
        Cookies.remove(ADMIN_TOKEN_KEY);

        set({ 
          token: null, 
          user: null,
          refreshToken: null,
          isAuthenticated: false,
          isLoading: false 
        });
      },

      setLoading: (loading: boolean) => {
        set({ isLoading: loading });
      },

      checkAuth: async (): Promise<boolean> => {
        const state = get();
        
        // Prevent multiple simultaneous checks
        if (state._isCheckingAuth) {
          console.log('⏸️ Auth check already in progress, skipping...');
          return state.isAuthenticated;
        }
        
        console.log('🔍 Checking authentication...');
        set({ isLoading: true, _isCheckingAuth: true });

        try {
          // Try to get token from multiple sources  
          let token = null;
          
          if (typeof window !== 'undefined') {
            token = state.token || 
                   localStorage.getItem(ADMIN_TOKEN_KEY) || 
                   sessionStorage.getItem(ADMIN_TOKEN_KEY) ||
                   Cookies.get(ADMIN_TOKEN_KEY);
          }

          console.log('🔑 Token found:', !!token);

          if (!token) {
            console.log('❌ No token found');
            set({ 
              isAuthenticated: false, 
              isLoading: false, 
              token: null, 
              user: null,
              _isCheckingAuth: false 
            });
            return false;
          }

          console.log('✅ Token found, verifying with backend...');
          
          // Validate token with backend API
          const response = await fetch(AUTH_ENDPOINTS.ME, {
            method: 'GET',
            headers: getDefaultHeaders(token)
          });

          console.log('📡 Backend validation response:', response.status);

          if (response.ok) {
            const data = await response.json();
            console.log('✅ Token valid, user data:', data);
            
            if (data.success && data.data) {
              set({ 
                token, 
                user: data.data,
                isAuthenticated: true,
                isLoading: false,
                _isCheckingAuth: false
              });
              
              // Ensure token is stored in all locations
              if (typeof window !== 'undefined') {
                localStorage.setItem(ADMIN_TOKEN_KEY, token);
                sessionStorage.setItem(ADMIN_TOKEN_KEY, token);
                Cookies.set(ADMIN_TOKEN_KEY, token, { 
                  expires: 7,
                  secure: false,
                  sameSite: 'lax',
                  path: '/'
                });
              }
              
              console.log('🎉 Auth check successful with real user data');
              return true;
            }
          }
          
          console.log('❌ Token validation failed');
          // Token is invalid, clear everything
          localStorage.removeItem(ADMIN_TOKEN_KEY);
          sessionStorage.removeItem(ADMIN_TOKEN_KEY);
          localStorage.removeItem(ADMIN_REFRESH_TOKEN_KEY);
          sessionStorage.removeItem(ADMIN_REFRESH_TOKEN_KEY);
          Cookies.remove(ADMIN_TOKEN_KEY);
          
          set({ 
            isAuthenticated: false,
            isLoading: false,
            token: null,
            user: null,
            refreshToken: null,
            _isCheckingAuth: false
          });
          return false;

        } catch (error) {
          console.error('❌ Auth check failed:', error);
          set({ 
            isAuthenticated: false,
            isLoading: false,
            token: null,
            user: null,
            _isCheckingAuth: false
          });
          return false;
        }
      }
    }));