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

  // Comptes Stripe
  total_stripe_accounts: number;
  active_stripe_accounts: number;
  pending_stripe_accounts: number;
  restricted_stripe_accounts: number;
  stripe_onboarding_rate: string | number;

  // Voyages
  total_trips: number;
  published_trips: number;
  pending_trips_count: number;
  completed_trips: number;
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
  trip_completion_rate: number | string;
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
      const token = await adminAuth.getValidAccessToken();

      if (!token) {
        return;
      }

      const response = await fetch('/api/v1/admin/dashboard/stats', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      if (response.ok) {
        const data = await response.json();
        setStats(data.data?.stats || data.stats);
        setCharts(data.data?.charts || data.charts);
        setError(null);
      } else {
        setError('Erreur lors du chargement des statistiques');
      }
    } catch (error) {
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
    color = 'primary',
    format = 'number'
  }: {
    title: string;
    value: number | string;
    change?: { value: number; label: string };
    icon: string;
    color?: 'primary' | 'success' | 'warning' | 'danger' | 'info';
    format?: 'number' | 'currency' | 'percentage';
  }) => {
    const colorClasses = {
      primary: 'bg-primary text-white',
      success: 'bg-success text-white',
      warning: 'bg-warning text-dark',
      danger: 'bg-danger text-white',
      info: 'bg-info text-white',
    };

    const formatValue = (val: number | string) => {
      if (typeof val === 'string') return val;
      if (val === undefined || val === null || isNaN(Number(val))) {
        return '0';
      }
      switch (format) {
        case 'currency':
          return formatCurrency(val);
        case 'percentage':
          return `${Number(val).toFixed(1)}%`;
        default:
          return formatNumber(val);
      }
    };

    return (
      <div className={`card h-100 ${colorClasses[color]}`}>
        <div className="card-body">
          <div className="d-flex justify-content-between align-items-center">
            <div>
              <h6 className="card-subtitle mb-2" style={{opacity: 0.7}}>{title}</h6>
              <h3 className="card-title mb-0">
                {formatValue(value)}
              </h3>
              {change && (
                <small className="mt-2 d-block" style={{opacity: 0.8}}>
                  {change.value > 0 ? '+' : ''}{change.value} {change.label}
                </small>
              )}
            </div>
            <div className="fs-1" style={{opacity: 0.3}}>
              {icon}
            </div>
          </div>
        </div>
      </div>
    );
  };

  const SimpleChart = ({
    data,
    title,
    color = '#0d6efd',
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
      <div className="card">
        <div className="card-body">
          <h5 className="card-title">{title}</h5>
          <div className="d-flex align-items-end gap-1" style={{height: '128px'}}>
            {lastWeekData.map((item, index) => {
              const height = maxValue > 0 ? (item[dataKey] || 0) / maxValue * 100 : 0;
              return (
                <div key={index} className="d-flex flex-column align-items-center flex-grow-1">
                  <div className="w-100 d-flex align-items-end justify-content-center">
                    <div
                      className="rounded-top"
                      style={{
                        width: '32px',
                        height: `${Math.max(height, 2)}%`,
                        backgroundColor: color,
                        minHeight: '4px'
                      }}
                      title={`${item.date}: ${item[dataKey] || 0}`}
                    />
                  </div>
                  <small className="text-muted mt-2 text-center">
                    {new Date(item.date).toLocaleDateString('fr-FR', {
                      day: 'numeric',
                      month: 'short'
                    })}
                  </small>
                </div>
              );
            })}
          </div>
          <div className="d-flex justify-content-between align-items-center mt-3 small text-muted">
            <span>7 derniers jours</span>
            <span className="fw-medium">
              Max: {dataKey === 'amount' ? formatCurrency(maxValue) : formatNumber(maxValue)}
            </span>
          </div>
        </div>
      </div>
    );
  };

  if (loading) {
    return (
      <div className="container-fluid p-4">
        <div className="d-flex justify-content-center align-items-center" style={{minHeight: '400px'}}>
          <div className="spinner-border text-primary" role="status">
            <span className="visually-hidden">Chargement...</span>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container-fluid p-4">
        <div className="alert alert-danger text-center">
          <div className="mb-3" style={{fontSize: '3rem'}}>⚠️</div>
          <h4 className="alert-heading">Erreur</h4>
          <p>{error}</p>
          <button
            onClick={fetchDashboardStats}
            className="btn btn-danger"
          >
            Réessayer
          </button>
        </div>
      </div>
    );
  }

  if (!stats) return null;

  return (
    <div className="container-fluid p-4">
      {/* Header */}
      <div className="row mb-4">
        <div className="col-12">
          <h1 className="h2 fw-bold mb-2">
            Tableau de bord
          </h1>
          <p className="text-muted">
            Vue d'ensemble de la plateforme KiloShare
          </p>
        </div>
      </div>

      {/* KPIs Principaux */}
      <div className="row g-4 mb-4">
        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Utilisateurs totaux"
            value={stats.total_users}
            change={{ value: stats.new_registrations_this_week, label: 'cette semaine' }}
            icon="👥"
            color="primary"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Voyages publiés"
            value={stats.published_trips}
            change={{ value: stats.published_trips_this_week, label: 'cette semaine' }}
            icon="✈️"
            color="success"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Réservations actives"
            value={stats.active_bookings}
            change={{ value: stats.bookings_this_week, label: 'cette semaine' }}
            icon="📦"
            color="warning"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Revenus ce mois"
            value={stats.revenue_this_month}
            change={{ value: stats.revenue_this_week, label: 'cette semaine' }}
            icon="💰"
            color="info"
            format="currency"
          />
        </div>
      </div>

      {/* Indicateurs secondaires */}
      <div className="row g-4 mb-4">
        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Utilisateurs vérifiés"
            value={stats.verified_users}
            icon="✅"
            color="success"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Voyages en attente"
            value={stats.pending_trips_count}
            icon="⏳"
            color="warning"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Taux de finalisation"
            value={stats.trip_completion_rate}
            icon="🎯"
            color="primary"
            format="percentage"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Commissions collectées"
            value={stats.commissions_collected}
            icon="🏦"
            color="info"
            format="currency"
          />
        </div>
      </div>

      {/* Statistiques Stripe */}
      <div className="row g-4 mb-4">
        <div className="col-12">
          <h3 className="h4 fw-bold mb-3">Comptes Stripe</h3>
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Total comptes Stripe"
            value={stats.total_stripe_accounts}
            icon="💳"
            color="primary"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Comptes actifs"
            value={stats.active_stripe_accounts}
            icon="✅"
            color="success"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Comptes en attente"
            value={stats.pending_stripe_accounts}
            icon="⏳"
            color="warning"
          />
        </div>

        <div className="col-lg-3 col-md-6">
          <StatCard
            title="Taux d'adoption"
            value={stats.stripe_onboarding_rate}
            icon="📊"
            color="info"
            format="percentage"
          />
        </div>
      </div>

      {/* Alertes */}
      {(stats.suspected_fraud_count > 0 || stats.urgent_disputes_count > 0 || stats.reported_trips_count > 0 || stats.failed_payments_count > 0) && (
        <div className="row mb-4">
          <div className="col-12">
            <div className="alert alert-danger">
              <h4 className="alert-heading d-flex align-items-center">
                <span className="me-2 fs-3">🚨</span>
                Alertes importantes
              </h4>
              <div className="row g-4 mt-2">
                {stats.suspected_fraud_count > 0 && (
                  <div className="col-lg-3 col-md-6 text-center">
                    <div className="h3 fw-bold text-danger">{stats.suspected_fraud_count}</div>
                    <div className="small">Fraudes suspectées</div>
                  </div>
                )}
                {stats.urgent_disputes_count > 0 && (
                  <div className="col-lg-3 col-md-6 text-center">
                    <div className="h3 fw-bold text-danger">{stats.urgent_disputes_count}</div>
                    <div className="small">Litiges urgents</div>
                  </div>
                )}
                {stats.reported_trips_count > 0 && (
                  <div className="col-lg-3 col-md-6 text-center">
                    <div className="h3 fw-bold text-danger">{stats.reported_trips_count}</div>
                    <div className="small">Voyages signalés</div>
                  </div>
                )}
                {stats.failed_payments_count > 0 && (
                  <div className="col-lg-3 col-md-6 text-center">
                    <div className="h3 fw-bold text-danger">{stats.failed_payments_count}</div>
                    <div className="small">Paiements échoués</div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Graphiques */}
      {charts && (
        <div className="row g-4">
          <div className="col-lg-6">
            <SimpleChart
              data={charts.user_growth}
              title="Croissance des utilisateurs"
              color="#0d6efd"
              dataKey="count"
            />
          </div>

          <div className="col-lg-6">
            <SimpleChart
              data={charts.trip_growth}
              title="Voyages publiés"
              color="#198754"
              dataKey="count"
            />
          </div>

          <div className="col-lg-6">
            <SimpleChart
              data={charts.booking_growth}
              title="Nouvelles réservations"
              color="#ffc107"
              dataKey="count"
            />
          </div>

          <div className="col-lg-6">
            <SimpleChart
              data={charts.revenue_growth}
              title="Revenus quotidiens"
              color="#0dcaf0"
              dataKey="amount"
            />
          </div>
        </div>
      )}
    </div>
  );
}