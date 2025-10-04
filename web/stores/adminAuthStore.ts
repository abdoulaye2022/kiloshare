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
        
        try {
          // Update Zustand state FIRST
          set({ 
            token, 
            user,
            refreshToken: refreshToken || null,
            isAuthenticated: true,
            isLoading: false 
          });
          
          
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
          }
          
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
          return state.isAuthenticated;
        }
        
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


          if (!token) {
            set({ 
              isAuthenticated: false, 
              isLoading: false, 
              token: null, 
              user: null,
              _isCheckingAuth: false 
            });
            return false;
          }

          
          // Validate token with backend API
          const response = await fetch(AUTH_ENDPOINTS.ADMIN_ME, {
            method: 'GET',
            headers: getDefaultHeaders(token)
          });


          if (response.ok) {
            const data = await response.json();
            
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
              
              return true;
            }
          }
          
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