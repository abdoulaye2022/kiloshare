'use client';

import { useState, useEffect } from 'react';
import { adminAPI } from '@/utils/adminApi';

interface Stats {
  users: {
    total: number;
    active: number;
    verified: number;
  };
  trips: {
    total: number;
    active: number;
    completed: number;
  };
  bookings: {
    total: number;
    pending: number;
    completed: number;
  };
  revenue: {
    total: number;
    commission: number;
  };
}

export default function StatsDetail() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      setLoading(true);
      const response = await adminAPI.get('/api/v1/admin/dashboard/stats');
      const data = await response.json();

      // Transformer les données pour notre format simplifié
      const dashboardStats = data.data?.stats || data.stats || {};

      setStats({
        users: {
          total: dashboardStats.total_users || 0,
          active: dashboardStats.active_users || 0,
          verified: dashboardStats.verified_users || 0,
        },
        trips: {
          total: dashboardStats.total_trips || 0,
          active: dashboardStats.active_trips || 0,
          completed: dashboardStats.completed_trips || 0,
        },
        bookings: {
          total: dashboardStats.total_bookings || 0,
          pending: dashboardStats.pending_bookings || 0,
          completed: dashboardStats.completed_bookings || 0,
        },
        revenue: {
          total: dashboardStats.total_revenue || 0,
          commission: dashboardStats.total_commission || 0,
        },
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: 'CAD',
    }).format(amount);
  };

  const calculatePercentage = (value: number, total: number) => {
    if (total === 0) return 0;
    return Math.round((value / total) * 100);
  };

  if (loading) {
    return (
      <div className="container-fluid p-4">
        <div className="text-center py-5">
          <div className="spinner-border text-primary" role="status">
            <span className="visually-hidden">Chargement...</span>
          </div>
        </div>
      </div>
    );
  }

  if (!stats) {
    return (
      <div className="container-fluid p-4">
        <div className="alert alert-warning">
          Impossible de charger les statistiques
        </div>
      </div>
    );
  }

  return (
    <div className="container-fluid p-4">
      <div className="mb-4">
        <h1 className="h2 fw-bold text-dark">Statistiques détaillées</h1>
        <p className="text-muted">
          Vue d'ensemble des statistiques de la plateforme KiloShare
        </p>
      </div>

      {/* Utilisateurs */}
      <div className="mb-4">
        <h5 className="mb-3">
          <i className="bi bi-people-fill text-primary me-2"></i>
          Utilisateurs
        </h5>
        <div className="row g-3">
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Total utilisateurs</p>
                    <h3 className="mb-0">{stats.users.total}</h3>
                  </div>
                  <i className="bi bi-people fs-1 text-primary opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Utilisateurs actifs</p>
                    <h3 className="mb-0 text-success">{stats.users.active}</h3>
                    <small className="text-muted">
                      {calculatePercentage(stats.users.active, stats.users.total)}%
                    </small>
                  </div>
                  <i className="bi bi-check-circle fs-1 text-success opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Utilisateurs vérifiés</p>
                    <h3 className="mb-0 text-info">{stats.users.verified}</h3>
                    <small className="text-muted">
                      {calculatePercentage(stats.users.verified, stats.users.total)}%
                    </small>
                  </div>
                  <i className="bi bi-shield-check fs-1 text-info opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Voyages */}
      <div className="mb-4">
        <h5 className="mb-3">
          <i className="bi bi-truck text-primary me-2"></i>
          Voyages
        </h5>
        <div className="row g-3">
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Total voyages</p>
                    <h3 className="mb-0">{stats.trips.total}</h3>
                  </div>
                  <i className="bi bi-truck fs-1 text-primary opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Voyages actifs</p>
                    <h3 className="mb-0 text-warning">{stats.trips.active}</h3>
                    <small className="text-muted">
                      {calculatePercentage(stats.trips.active, stats.trips.total)}%
                    </small>
                  </div>
                  <i className="bi bi-clock fs-1 text-warning opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Voyages complétés</p>
                    <h3 className="mb-0 text-success">{stats.trips.completed}</h3>
                    <small className="text-muted">
                      {calculatePercentage(stats.trips.completed, stats.trips.total)}%
                    </small>
                  </div>
                  <i className="bi bi-check-circle fs-1 text-success opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Réservations */}
      <div className="mb-4">
        <h5 className="mb-3">
          <i className="bi bi-box-seam text-primary me-2"></i>
          Réservations
        </h5>
        <div className="row g-3">
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Total réservations</p>
                    <h3 className="mb-0">{stats.bookings.total}</h3>
                  </div>
                  <i className="bi bi-box-seam fs-1 text-primary opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">En attente</p>
                    <h3 className="mb-0 text-warning">{stats.bookings.pending}</h3>
                    <small className="text-muted">
                      {calculatePercentage(stats.bookings.pending, stats.bookings.total)}%
                    </small>
                  </div>
                  <i className="bi bi-hourglass fs-1 text-warning opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-4">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Complétées</p>
                    <h3 className="mb-0 text-success">{stats.bookings.completed}</h3>
                    <small className="text-muted">
                      {calculatePercentage(stats.bookings.completed, stats.bookings.total)}%
                    </small>
                  </div>
                  <i className="bi bi-check-circle fs-1 text-success opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Revenus */}
      <div className="mb-4">
        <h5 className="mb-3">
          <i className="bi bi-currency-dollar text-primary me-2"></i>
          Revenus
        </h5>
        <div className="row g-3">
          <div className="col-md-6">
            <div className="card border-0 shadow-sm bg-primary text-white">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="mb-1 small opacity-75">Revenu total</p>
                    <h2 className="mb-0">{formatCurrency(stats.revenue.total)}</h2>
                  </div>
                  <i className="bi bi-graph-up-arrow fs-1 opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-6">
            <div className="card border-0 shadow-sm bg-success text-white">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="mb-1 small opacity-75">Commissions</p>
                    <h2 className="mb-0">{formatCurrency(stats.revenue.commission)}</h2>
                    <small className="opacity-75">
                      {calculatePercentage(stats.revenue.commission, stats.revenue.total)}% du total
                    </small>
                  </div>
                  <i className="bi bi-piggy-bank fs-1 opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
