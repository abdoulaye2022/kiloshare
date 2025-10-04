'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface Transaction {
  id: string;
  stripe_transaction_id: string;
  user_id: number;
  trip_id?: number;
  booking_id?: number;
  amount: number;
  currency: string;
  type: 'payment' | 'refund' | 'commission' | 'payout';
  status: 'pending' | 'completed' | 'failed' | 'cancelled';
  failure_reason?: string;
  stripe_fee?: number;
  net_amount: number;
  created_at: string;
  updated_at: string;
  user?: {
    id: number;
    first_name: string;
    last_name: string;
    email: string;
  };
  trip?: {
    id: number;
    departure_city: string;
    arrival_city: string;
  };
}

interface TransactionManagementProps {
  adminInfo?: any;
}

export default function TransactionManagement({ adminInfo }: TransactionManagementProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'pending' | 'completed' | 'failed'>('all');
  const [typeFilter, setTypeFilter] = useState<'all' | 'payment' | 'refund' | 'commission' | 'payout'>('all');
  const [stats, setStats] = useState<any>(null);
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null);
  const [showTransactionDetails, setShowTransactionDetails] = useState(false);

  useEffect(() => {
    fetchTransactions();
    fetchStats();
  }, [filter, typeFilter]);

  const fetchTransactions = async () => {
    try {
      setLoading(true);
      const response = await adminAuth.apiRequest(
        `/api/v1/admin/payments/transactions?status=${filter}&type=${typeFilter}&limit=50`
      );

      if (response.ok) {
        const data = await response.json();
        const transactions = data.data?.transactions || data.transactions || [];
        setTransactions(transactions);
      } else {
        console.error('Failed to fetch transactions');
      }
    } catch (error) {
      console.error('Error fetching transactions:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/payments/stats');

      if (response.ok) {
        const data = await response.json();
        const stats = data.data?.stats || data.stats;
        setStats(stats);
      }
    } catch (error) {
      console.error('Error fetching transaction stats:', error);
    }
  };

  const handleRefund = async (transactionId: string, amount?: number) => {
    try {
      const refundAmount = amount || selectedTransaction?.amount;
      const response = await adminAuth.apiRequest(`/api/v1/admin/payments/transactions/${transactionId}/refund`, {
        method: 'POST',
        body: JSON.stringify({
          amount: refundAmount,
          reason: 'Admin refund'
        }),
      });

      if (response.ok) {
        fetchTransactions();
        fetchStats();
        setShowTransactionDetails(false);
      }
    } catch (error) {
      console.error('Error processing refund:', error);
    }
  };

  const getStatusBadge = (status: string) => {
    const badgeClasses = {
      pending: 'badge bg-warning text-dark',
      completed: 'badge bg-success',
      failed: 'badge bg-danger',
      cancelled: 'badge bg-secondary'
    };

    return (
      <span className={badgeClasses[status as keyof typeof badgeClasses] || 'badge bg-secondary'}>
        {status}
      </span>
    );
  };

  const getTypeIcon = (type: string) => {
    const icons = {
      payment: 'bi-credit-card text-success',
      refund: 'bi-arrow-counterclockwise text-danger',
      commission: 'bi-percent text-primary',
      payout: 'bi-arrow-up-right text-info'
    };

    return (
      <i className={`bi ${icons[type as keyof typeof icons] || 'bi-currency-dollar text-muted'}`}></i>
    );
  };

  const formatCurrency = (amount: number, currency: string = 'CAD') => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: currency
    }).format(amount);
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

  return (
    <div className="container-fluid p-4">
      {/* Header */}
      <div className="row mb-4">
        <div className="col-12">
          <div className="d-flex justify-content-between align-items-center mb-4">
            <div>
              <h2 className="h3 mb-0 fw-bold">Gestion des transactions</h2>
              <p className="text-muted mb-0">Gérez tous les paiements de la plateforme</p>
            </div>
          </div>
        </div>
      </div>

      {/* Stats */}
      {stats && (
        <div className="row g-3 mb-4">
          <div className="col-lg-3 col-md-6">
            <div className="card bg-success text-white h-100">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <h6 className="card-subtitle mb-2 text-white-50">Revenus totaux</h6>
                    <h4 className="card-title mb-0">{formatCurrency(stats.total_revenue || 0)}</h4>
                  </div>
                  <i className="bi bi-cash-stack fs-1 opacity-50"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-lg-3 col-md-6">
            <div className="card bg-primary text-white h-100">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <h6 className="card-subtitle mb-2 text-white-50">Commissions</h6>
                    <h4 className="card-title mb-0">{formatCurrency(stats.total_commission || 0)}</h4>
                  </div>
                  <i className="bi bi-percent fs-1 opacity-50"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-lg-3 col-md-6">
            <div className="card bg-warning text-dark h-100">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <h6 className="card-subtitle mb-2 opacity-75">En attente</h6>
                    <h4 className="card-title mb-0">{stats.pending_count || 0}</h4>
                  </div>
                  <i className="bi bi-clock fs-1 opacity-50"></i>
                </div>
              </div>
            </div>
          </div>
          <div className="col-lg-3 col-md-6">
            <div className="card bg-danger text-white h-100">
              <div className="card-body">
                <div className="d-flex justify-content-between align-items-center">
                  <div>
                    <h6 className="card-subtitle mb-2 text-white-50">Échouées</h6>
                    <h4 className="card-title mb-0">{stats.failed_count || 0}</h4>
                  </div>
                  <i className="bi bi-x-circle fs-1 opacity-50"></i>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="row mb-4">
        <div className="col-12">
          <div className="card">
            <div className="card-body">
              <div className="row g-3 align-items-center">
                <div className="col-md-4">
                  <label className="form-label fw-medium">Statut:</label>
                  <select
                    value={filter}
                    onChange={(e) => setFilter(e.target.value as any)}
                    className="form-select"
                  >
                    <option value="all">Tous les statuts</option>
                    <option value="pending">En attente</option>
                    <option value="completed">Complétées</option>
                    <option value="failed">Échouées</option>
                  </select>
                </div>

                <div className="col-md-4">
                  <label className="form-label fw-medium">Type:</label>
                  <select
                    value={typeFilter}
                    onChange={(e) => setTypeFilter(e.target.value as any)}
                    className="form-select"
                  >
                    <option value="all">Tous les types</option>
                    <option value="payment">Paiements</option>
                    <option value="refund">Remboursements</option>
                    <option value="commission">Commissions</option>
                    <option value="payout">Virements</option>
                  </select>
                </div>

                <div className="col-md-4">
                  <div className="text-center">
                    <div className="h4 mb-0 text-primary">{transactions.length}</div>
                    <small className="text-muted">transaction{transactions.length !== 1 ? 's' : ''}</small>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Transactions List */}
      <div className="row">
        <div className="col-12">
          <div className="card">
            <div className="card-header">
              <h5 className="card-title mb-0">
                <i className="bi bi-credit-card me-2"></i>
                Liste des transactions
              </h5>
            </div>
            <div className="card-body p-0">
              <div className="table-responsive">
                <table className="table table-hover mb-0">
                  <thead className="table-light">
                    <tr>
                      <th>Transaction</th>
                      <th>Utilisateur</th>
                      <th>Montant</th>
                      <th>Statut</th>
                      <th>Date</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {transactions.map((transaction) => (
                      <tr key={transaction.id}>
                        <td>
                          <div className="d-flex align-items-center">
                            {getTypeIcon(transaction.type)}
                            <div className="ms-3">
                              <div className="fw-medium">{transaction.stripe_transaction_id}</div>
                              <div className="text-muted small text-capitalize">{transaction.type}</div>
                            </div>
                          </div>
                        </td>
                        <td>
                          <div>
                            <div className="fw-medium">
                              {transaction.user?.first_name} {transaction.user?.last_name}
                            </div>
                            <div className="text-muted small">{transaction.user?.email}</div>
                          </div>
                        </td>
                        <td>
                          <div className="fw-medium">
                            {formatCurrency(transaction.amount, transaction.currency)}
                          </div>
                          <div className="text-muted small">
                            Net: {formatCurrency(transaction.net_amount, transaction.currency)}
                          </div>
                        </td>
                        <td>
                          {getStatusBadge(transaction.status)}
                        </td>
                        <td className="text-muted small">
                          {new Date(transaction.created_at).toLocaleDateString('fr-FR')}
                        </td>
                        <td>
                          <div className="btn-group btn-group-sm">
                            <button
                              onClick={() => {
                                setSelectedTransaction(transaction);
                                setShowTransactionDetails(true);
                              }}
                              className="btn btn-outline-primary"
                              title="Voir les détails"
                            >
                              <i className="bi bi-eye"></i>
                            </button>
                            {transaction.type === 'payment' && transaction.status === 'completed' && (
                              <button
                                onClick={() => handleRefund(transaction.id)}
                                className="btn btn-outline-danger"
                                title="Rembourser"
                              >
                                <i className="bi bi-arrow-counterclockwise"></i>
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Transaction Details Modal */}
      {showTransactionDetails && selectedTransaction && (
        <div className="modal show d-block" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog modal-lg modal-dialog-centered">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">
                  <i className="bi bi-credit-card me-2"></i>
                  Détails de la transaction
                </h5>
                <button
                  type="button"
                  className="btn-close"
                  onClick={() => setShowTransactionDetails(false)}
                ></button>
              </div>
              <div className="modal-body">
                <div className="row g-3">
                  <div className="col-md-6">
                    <label className="form-label fw-medium">ID Transaction</label>
                    <p className="mb-0 font-monospace small">{selectedTransaction.id}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Stripe ID</label>
                    <p className="mb-0 font-monospace small">{selectedTransaction.stripe_transaction_id}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Type</label>
                    <div className="d-flex align-items-center">
                      {getTypeIcon(selectedTransaction.type)}
                      <span className="ms-2 text-capitalize">{selectedTransaction.type}</span>
                    </div>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Statut</label>
                    <div>{getStatusBadge(selectedTransaction.status)}</div>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Montant</label>
                    <p className="mb-0 fw-medium">
                      {formatCurrency(selectedTransaction.amount, selectedTransaction.currency)}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Montant net</label>
                    <p className="mb-0 fw-medium">
                      {formatCurrency(selectedTransaction.net_amount, selectedTransaction.currency)}
                    </p>
                  </div>
                  {selectedTransaction.stripe_fee && (
                    <div className="col-md-6">
                      <label className="form-label fw-medium">Frais Stripe</label>
                      <p className="mb-0">
                        {formatCurrency(selectedTransaction.stripe_fee || 0, selectedTransaction.currency)}
                      </p>
                    </div>
                  )}
                  {selectedTransaction.failure_reason && (
                    <div className="col-12">
                      <label className="form-label fw-medium">Raison de l'échec</label>
                      <div className="alert alert-danger">{selectedTransaction.failure_reason}</div>
                    </div>
                  )}
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Date de création</label>
                    <p className="mb-0">
                      {new Date(selectedTransaction.created_at).toLocaleString('fr-FR')}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Dernière mise à jour</label>
                    <p className="mb-0">
                      {new Date(selectedTransaction.updated_at).toLocaleString('fr-FR')}
                    </p>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <div className="d-flex gap-2">
                  {selectedTransaction.type === 'payment' && selectedTransaction.status === 'completed' && (
                    <button
                      onClick={() => handleRefund(selectedTransaction.id)}
                      className="btn btn-danger"
                    >
                      <i className="bi bi-arrow-counterclockwise me-1"></i>
                      Rembourser
                    </button>
                  )}
                  <button
                    onClick={() => setShowTransactionDetails(false)}
                    className="btn btn-secondary"
                  >
                    Fermer
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}