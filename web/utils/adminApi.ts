import { useAdminAuthStore } from '../stores/adminAuthStore';

class AdminAPI {
  private baseURL: string;

  constructor() {
    this.baseURL = process.env.NEXT_PUBLIC_API_URL || 'http://127.0.0.1:8080';
  }

  private getToken(): string | null {
    const store = useAdminAuthStore.getState();
    return store.token || localStorage.getItem('admin_token');
  }

  private async request(endpoint: string, options: RequestInit = {}): Promise<Response> {
    const token = this.getToken();
    
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(options.headers as Record<string, string> || {}),
    };

    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }

    const response = await fetch(`${this.baseURL}${endpoint}`, {
      ...options,
      headers,
    });

    // If unauthorized, clear the session
    if (response.status === 401) {
      const store = useAdminAuthStore.getState();
      store.logout();
    }

    return response;
  }

  async get(endpoint: string): Promise<Response> {
    return this.request(endpoint, { method: 'GET' });
  }

  async post(endpoint: string, data: any): Promise<Response> {
    return this.request(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async put(endpoint: string, data: any): Promise<Response> {
    return this.request(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async delete(endpoint: string): Promise<Response> {
    return this.request(endpoint, { method: 'DELETE' });
  }

  // Specific admin endpoints
  async checkProfile(): Promise<Response> {
    return this.get('/api/v1/admin/profile');
  }

  async getDashboardStats(): Promise<Response> {
    return this.get('/api/v1/admin/dashboard/stats');
  }

  async getUsers(): Promise<Response> {
    return this.get('/api/v1/admin/users');
  }

  async getTrips(): Promise<Response> {
    return this.get('/api/v1/admin/trips/pending');
  }
}

export const adminAPI = new AdminAPI();