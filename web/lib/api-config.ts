/**
 * Configuration centralisée pour les URLs d'API
 */

// URL de base de l'API backend
export const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';

// Version de l'API
export const API_VERSION = 'v1';

// URL complète de l'API avec version
export const API_URL = `${API_BASE_URL}/api/${API_VERSION}`;

/**
 * Endpoints d'authentification
 */
export const AUTH_ENDPOINTS = {
  // Authentification utilisateur
  LOGIN: `${API_URL}/auth/login`,
  REGISTER: `${API_URL}/auth/register`,
  REFRESH: `${API_URL}/auth/refresh`,
  LOGOUT: `${API_URL}/auth/logout`,
  ME: `${API_URL}/auth/me`,
  FORGOT_PASSWORD: `${API_URL}/auth/forgot-password`,
  RESET_PASSWORD: `${API_URL}/auth/reset-password`,
  VERIFY_EMAIL: `${API_URL}/auth/verify-email`,
  
  // Authentification admin
  ADMIN_LOGIN: `${API_URL}/admin/auth/login`,
} as const;

/**
 * Endpoints admin
 */
export const ADMIN_ENDPOINTS = {
  DASHBOARD_STATS: `${API_URL}/admin/dashboard/stats`,
  USERS: `${API_URL}/admin/users`,
  TRIPS_PENDING: `${API_URL}/admin/trips/pending`,
  PAYMENTS_STATS: `${API_URL}/admin/payments/stats`,
  PAYMENTS_TRANSACTIONS: `${API_URL}/admin/payments/transactions`,
} as const;

/**
 * Endpoints généraux
 */
export const API_ENDPOINTS = {
  TRIPS: `${API_URL}/trips`,
  SEARCH: `${API_URL}/search`,
  PROFILE: `${API_URL}/profile`,
  IMAGES: `${API_URL}/images`,
} as const;

/**
 * Utilitaire pour construire une URL d'API
 */
export function buildApiUrl(endpoint: string): string {
  // Si l'endpoint commence déjà par http, le retourner tel quel
  if (endpoint.startsWith('http')) {
    return endpoint;
  }
  
  // Si l'endpoint commence par /, l'ajouter à l'URL de base
  if (endpoint.startsWith('/')) {
    return `${API_BASE_URL}${endpoint}`;
  }
  
  // Sinon, l'ajouter à l'URL de l'API versionnée
  return `${API_URL}/${endpoint}`;
}

/**
 * Utilitaire pour obtenir les headers par défaut
 */
export function getDefaultHeaders(token?: string): HeadersInit {
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
  };
  
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  return headers;
}

export default {
  API_BASE_URL,
  API_VERSION,
  API_URL,
  AUTH_ENDPOINTS,
  ADMIN_ENDPOINTS,
  API_ENDPOINTS,
  buildApiUrl,
  getDefaultHeaders,
};