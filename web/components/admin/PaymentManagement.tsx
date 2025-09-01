'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface Transaction {
  id: string;
  trip_id: string;
  booking_id: string;
  user_id: string;
  amount: number;
  currency: string;
  type: 'payment' | 'refund' | 'commission' | 'payout';
  status: 'pending' | 'completed' | 'failed' | 'cancelled';
  stripe_payment_intent_id?: string;
  stripe_transfer_id?: string;
  failure_reason?: string;
  created_at: string;
  updated_at: string;
  
  // Relations
  trip?: {
    departure_city: string;
    arrival_city: string;
    departure_date: string;
  };
  user?: {
    first_name: string;
    last_name: string;
    email: string;
  };
  booking?: {
    package_weight: number;
    total_price: number;
  };
}

interface PaymentStats {
  total_revenue_today: number;
  total_revenue_week: number;
  total_revenue_month: number;
  pending_payments_count: number;
  failed_payments_count: number;
  total_refunds_today: number;
  commission_rate: number;
  total_commission_collected: number;
}

interface PaymentManagementProps {
  adminInfo: any;
  onLogout: () => void;
}

export default function PaymentManagement({ adminInfo, onLogout }: PaymentManagementProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [stats, setStats] = useState<PaymentStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null);
  const [filter, setFilter] = useState<'all' | 'pending' | 'failed' | 'completed'>('all');
  const [typeFilter, setTypeFilter] = useState<'all' | 'payment' | 'refund' | 'commission' | 'payout'>('all');

  useEffect(() => {
    fetchTransactions();
    fetchPaymentStats();
    // Rafraîchir toutes les 30 secondes
    const interval = setInterval(() => {
      fetchTransactions();
      fetchPaymentStats();
    }, 30 * 1000);
    return () => clearInterval(interval);
  }, [filter, typeFilter]);

  const fetchTransactions = async () => {
    try {
      const queryParams = new URLSearchParams();
      if (filter !== 'all') queryParams.append('status', filter);
      if (typeFilter !== 'all') queryParams.append('type', typeFilter);
      
      const response = await adminAuth.apiRequest(`/api/admin/payments/transactions?${queryParams}`);
      
      if (response.ok) {
        const data = await response.json();
        if (data.success) {
          setTransactions(data.data.transactions || []);
        } else {
          console.error('API returned error:', data.message);
        }
      } else {
        console.error('Failed to fetch transactions - HTTP', response.status);
      }
    } catch (error) {
      console.error('Error fetching transactions:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchPaymentStats = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/admin/payments/stats');
      
      if (response.ok) {
        const data = await response.json();
        setStats(data.stats);
      }
    } catch (error) {
      console.error('Error fetching payment stats:', error);
    }
  };

  const handleRefund = async (transaction: Transaction) => {
    const reason = prompt('Raison du remboursement:');
    if (!reason) return;

    const amount = prompt(`Montant à rembourser (max: ${transaction.amount} ${transaction.currency}):`);
    if (!amount || parseFloat(amount) <= 0) return;

    try {
      const response = await adminAuth.apiRequest('/api/admin/transactions/refund', {
        method: 'POST',
        body: JSON.stringify({
          transaction_id: transaction.id,
          amount: parseFloat(amount),
          reason: reason
        }),
      });

      if (response.ok) {
        fetchTransactions();
        alert('Remboursement traité avec succès');
      } else {
        const error = await response.json();
        alert(`Erreur: ${error.message}`);
      }
    } catch (error) {
      console.error('Error processing refund:', error);
      alert('Erreur lors du traitement du remboursement');
    }
  };

  const handleRetryPayment = async (transaction: Transaction) => {
    if (!confirm('Êtes-vous sûr de vouloir relancer ce paiement ?')) return;

    try {
      const response = await adminAuth.apiRequest('/api/admin/transactions/retry', {
        method: 'POST',
        body: JSON.stringify({ transaction_id: transaction.id }),
      });

      if (response.ok) {
        fetchTransactions();
        alert('Paiement relancé avec succès');
      } else {
        const error = await response.json();
        alert(`Erreur: ${error.message}`);
      }
    } catch (error) {
      console.error('Error retrying payment:', error);
      alert('Erreur lors du relancement du paiement');
    }
  };

  const formatCurrency = (amount: number, currency: string = 'EUR') => {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: currency
    }).format(amount);
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed': return 'bg-green-100 text-green-800';
      case 'pending': return 'bg-yellow-100 text-yellow-800';
      case 'failed': return 'bg-red-100 text-red-800';
      case 'cancelled': return 'bg-gray-100 text-gray-800';
      default: return 'bg-blue-100 text-blue-800';
    }
  };

  const getTypeColor = (type: string) => {
    switch (type) {
      case 'payment': return 'bg-blue-100 text-blue-800';
      case 'refund': return 'bg-red-100 text-red-800';
      case 'commission': return 'bg-green-100 text-green-800';
      case 'payout': return 'bg-purple-100 text-purple-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getTypeIcon = (type: string) => {
    const iconClass = "w-4 h-4";
    switch (type) {
      case 'payment': 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
          </svg>
        );
      case 'refund': 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 15v-1a4 4 0 00-4-4H8m0 0l3 3m-3-3l3-3" />
          </svg>
        );
      case 'commission': 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2" />
          </svg>
        );
      case 'payout': 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16l-4-4m0 0l4-4m-4 4h18" />
          </svg>
        );
      default: 
        return (
          <svg className={iconClass} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2" />
          </svg>
        );
    }
  };

  const filteredTransactions = transactions.filter(tx => {
    if (filter !== 'all' && tx.status !== filter) return false;
    if (typeFilter !== 'all' && tx.type !== typeFilter) return false;
    return true;
  });

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">
                Gestion des Paiements
              </h1>
              <p className="text-sm text-gray-500">
                Transactions, remboursements et commissions • {filteredTransactions.length} transaction(s)
              </p>
            </div>
            <button
              onClick={onLogout}
              className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
            >
              <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
              Déconnexion
            </button>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          
          {/* Stats de Paiement */}
          {stats && (
            <div className="mb-8">
              <h2 className="text-2xl font-bold text-gray-900 mb-4">Statistiques Financières</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="bg-white p-6 rounded-lg shadow">
                  <div className="text-green-600 text-2xl font-bold">{formatCurrency(stats.total_revenue_today)}</div>
                  <div className="text-sm text-gray-600">Revenus aujourd'hui</div>
                </div>
                <div className="bg-white p-6 rounded-lg shadow">
                  <div className="text-green-600 text-2xl font-bold">{formatCurrency(stats.total_revenue_week)}</div>
                  <div className="text-sm text-gray-600">Revenus cette semaine</div>
                </div>
                <div className="bg-white p-6 rounded-lg shadow">
                  <div className="text-blue-600 text-2xl font-bold">{formatCurrency(stats.total_commission_collected)}</div>
                  <div className="text-sm text-gray-600">Commissions collectées</div>
                </div>
                <div className="bg-white p-6 rounded-lg shadow">
                  <div className="text-orange-600 text-2xl font-bold">{stats.pending_payments_count}</div>
                  <div className="text-sm text-gray-600">Paiements en attente</div>
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
                <div className="bg-white p-6 rounded-lg shadow">
                  <div className="text-red-600 text-2xl font-bold">{stats.failed_payments_count}</div>
                  <div className="text-sm text-gray-600">Paiements échoués</div>
                </div>
                <div className="bg-white p-6 rounded-lg shadow">
                  <div className="text-red-600 text-2xl font-bold">{formatCurrency(stats.total_refunds_today)}</div>
                  <div className="text-sm text-gray-600">Remboursements aujourd'hui</div>
                </div>
                <div className="bg-white p-6 rounded-lg shadow">
                  <div className="text-purple-600 text-2xl font-bold">{stats.commission_rate}%</div>
                  <div className="text-sm text-gray-600">Taux de commission</div>
                </div>
              </div>
            </div>
          )}

          {/* Filtres */}
          <div className="mb-6 flex flex-wrap gap-4 items-center justify-between">
            <div className="flex flex-wrap gap-4 items-center">
              <div>
                <label className="text-sm font-medium text-gray-700 mr-2">Statut :</label>
                <select
                  value={filter}
                  onChange={(e) => setFilter(e.target.value as any)}
                  className="border border-gray-300 rounded-md px-3 py-1 text-sm"
                >
                  <option value="all">Tous</option>
                  <option value="pending">En attente</option>
                  <option value="completed">Terminés</option>
                  <option value="failed">Échoués</option>
                </select>
              </div>
              
              <div>
                <label className="text-sm font-medium text-gray-700 mr-2">Type :</label>
                <select
                  value={typeFilter}
                  onChange={(e) => setTypeFilter(e.target.value as any)}
                  className="border border-gray-300 rounded-md px-3 py-1 text-sm"
                >
                  <option value="all">Tous</option>
                  <option value="payment">Paiements</option>
                  <option value="refund">Remboursements</option>
                  <option value="commission">Commissions</option>
                  <option value="payout">Virements</option>
                </select>
              </div>
            </div>

            <button
              onClick={() => {
                fetchTransactions();
                fetchPaymentStats();
              }}
              className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium flex items-center gap-2"
            >
              🔄 Actualiser
            </button>
          </div>

          {/* Liste des Transactions */}
          {filteredTransactions.length === 0 ? (
            <div className="text-center py-12">
              <div className="mb-4">
                <svg className="w-16 h-16 text-gray-400 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
                </svg>
              </div>
              <p className="text-gray-500 text-lg">Aucune transaction trouvée</p>
            </div>
          ) : (
            <div className="bg-white shadow rounded-lg overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-200">
                <h3 className="text-lg font-medium text-gray-900">
                  Transactions ({filteredTransactions.length})
                </h3>
              </div>
              
              <div className="divide-y divide-gray-200">
                {filteredTransactions.map((transaction) => (
                  <div key={transaction.id} className="p-6 hover:bg-gray-50">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-4">
                        <div className="text-2xl">
                          {getTypeIcon(transaction.type)}
                        </div>
                        
                        <div>
                          <div className="flex items-center space-x-2">
                            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getTypeColor(transaction.type)}`}>
                              {transaction.type}
                            </span>
                            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor(transaction.status)}`}>
                              {transaction.status}
                            </span>
                          </div>
                          
                          <div className="mt-1">
                            <p className="text-sm font-medium text-gray-900">
                              {formatCurrency(transaction.amount, transaction.currency)}
                            </p>
                            <p className="text-sm text-gray-500">
                              {transaction.user?.first_name} {transaction.user?.last_name} ({transaction.user?.email})
                            </p>
                          </div>
                          
                          {transaction.trip && (
                            <p className="text-xs text-gray-400 mt-1">
                              {transaction.trip.departure_city} → {transaction.trip.arrival_city} • 
                              {new Date(transaction.trip.departure_date).toLocaleDateString('fr-FR')}
                            </p>
                          )}
                          
                          {transaction.failure_reason && (
                            <p className="text-xs text-red-600 mt-1">
                              <svg className="w-4 h-4 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                              </svg>
                              {transaction.failure_reason}
                            </p>
                          )}
                        </div>
                      </div>

                      <div className="flex items-center space-x-2">
                        <div className="text-right text-xs text-gray-500">
                          <div>{new Date(transaction.created_at).toLocaleDateString('fr-FR')}</div>
                          <div>{new Date(transaction.created_at).toLocaleTimeString('fr-FR')}</div>
                        </div>
                        
                        <div className="flex space-x-2">
                          {transaction.status === 'completed' && transaction.type === 'payment' && (
                            <button
                              onClick={() => handleRefund(transaction)}
                              className="bg-red-100 hover:bg-red-200 text-red-800 px-3 py-1 rounded text-xs font-medium"
                            >
                              Rembourser
                            </button>
                          )}
                          
                          {transaction.status === 'failed' && (
                            <button
                              onClick={() => handleRetryPayment(transaction)}
                              className="bg-blue-100 hover:bg-blue-200 text-blue-800 px-3 py-1 rounded text-xs font-medium"
                            >
                              Relancer
                            </button>
                          )}
                          
                          <button
                            onClick={() => setSelectedTransaction(transaction)}
                            className="bg-gray-100 hover:bg-gray-200 text-gray-800 px-3 py-1 rounded text-xs font-medium"
                          >
                            Détails
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </main>

      {/* Modal de détails */}
      {selectedTransaction && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-2xl w-full max-h-96 overflow-y-auto">
            <div className="p-6">
              <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-medium text-gray-900">
                  Détails de la transaction
                </h3>
                <button
                  onClick={() => setSelectedTransaction(null)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              
              <div className="space-y-4">
                <div>
                  <strong>ID:</strong> {selectedTransaction.id}
                </div>
                <div>
                  <strong>Montant:</strong> {formatCurrency(selectedTransaction.amount, selectedTransaction.currency)}
                </div>
                <div>
                  <strong>Type:</strong> {selectedTransaction.type}
                </div>
                <div>
                  <strong>Statut:</strong> {selectedTransaction.status}
                </div>
                {selectedTransaction.stripe_payment_intent_id && (
                  <div>
                    <strong>Stripe Payment Intent:</strong> {selectedTransaction.stripe_payment_intent_id}
                  </div>
                )}
                <div>
                  <strong>Créé le:</strong> {new Date(selectedTransaction.created_at).toLocaleString('fr-FR')}
                </div>
                <div>
                  <strong>Mis à jour le:</strong> {new Date(selectedTransaction.updated_at).toLocaleString('fr-FR')}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}