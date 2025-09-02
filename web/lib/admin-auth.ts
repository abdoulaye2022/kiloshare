import { AUTH_ENDPOINTS, getDefaultHeaders, API_BASE_URL } from './api-config';

class AdminAuthService {
  private static instance: AdminAuthService;
  private refreshPromise: Promise<void> | null = null;

  static getInstance(): AdminAuthService {
    if (!AdminAuthService.instance) {
      AdminAuthService.instance = new AdminAuthService();
    }
    return AdminAuthService.instance;
  }

  // Stocker les tokens après login
  setTokens(accessToken: string, refreshToken: string, expiresIn: number, adminInfo: any) {
    localStorage.setItem('adminToken', accessToken);
    localStorage.setItem('adminRefreshToken', refreshToken);
    localStorage.setItem('adminInfo', JSON.stringify(adminInfo));
    
    // Calculer la date d'expiration
    const expiresAt = Date.now() + (expiresIn * 1000);
    localStorage.setItem('adminTokenExpiresAt', expiresAt.toString());
  }

  // Récupérer le token d'accès (compatible avec le nouveau store Zustand)
  getAccessToken(): string | null {
    return localStorage.getItem('admin_token') || localStorage.getItem('adminToken');
  }

  // Récupérer le refresh token (compatible avec le nouveau store Zustand)
  getRefreshToken(): string | null {
    return localStorage.getItem('admin_refresh_token') || localStorage.getItem('adminRefreshToken');
  }

  // Vérifier si le token est expiré
  isTokenExpired(): boolean {
    const expiresAt = localStorage.getItem('adminTokenExpiresAt');
    if (!expiresAt) return true;
    
    const now = Date.now();
    const tokenExpiresAt = parseInt(expiresAt);
    
    // Considérer le token comme expiré 5 minutes avant l'expiration réelle
    return now >= (tokenExpiresAt - 5 * 60 * 1000);
  }

  // Obtenir un token valide (simplifié - plus de refresh automatique)
  async getValidAccessToken(): Promise<string | null> {
    const token = this.getAccessToken();
    
    if (!token) {
      return null;
    }

    // Pour l'instant, on retourne le token tel quel
    // La validation se fera au niveau des API calls
    return token;
  }

  // Rafraîchir le token
  private async refreshToken(): Promise<void> {
    const refreshToken = this.getRefreshToken();
    
    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await fetch(AUTH_ENDPOINTS.REFRESH, {
      method: 'POST',
      headers: getDefaultHeaders(),
      body: JSON.stringify({ refresh_token: refreshToken }),
    });

    const data = await response.json();

    if (!response.ok || !data.success) {
      throw new Error(data.message || 'Token refresh failed');
    }

    // Stocker les nouveaux tokens
    this.setTokens(
      data.token, 
      data.refresh_token, 
      data.expires_in, 
      data.admin
    );
  }

  // Nettoyer tous les tokens (compatible avec les deux systèmes)
  clearTokens() {
    // Old format
    localStorage.removeItem('adminToken');
    localStorage.removeItem('adminRefreshToken');
    localStorage.removeItem('adminTokenExpiresAt');
    localStorage.removeItem('adminInfo');
    
    // New format (Zustand store)
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_refresh_token');
    localStorage.removeItem('admin-auth-storage');
    sessionStorage.removeItem('admin_token');
    sessionStorage.removeItem('admin_refresh_token');
  }

  // Faire une requête API avec gestion automatique des tokens
  async apiRequest(url: string, options: RequestInit = {}): Promise<Response> {
    const token = await this.getValidAccessToken();
    
    if (!token) {
      // Rediriger vers la page de login si pas de token valide
      window.location.href = '/admin/login';
      throw new Error('No valid token available');
    }

    // Construire l'URL complète si c'est un chemin relatif
    const fullUrl = url.startsWith('http') ? url : `${API_BASE_URL}${url}`;

    const headers = {
      ...options.headers,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    };

    const response = await fetch(fullUrl, {
      ...options,
      headers,
    });

    // Si on reçoit une 401, rediriger directement vers login
    if (response.status === 401) {
      console.error('Authentication failed - redirecting to login');
      this.clearTokens();
      window.location.href = '/admin/login';
      throw new Error('Authentication failed');
    }

    return response;
  }

  // Vérifier si l'utilisateur est connecté (compatible avec le nouveau store)
  isAuthenticated(): boolean {
    const token = this.getAccessToken();
    // Check both old and new storage formats
    const adminInfo = localStorage.getItem('adminInfo') || localStorage.getItem('admin-auth-storage');
    return !!token && (!!adminInfo || !!localStorage.getItem('admin_token'));
  }

  // Obtenir les informations admin
  getAdminInfo(): any | null {
    const adminInfo = localStorage.getItem('adminInfo');
    return adminInfo ? JSON.parse(adminInfo) : null;
  }

  // Déconnexion
  logout() {
    this.clearTokens();
    window.location.href = '/admin/login';
  }
}

export const adminAuth = AdminAuthService.getInstance();
export default adminAuth;