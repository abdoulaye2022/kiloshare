'use client';

import { useState, useEffect } from 'react';
import { useAdminAuthStore } from '../../stores/adminAuthStore';
import adminAuth from '../../lib/admin-auth';

interface DashboardStats {
  // KPIs principaux
  total_users: number;
  active_users: number;
  verified_users: number;
  new_registrations_today: number;
  new_registrations_this_week: number;
  
  // Voyages
  total_trips: number;
  published_trips: number;
  pending_trips_count: number;
  published_trips_today: number;
  published_trips_this_week: number;
  
  // Réservations
  total_bookings: number;
  active_bookings: number;
  bookings_today: number;
  bookings_this_week: number;
  
  // Financier
  revenue_today: number;
  revenue_this_week: number;
  revenue_this_month: number;
  commissions_collected: number;
  transactions_pending: number;
  
  // Indicateurs
  trip_completion_rate: number;
  dispute_rate: number;
  suspected_fraud_count: number;
  urgent_disputes_count: number;
  reported_trips_count: number;
  failed_payments_count: number;
}

interface ChartData {
  user_growth: Array<{date: string, count: number}>;
  trip_growth: Array<{date: string, count: number}>;
  booking_growth: Array<{date: string, count: number}>;
  revenue_growth: Array<{date: string, amount: number}>;
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [charts, setCharts] = useState<ChartData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  const { isAuthenticated } = useAdminAuthStore();

  useEffect(() => {
    if (isAuthenticated) {
      fetchDashboardStats();
      // Rafraîchir toutes les 5 minutes
      const interval = setInterval(fetchDashboardStats, 5 * 60 * 1000);
      return () => clearInterval(interval);
    }
  }, [isAuthenticated]);

  const fetchDashboardStats = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/dashboard/stats');
      
      if (response.ok) {
        const data = await response.json();
        console.log('Dashboard stats:', data);
        setStats(data.data?.stats || data.stats);
        setCharts(data.data?.charts || data.charts);
        setError(null);
      } else {
        console.error('Failed to fetch dashboard stats:', response.status);
        setError('Erreur lors du chargement des statistiques');
      }
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
      setError('Erreur de connexion');
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: 'CAD'
    }).format(amount || 0);
  };

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('fr-FR').format(num || 0);
  };

  const StatCard = ({ 
    title, 
    value, 
    change, 
    icon, 
    color = 'blue',
    format = 'number'
  }: {
    title: string;
    value: number | string;
    change?: { value: number; label: string };
    icon: string;
    color?: 'blue' | 'green' | 'orange' | 'red' | 'purple';
    format?: 'number' | 'currency' | 'percentage';
  }) => {
    const colorClasses = {
      blue: 'bg-blue-50 text-blue-700 border-blue-200',
      green: 'bg-green-50 text-green-700 border-green-200',
      orange: 'bg-orange-50 text-orange-700 border-orange-200',
      red: 'bg-red-50 text-red-700 border-red-200',
      purple: 'bg-purple-50 text-purple-700 border-purple-200',
    };

    const formatValue = (val: number | string) => {
      if (typeof val === 'string') return val;
      switch (format) {
        case 'currency':
          return formatCurrency(val);
        case 'percentage':
          return `${val.toFixed(1)}%`;
        default:
          return formatNumber(val);
      }
    };

    return (
      <div className={`p-6 rounded-lg border-2 ${colorClasses[color]}`}>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium opacity-70">{title}</p>
            <p className="text-2xl font-bold mt-2">
              {formatValue(value)}
            </p>
            {change && (
              <p className="text-sm mt-2 opacity-60">
                {change.value > 0 ? '+' : ''}{change.value} {change.label}
              </p>
            )}
          </div>
          <div className="text-3xl opacity-30">
            {icon}
          </div>
        </div>
      </div>
    );
  };

  const SimpleChart = ({ 
    data, 
    title, 
    color = '#3B82F6',
    dataKey = 'count'
  }: {
    data: Array<{date: string, count?: number, amount?: number}>;
    title: string;
    color?: string;
    dataKey?: 'count' | 'amount';
  }) => {
    if (!data || data.length === 0) return null;
    
    const maxValue = Math.max(...data.map(d => d[dataKey] || 0));
    const lastWeekData = data.slice(-7);

    return (
      <div className="p-6 bg-white rounded-lg border border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">{title}</h3>
        <div className="flex items-end space-x-2 h-32">
          {lastWeekData.map((item, index) => {
            const height = maxValue > 0 ? (item[dataKey] || 0) / maxValue * 100 : 0;
            return (
              <div key={index} className="flex flex-col items-center flex-1">
                <div className="w-full flex items-end justify-center">
                  <div
                    className="w-8 rounded-t"
                    style={{
                      height: `${Math.max(height, 2)}%`,
                      backgroundColor: color,
                      minHeight: '4px'
                    }}
                    title={`${item.date}: ${item[dataKey] || 0}`}
                  />
                </div>
                <div className="text-xs text-gray-500 mt-2 text-center">
                  {new Date(item.date).toLocaleDateString('fr-FR', { 
                    day: 'numeric',
                    month: 'short'
                  })}
                </div>
              </div>
            );
          })}
        </div>
        <div className="flex justify-between items-center mt-4 text-sm text-gray-600">
          <span>7 derniers jours</span>
          <span className="font-medium">
            Max: {dataKey === 'amount' ? formatCurrency(maxValue) : formatNumber(maxValue)}
          </span>
        </div>
      </div>
    );
  };

  if (loading) {
    return (
      <div className="p-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-64 mb-8"></div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {[...Array(8)].map((_, i) => (
              <div key={i} className="h-32 bg-gray-200 rounded-lg"></div>
            ))}
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-64 bg-gray-200 rounded-lg"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-8">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <div className="text-red-400 text-4xl mb-4">⚠️</div>
          <h3 className="text-lg font-semibold text-red-800 mb-2">Erreur</h3>
          <p className="text-red-600">{error}</p>
          <button
            onClick={fetchDashboardStats}
            className="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
          >
            Réessayer
          </button>
        </div>
      </div>
    );
  }

  if (!stats) return null;

  return (
    <div className="p-8 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">
          Tableau de bord
        </h1>
        <p className="text-gray-600">
          Vue d'ensemble de la plateforme KiloShare
        </p>
      </div>

      {/* KPIs Principaux */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="Utilisateurs totaux"
          value={stats.total_users}
          change={{ value: stats.new_registrations_this_week, label: 'cette semaine' }}
          icon="👥"
          color="blue"
        />
        
        <StatCard
          title="Voyages publiés"
          value={stats.published_trips}
          change={{ value: stats.published_trips_this_week, label: 'cette semaine' }}
          icon="✈️"
          color="green"
        />
        
        <StatCard
          title="Réservations actives"
          value={stats.active_bookings}
          change={{ value: stats.bookings_this_week, label: 'cette semaine' }}
          icon="📦"
          color="orange"
        />
        
        <StatCard
          title="Revenus ce mois"
          value={stats.revenue_this_month}
          change={{ value: stats.revenue_this_week, label: 'cette semaine' }}
          icon="💰"
          color="purple"
          format="currency"
        />
      </div>

      {/* Indicateurs secondaires */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="Utilisateurs vérifiés"
          value={stats.verified_users}
          icon="✅"
          color="green"
        />
        
        <StatCard
          title="Voyages en attente"
          value={stats.pending_trips_count}
          icon="⏳"
          color="orange"
        />
        
        <StatCard
          title="Taux de finalisation"
          value={stats.trip_completion_rate}
          icon="🎯"
          color="blue"
          format="percentage"
        />
        
        <StatCard
          title="Commissions collectées"
          value={stats.commissions_collected}
          icon="🏦"
          color="purple"
          format="currency"
        />
      </div>

      {/* Alertes */}
      {(stats.suspected_fraud_count > 0 || stats.urgent_disputes_count > 0 || stats.reported_trips_count > 0 || stats.failed_payments_count > 0) && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 mb-8">
          <h2 className="text-lg font-semibold text-red-800 mb-4 flex items-center">
            <span className="text-2xl mr-2">🚨</span>
            Alertes importantes
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {stats.suspected_fraud_count > 0 && (
              <div className="text-center">
                <div className="text-2xl font-bold text-red-700">{stats.suspected_fraud_count}</div>
                <div className="text-sm text-red-600">Fraudes suspectées</div>
              </div>
            )}
            {stats.urgent_disputes_count > 0 && (
              <div className="text-center">
                <div className="text-2xl font-bold text-red-700">{stats.urgent_disputes_count}</div>
                <div className="text-sm text-red-600">Litiges urgents</div>
              </div>
            )}
            {stats.reported_trips_count > 0 && (
              <div className="text-center">
                <div className="text-2xl font-bold text-red-700">{stats.reported_trips_count}</div>
                <div className="text-sm text-red-600">Voyages signalés</div>
              </div>
            )}
            {stats.failed_payments_count > 0 && (
              <div className="text-center">
                <div className="text-2xl font-bold text-red-700">{stats.failed_payments_count}</div>
                <div className="text-sm text-red-600">Paiements échoués</div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Graphiques */}
      {charts && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <SimpleChart
            data={charts.user_growth}
            title="Croissance des utilisateurs"
            color="#3B82F6"
            dataKey="count"
          />
          
          <SimpleChart
            data={charts.trip_growth}
            title="Voyages publiés"
            color="#10B981"
            dataKey="count"
          />
          
          <SimpleChart
            data={charts.booking_growth}
            title="Nouvelles réservations"
            color="#F59E0B"
            dataKey="count"
          />
          
          <SimpleChart
            data={charts.revenue_growth}
            title="Revenus quotidiens"
            color="#8B5CF6"
            dataKey="amount"
          />
        </div>
      )}
    </div>
  );
}