'use client';

import { useState, useEffect } from 'react';
import { adminAPI } from '@/utils/adminApi';

interface ConnectedAccount {
  id: string;
  user_id: number;
  stripe_account_id: string;
  account_status: 'pending' | 'restricted' | 'active' | 'rejected';
  onboarding_complete: boolean;
  country: string;
  default_currency: string;
  email?: string;
  created_at: string;
  user?: {
    id: number;
    first_name: string;
    last_name: string;
    email: string;
  };
}

export default function ConnectedAccountsManagement() {
  const [accounts, setAccounts] = useState<ConnectedAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'active' | 'pending' | 'restricted' | 'rejected'>('all');
  const [stats, setStats] = useState<any>(null);

  useEffect(() => {
    fetchAccounts();
    fetchStats();
  }, [filter]);

  const fetchAccounts = async () => {
    try {
      setLoading(true);
      const response = await adminAPI.get(
        `/api/v1/admin/stripe/connected-accounts?status=${filter}&limit=50`
      );

      const data = await response.json();
      const accounts = data.data?.data?.accounts || data.data?.accounts || [];
      setAccounts(accounts);
    } catch (error) {
      console.error('Error fetching connected accounts:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await adminAPI.get('/api/v1/admin/stripe/connected-accounts/stats');
      const data = await response.json();
      setStats(data.data?.stats);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  const getStatusBadge = (status: string) => {
    const badges = {
      active: 'bg-success',
      pending: 'bg-warning',
      restricted: 'bg-danger',
      rejected: 'bg-secondary'
    };
    return badges[status as keyof typeof badges] || 'bg-secondary';
  };

  const getStatusText = (status: string) => {
    const texts = {
      active: 'Actif',
      pending: 'En attente',
      restricted: 'Restreint',
      rejected: 'Rejeté'
    };
    return texts[status as keyof typeof texts] || status;
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('fr-FR', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
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

  return (
    <div className="container-fluid p-4">
      <div className="mb-4">
        <h1 className="h2 fw-bold text-dark">Comptes Stripe Connectés</h1>
        <p className="text-muted">
          Gérez les comptes Stripe Connect des transporteurs
        </p>
      </div>

      {/* Stats Cards */}
      {stats && (
        <div className="row g-3 mb-4">
          <div className="col-md-3">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Total</p>
                    <h3 className="mb-0">{stats.total || 0}</h3>
                  </div>
                  <i className="bi bi-people fs-1 text-primary opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-3">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Actifs</p>
                    <h3 className="mb-0 text-success">{stats.active || 0}</h3>
                  </div>
                  <i className="bi bi-check-circle fs-1 text-success opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-3">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">En attente</p>
                    <h3 className="mb-0 text-warning">{stats.pending || 0}</h3>
                  </div>
                  <i className="bi bi-clock fs-1 text-warning opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-md-3">
            <div className="card border-0 shadow-sm">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <p className="text-muted mb-1 small">Restreints</p>
                    <h3 className="mb-0 text-danger">{stats.restricted || 0}</h3>
                  </div>
                  <i className="bi bi-exclamation-triangle fs-1 text-danger opacity-25"></i>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Filter Tabs */}
      <ul className="nav nav-pills mb-4">
        <li className="nav-item">
          <button
            className={`nav-link ${filter === 'all' ? 'active' : ''}`}
            onClick={() => setFilter('all')}
          >
            Tous
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${filter === 'active' ? 'active' : ''}`}
            onClick={() => setFilter('active')}
          >
            Actifs
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${filter === 'pending' ? 'active' : ''}`}
            onClick={() => setFilter('pending')}
          >
            En attente
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${filter === 'restricted' ? 'active' : ''}`}
            onClick={() => setFilter('restricted')}
          >
            Restreints
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${filter === 'rejected' ? 'active' : ''}`}
            onClick={() => setFilter('rejected')}
          >
            Rejetés
          </button>
        </li>
      </ul>

      {/* Accounts List */}
      {accounts.length === 0 ? (
        <div className="card">
          <div className="card-body text-center py-5">
            <i className="bi bi-inbox fs-1 text-muted mb-3 d-block"></i>
            <h5 className="card-title">Aucun compte trouvé</h5>
            <p className="card-text text-muted">
              Aucun compte Stripe connecté ne correspond aux critères sélectionnés.
            </p>
          </div>
        </div>
      ) : (
        <div className="card">
          <div className="table-responsive">
            <table className="table table-hover align-middle mb-0">
              <thead className="table-light">
                <tr>
                  <th>Utilisateur</th>
                  <th>Email</th>
                  <th>Pays</th>
                  <th>Devise</th>
                  <th>Statut</th>
                  <th>Onboarding</th>
                  <th>Date création</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {accounts.map((account) => (
                  <tr key={account.id}>
                    <td>
                      <div>
                        <div className="fw-semibold">
                          {account.user?.first_name} {account.user?.last_name}
                        </div>
                        <small className="text-muted">ID: {account.user_id}</small>
                      </div>
                    </td>
                    <td>
                      <small>{account.user?.email || account.email || '-'}</small>
                    </td>
                    <td>
                      <span className="badge bg-light text-dark">{account.country}</span>
                    </td>
                    <td>
                      <span className="badge bg-light text-dark">{account.default_currency}</span>
                    </td>
                    <td>
                      <span className={`badge ${getStatusBadge(account.account_status)}`}>
                        {getStatusText(account.account_status)}
                      </span>
                    </td>
                    <td>
                      {account.onboarding_complete ? (
                        <i className="bi bi-check-circle-fill text-success"></i>
                      ) : (
                        <i className="bi bi-x-circle-fill text-danger"></i>
                      )}
                    </td>
                    <td>
                      <small className="text-muted">{formatDate(account.created_at)}</small>
                    </td>
                    <td>
                      <a
                        href={`https://dashboard.stripe.com/connect/accounts/${account.stripe_account_id}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="btn btn-sm btn-outline-primary"
                      >
                        <i className="bi bi-box-arrow-up-right me-1"></i>
                        Voir sur Stripe
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
