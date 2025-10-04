'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface PlatformMetrics {
  total_users: number;
  active_users: number;
  total_trips: number;
  completed_trips: number;
  total_bookings: number;
  total_revenue: number;
  total_commission: number;
  commission_rate: number;
  connected_accounts: number;
  active_connected_accounts: number;
  pending_transfers: number;
  stripe_fees: number;
  net_revenue: number;
  monthly_growth: number;
  conversion_rate: number;
}

interface PlatformTrends {
  daily: Array<{
    date: string;
    revenue: number;
    transactions: number;
    users: number;
  }>;
  weekly: Array<{
    week: string;
    revenue: number;
    transactions: number;
    users: number;
  }>;
  monthly: Array<{
    month: string;
    revenue: number;
    transactions: number;
    users: number;
  }>;
}

export default function PlatformAnalyticsDashboard() {
  const [metrics, setMetrics] = useState<PlatformMetrics | null>(null);
  const [trends, setTrends] = useState<PlatformTrends | null>(null);
  const [loading, setLoading] = useState(true);
  const [timeframe, setTimeframe] = useState<'daily' | 'weekly' | 'monthly'>('daily');

  useEffect(() => {
    fetchMetrics();
    fetchTrends();
  }, [timeframe]);

  const fetchMetrics = async () => {
    try {
      setLoading(true);
      const response = await adminAuth.apiRequest('/api/v1/admin/analytics/platform/metrics');
      
      if (response.ok) {
        const data = await response.json();
        setMetrics(data.data?.metrics);
      }
    } catch (error) {
      console.error('Error fetching platform metrics:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchTrends = async () => {
    try {
      const response = await adminAuth.apiRequest(`/api/v1/admin/analytics/platform/trends?timeframe=${timeframe}`);
      
      if (response.ok) {
        const data = await response.json();
        setTrends(data.data?.trends);
      }
    } catch (error) {
      console.error('Error fetching platform trends:', error);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: 'CAD'
    }).format(amount);
  };

  const formatPercentage = (value: number) => {
    return `${value >= 0 ? '+' : ''}${value.toFixed(1)}%`;
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/3 mb-6"></div>
          <div className="grid grid-cols-4 gap-4 mb-6">
            {[...Array(8)].map((_, i) => (
              <div key={i} className="h-24 bg-gray-200 rounded"></div>
            ))}
          </div>
          <div className="h-64 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 bg-gray-100 min-h-screen">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Dashboard Analytics - Plateforme KiloShare</h2>
        
        {/* Key Metrics */}
        {metrics && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            {/* Revenue Card */}
            <div className="bg-gradient-to-r from-green-400 to-green-600 p-6 rounded-lg text-white">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-3xl font-bold">
                    {formatCurrency(metrics.total_revenue)}
                  </div>
                  <div className="text-green-100">Revenus totaux</div>
                </div>
                <div className="bg-white bg-opacity-20 p-3 rounded-full">
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
                  </svg>
                </div>
              </div>
              <div className="mt-2 text-sm text-green-100">
                {formatPercentage(metrics.monthly_growth)} ce mois
              </div>
            </div>

            {/* Commission Card */}
            <div className="bg-gradient-to-r from-blue-400 to-blue-600 p-6 rounded-lg text-white">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-3xl font-bold">
                    {formatCurrency(metrics.total_commission)}
                  </div>
                  <div className="text-blue-100">Commission collectée</div>
                </div>
                <div className="bg-white bg-opacity-20 p-3 rounded-full">
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                </div>
              </div>
              <div className="mt-2 text-sm text-blue-100">
                {metrics.commission_rate}% taux moyen
              </div>
            </div>

            {/* Users Card */}
            <div className="bg-gradient-to-r from-purple-400 to-purple-600 p-6 rounded-lg text-white">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-3xl font-bold">{metrics.total_users.toLocaleString()}</div>
                  <div className="text-purple-100">Utilisateurs totaux</div>
                </div>
                <div className="bg-white bg-opacity-20 p-3 rounded-full">
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                  </svg>
                </div>
              </div>
              <div className="mt-2 text-sm text-purple-100">
                {metrics.active_users.toLocaleString()} actifs
              </div>
            </div>

            {/* Connected Accounts Card */}
            <div className="bg-gradient-to-r from-orange-400 to-orange-600 p-6 rounded-lg text-white">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-3xl font-bold">{metrics.connected_accounts}</div>
                  <div className="text-orange-100">Comptes connectés</div>
                </div>
                <div className="bg-white bg-opacity-20 p-3 rounded-full">
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                  </svg>
                </div>
              </div>
              <div className="mt-2 text-sm text-orange-100">
                {metrics.active_connected_accounts} actifs
              </div>
            </div>
          </div>
        )}

        {/* Secondary Metrics */}
        {metrics && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-gray-900">{metrics.total_trips.toLocaleString()}</div>
              <div className="text-sm text-gray-600">Voyages totaux</div>
              <div className="text-xs text-green-600 mt-1">
                {metrics.completed_trips.toLocaleString()} complétés
              </div>
            </div>
            
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-gray-900">{metrics.total_bookings.toLocaleString()}</div>
              <div className="text-sm text-gray-600">Réservations totales</div>
              <div className="text-xs text-blue-600 mt-1">
                {metrics.conversion_rate.toFixed(1)}% taux de conversion
              </div>
            </div>

            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-gray-900">
                {formatCurrency(metrics.stripe_fees)}
              </div>
              <div className="text-sm text-gray-600">Frais Stripe</div>
              <div className="text-xs text-gray-500 mt-1">
                Net: {formatCurrency(metrics.net_revenue)}
              </div>
            </div>

            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-yellow-600">{metrics.pending_transfers}</div>
              <div className="text-sm text-gray-600">Transferts en attente</div>
              <div className="text-xs text-yellow-600 mt-1">
                Nécessite attention
              </div>
            </div>
          </div>
        )}

        {/* Chart Section */}
        <div className="bg-white p-6 rounded-lg border">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">Tendances de la plateforme</h3>
            <div className="flex items-center space-x-2">
              <select
                value={timeframe}
                onChange={(e) => setTimeframe(e.target.value as any)}
                className="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
              >
                <option value="daily">Quotidien (7 jours)</option>
                <option value="weekly">Hebdomadaire (4 semaines)</option>
                <option value="monthly">Mensuel (12 mois)</option>
              </select>
            </div>
          </div>

          {/* Simple Chart Placeholder */}
          {trends && trends[timeframe] && (
            <div className="mt-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="text-center p-4 bg-gray-50 rounded-lg">
                  <div className="text-2xl font-bold text-gray-900">
                    {formatCurrency(trends[timeframe].reduce((sum, item) => sum + item.revenue, 0))}
                  </div>
                  <div className="text-sm text-gray-600">Revenus période</div>
                </div>
                <div className="text-center p-4 bg-gray-50 rounded-lg">
                  <div className="text-2xl font-bold text-gray-900">
                    {trends[timeframe].reduce((sum, item) => sum + item.transactions, 0).toLocaleString()}
                  </div>
                  <div className="text-sm text-gray-600">Transactions période</div>
                </div>
                <div className="text-center p-4 bg-gray-50 rounded-lg">
                  <div className="text-2xl font-bold text-gray-900">
                    {Math.max(...trends[timeframe].map(item => item.users)).toLocaleString()}
                  </div>
                  <div className="text-sm text-gray-600">Pic d'utilisateurs</div>
                </div>
              </div>

              {/* Data Table */}
              <div className="mt-6">
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Période
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Revenus
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Transactions
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Utilisateurs
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {trends[timeframe].slice(-10).map((item, index) => (
                        <tr key={index} className="hover:bg-gray-50">
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {timeframe === 'daily' ? new Date((item as any).date || '').toLocaleDateString('fr-FR') :
                             timeframe === 'weekly' ? (item as any).week :
                             (item as any).month}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            {formatCurrency(item.revenue)}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {item.transactions.toLocaleString()}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {item.users.toLocaleString()}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}