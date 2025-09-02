'use client';

import { useState, useEffect } from 'react';
import { useAdminAuthStore } from '../../stores/adminAuthStore';
import { ADMIN_ENDPOINTS, getDefaultHeaders } from '../../lib/api-config';

interface DashboardStats {
  // KPIs Financiers
  revenue_today: number;
  revenue_this_week: number;
  revenue_this_month: number;
  commissions_collected: number;
  transactions_pending: number;
  
  // Activité Plateforme
  active_users: number;
  new_registrations_today: number;
  new_registrations_this_week: number;
  published_trips_today: number;
  published_trips_this_week: number;
  active_bookings: number;
  
  // Santé du Système
  trip_completion_rate: number;
  dispute_rate: number;
  average_resolution_time_hours: number;
  
  // Alertes Critiques
  suspected_fraud_count: number;
  urgent_disputes_count: number;
  reported_trips_count: number;
  failed_payments_count: number;
  
  // Données pour graphiques
  revenue_growth: Array<{date: string, amount: number}>;
  user_growth: Array<{date: string, count: number}>;
  popular_routes: Array<{route: string, count: number, revenue: number}>;
  transport_distribution: Array<{type: string, count: number, percentage: number}>;
}

interface AdminDashboardProps {
  adminInfo: any;
  onLogout: () => void;
}

export default function Dashboard({ adminInfo, onLogout }: AdminDashboardProps) {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  const { token, isAuthenticated, logout } = useAdminAuthStore();

  useEffect(() => {
    if (isAuthenticated && token) {
      fetchDashboardStats();
      // Rafraîchir les stats toutes les 5 minutes
      const interval = setInterval(fetchDashboardStats, 5 * 60 * 1000);
      return () => clearInterval(interval);
    }
  }, [isAuthenticated, token]);

  const fetchDashboardStats = async () => {
    try {
      if (!token) {
        setError('Aucun token d\'authentification disponible');
        setLoading(false);
        return;
      }

      const response = await fetch(ADMIN_ENDPOINTS.DASHBOARD_STATS, {
        method: 'GET',
        headers: getDefaultHeaders(token)
      });
      
      if (response.ok) {
        const data = await response.json();
        setStats(data.stats);
        setError(null);
      } else {
        // Si on reçoit une 401, c'est que le token n'est plus valide
        if (response.status === 401) {
          console.log('❌ Token expired, logging out');
          logout();
          onLogout();
          return;
        }
        
        const errorData = await response.json();
        setError(errorData.message || 'Erreur lors du chargement des statistiques');
      }
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
      setError('Erreur de connexion');
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'EUR'
    }).format(amount);
  };

  const getAlertLevel = (type: 'fraud' | 'disputes' | 'reports' | 'payments') => {
    if (!stats) return 'low';
    
    const thresholds = {
      fraud: { high: 10, medium: 5 },
      disputes: { high: 20, medium: 10 },
      reports: { high: 15, medium: 8 },
      payments: { high: 25, medium: 10 }
    };
    
    const counts = {
      fraud: stats.suspected_fraud_count,
      disputes: stats.urgent_disputes_count,
      reports: stats.reported_trips_count,
      payments: stats.failed_payments_count
    };
    
    const count = counts[type];
    const threshold = thresholds[type];
    
    if (count >= threshold.high) return 'high';
    if (count >= threshold.medium) return 'medium';
    return 'low';
  };

  const getAlertColor = (level: string) => {
    switch (level) {
      case 'high': return 'bg-red-100 text-red-800 border-red-200';
      case 'medium': return 'bg-yellow-100 text-yellow-800 border-yellow-200';
      default: return 'bg-green-100 text-green-800 border-green-200';
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="max-w-md mx-auto bg-white rounded-lg shadow-sm border border-gray-200 p-6 text-center">
          <div className="text-red-600 text-lg mb-4">{error}</div>
          <button
            onClick={fetchDashboardStats}
            className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md transition-colors"
          >
            Réessayer
          </button>
        </div>
      </div>
    );
  }

  if (!stats) {
    return (
      <div className="p-6">
        <div className="text-center text-gray-500">Aucune donnée disponible</div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Dashboard Content */}
      <div className="space-y-6">
        {/* Quick Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {/* Revenue Today */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Revenus aujourd'hui</p>
                <p className="text-2xl font-bold text-gray-900">{formatCurrency(stats.revenue_today)}</p>
              </div>
              <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                </svg>
              </div>
            </div>
          </div>

          {/* Active Users */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Utilisateurs actifs</p>
                <p className="text-2xl font-bold text-gray-900">{stats.active_users.toLocaleString()}</p>
              </div>
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg className="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                </svg>
              </div>
            </div>
          </div>

          {/* Active Bookings */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Réservations actives</p>
                <p className="text-2xl font-bold text-gray-900">{stats.active_bookings}</p>
              </div>
              <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg className="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v6a2 2 0 002 2h2m0 0h2m-2 0v4a1 1 0 001 1h4a1 1 0 001-1v-4m-2 0V9a1 1 0 00-1-1H9a1 1 0 00-1 1v6z" />
                </svg>
              </div>
            </div>
          </div>

          {/* Commission Rate */}
          <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Taux de completion</p>
                <p className="text-2xl font-bold text-gray-900">{stats.trip_completion_rate}%</p>
              </div>
              <div className="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
                <svg className="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </div>
            </div>
          </div>
        </div>

        {/* Alerts Section */}
        {(stats.suspected_fraud_count > 0 || stats.urgent_disputes_count > 0 || stats.reported_trips_count > 0 || stats.failed_payments_count > 0) && (
          <div className="bg-white rounded-lg shadow-sm border border-gray-200">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">Alertes critiques</h2>
            </div>
            <div className="p-6">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {stats.suspected_fraud_count > 0 && (
                  <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <svg className="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <div className="ml-3">
                        <h3 className="text-sm font-medium text-red-800">{stats.suspected_fraud_count} Fraudes suspectées</h3>
                        <p className="text-xs text-red-700">Nécessite une vérification</p>
                      </div>
                    </div>
                  </div>
                )}

                {stats.urgent_disputes_count > 0 && (
                  <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <svg className="w-5 h-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <div className="ml-3">
                        <h3 className="text-sm font-medium text-yellow-800">{stats.urgent_disputes_count} Litiges urgents</h3>
                        <p className="text-xs text-yellow-700">À traiter prioritairement</p>
                      </div>
                    </div>
                  </div>
                )}

                {stats.reported_trips_count > 0 && (
                  <div className="bg-orange-50 border border-orange-200 rounded-lg p-4">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <svg className="w-5 h-5 text-orange-400" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-5a.75.75 0 01.75.75v4.5a.75.75 0 01-1.5 0v-4.5A.75.75 0 0110 5zM10 13a1 1 0 100 2 1 1 0 000-2z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <div className="ml-3">
                        <h3 className="text-sm font-medium text-orange-800">{stats.reported_trips_count} Annonces signalées</h3>
                        <p className="text-xs text-orange-700">Modération requise</p>
                      </div>
                    </div>
                  </div>
                )}

                {stats.failed_payments_count > 0 && (
                  <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <svg className="w-5 h-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                          <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.236 4.53L8.53 10.5a.75.75 0 00-1.06 1.061l1.5 1.5a.75.75 0 001.137-.089l4-5.5z" clipRule="evenodd" />
                        </svg>
                      </div>
                      <div className="ml-3">
                        <h3 className="text-sm font-medium text-red-800">{stats.failed_payments_count} Paiements échoués</h3>
                        <p className="text-xs text-red-700">Vérification nécessaire</p>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Recent Activity */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="bg-white rounded-lg shadow-sm border border-gray-200">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">Activité récente</h2>
            </div>
            <div className="p-6">
              <div className="space-y-4">
                <div className="flex items-center justify-between py-3 border-b border-gray-100 last:border-0">
                  <div>
                    <p className="text-sm font-medium text-gray-900">Nouvelles inscriptions aujourd'hui</p>
                    <p className="text-xs text-gray-500">Croissance des utilisateurs</p>
                  </div>
                  <span className="text-lg font-semibold text-blue-600">+{stats.new_registrations_today}</span>
                </div>
                <div className="flex items-center justify-between py-3 border-b border-gray-100 last:border-0">
                  <div>
                    <p className="text-sm font-medium text-gray-900">Annonces publiées aujourd'hui</p>
                    <p className="text-xs text-gray-500">Nouvelle offre de transport</p>
                  </div>
                  <span className="text-lg font-semibold text-green-600">+{stats.published_trips_today}</span>
                </div>
                <div className="flex items-center justify-between py-3 border-b border-gray-100 last:border-0">
                  <div>
                    <p className="text-sm font-medium text-gray-900">Revenus cette semaine</p>
                    <p className="text-xs text-gray-500">Performance commerciale</p>
                  </div>
                  <span className="text-lg font-semibold text-gray-900">{formatCurrency(stats.revenue_this_week)}</span>
                </div>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow-sm border border-gray-200">
            <div className="px-6 py-4 border-b border-gray-200">
              <h2 className="text-lg font-semibold text-gray-900">Routes populaires</h2>
            </div>
            <div className="p-6">
              <div className="space-y-4">
                {stats.popular_routes.slice(0, 5).map((route, index) => (
                  <div key={index} className="flex items-center justify-between py-3 border-b border-gray-100 last:border-0">
                    <div>
                      <p className="text-sm font-medium text-gray-900">{route.route}</p>
                      <p className="text-xs text-gray-500">{route.count} annonces</p>
                    </div>
                    <span className="text-sm font-semibold text-gray-600">{formatCurrency(route.revenue)}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}