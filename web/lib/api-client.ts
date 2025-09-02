/**
 * Client API configuré avec l'URL de base
 */

import { API_BASE_URL } from './api-config';

/**
 * Faire un appel API avec l'URL de base configurée
 */
export const apiRequest = async (endpoint: string, options: RequestInit = {}): Promise<Response> => {
  const fullUrl = endpoint.startsWith('http') ? endpoint : `${API_BASE_URL}${endpoint}`;
  
  return fetch(fullUrl, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
};

/**
 * Faire un appel API avec authentification
 */
export const authenticatedApiRequest = async (
  endpoint: string, 
  token: string,
  options: RequestInit = {}
): Promise<Response> => {
  return apiRequest(endpoint, {
    ...options,
    headers: {
      ...options.headers,
      Authorization: `Bearer ${token}`,
    },
  });
};

/**
 * Utilitaire pour les appels GET
 */
export const get = (endpoint: string, token?: string) => {
  if (token) {
    return authenticatedApiRequest(endpoint, token, { method: 'GET' });
  }
  return apiRequest(endpoint, { method: 'GET' });
};

/**
 * Utilitaire pour les appels POST
 */
export const post = (endpoint: string, data?: any, token?: string) => {
  const options: RequestInit = {
    method: 'POST',
    body: data ? JSON.stringify(data) : undefined,
  };

  if (token) {
    return authenticatedApiRequest(endpoint, token, options);
  }
  return apiRequest(endpoint, options);
};

/**
 * Utilitaire pour les appels PUT
 */
export const put = (endpoint: string, data?: any, token?: string) => {
  const options: RequestInit = {
    method: 'PUT',
    body: data ? JSON.stringify(data) : undefined,
  };

  if (token) {
    return authenticatedApiRequest(endpoint, token, options);
  }
  return apiRequest(endpoint, options);
};

/**
 * Utilitaire pour les appels DELETE
 */
export const del = (endpoint: string, token?: string) => {
  if (token) {
    return authenticatedApiRequest(endpoint, token, { method: 'DELETE' });
  }
  return apiRequest(endpoint, { method: 'DELETE' });
};