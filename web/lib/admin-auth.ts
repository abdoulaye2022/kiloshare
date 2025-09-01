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

  // Récupérer le token d'accès
  getAccessToken(): string | null {
    return localStorage.getItem('adminToken');
  }

  // Récupérer le refresh token
  getRefreshToken(): string | null {
    return localStorage.getItem('adminRefreshToken');
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

  // Obtenir un token valide (rafraîchir si nécessaire)
  async getValidAccessToken(): Promise<string | null> {
    const token = this.getAccessToken();
    
    if (!token) {
      return null;
    }

    if (!this.isTokenExpired()) {
      return token;
    }

    // Si un refresh est déjà en cours, attendre sa completion
    if (this.refreshPromise) {
      await this.refreshPromise;
      return this.getAccessToken();
    }

    // Lancer le refresh
    this.refreshPromise = this.refreshToken();
    
    try {
      await this.refreshPromise;
      return this.getAccessToken();
    } catch (error) {
      console.error('Token refresh failed:', error);
      this.clearTokens();
      return null;
    } finally {
      this.refreshPromise = null;
    }
  }

  // Rafraîchir le token
  private async refreshToken(): Promise<void> {
    const refreshToken = this.getRefreshToken();
    
    if (!refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await fetch('/api/admin/auth/refresh', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
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

  // Nettoyer tous les tokens
  clearTokens() {
    localStorage.removeItem('adminToken');
    localStorage.removeItem('adminRefreshToken');
    localStorage.removeItem('adminTokenExpiresAt');
    localStorage.removeItem('adminInfo');
  }

  // Faire une requête API avec gestion automatique des tokens
  async apiRequest(url: string, options: RequestInit = {}): Promise<Response> {
    const token = await this.getValidAccessToken();
    
    if (!token) {
      // Rediriger vers la page de login si pas de token valide
      window.location.href = '/admin/login';
      throw new Error('No valid token available');
    }

    const headers = {
      ...options.headers,
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    };

    const response = await fetch(url, {
      ...options,
      headers,
    });

    // Si on reçoit une 401, essayer de rafraîchir le token une fois
    if (response.status === 401) {
      try {
        await this.refreshToken();
        const newToken = this.getAccessToken();
        
        if (newToken) {
          const retryHeaders = {
            ...options.headers,
            'Authorization': `Bearer ${newToken}`,
            'Content-Type': 'application/json',
          };
          
          return fetch(url, {
            ...options,
            headers: retryHeaders,
          });
        }
      } catch (error) {
        console.error('Token refresh failed on 401:', error);
      }
      
      // Si le refresh échoue, rediriger vers login
      this.clearTokens();
      window.location.href = '/admin/login';
      throw new Error('Authentication failed');
    }

    return response;
  }

  // Vérifier si l'utilisateur est connecté
  isAuthenticated(): boolean {
    const token = this.getAccessToken();
    const adminInfo = localStorage.getItem('adminInfo');
    return !!token && !!adminInfo;
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