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
  adminInfo: any;
}

export default function TransactionManagement({ adminInfo }: TransactionManagementProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'pending' | 'completed' | 'failed'>('all');
  const [typeFilter, setTypeFilter] = useState<'all' | 'payment' | 'refund' | 'commission' | 'payout'>('all');
  const [stats, setStats] = useState<any>(null);
  const [selectedTransaction, setSelectedTransaction] = useState<Transaction | null>(null);
  const [showTransactionDetails, setShowTransactionDetails] = useState(false);
  const [commissionStats, setCommissionStats] = useState<any>(null);
  const [platformAnalytics, setPlatformAnalytics] = useState<any>(null);
  const [showAnalytics, setShowAnalytics] = useState(false);

  useEffect(() => {
    fetchTransactions();
    fetchStats();
    fetchCommissionStats();
    fetchPlatformAnalytics();
  }, [filter, typeFilter]);

  const fetchTransactions = async () => {
    try {
      setLoading(true);
      const response = await adminAuth.apiRequest(
        `/api/v1/admin/payments/transactions?status=${filter}&type=${typeFilter}&limit=50`
      );
      
      if (response.ok) {
        const data = await response.json();
        console.log('Transactions API response:', data);
        // Handle nested data structure: data.data.transactions
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
        console.log('Stats API response:', data);
        // Handle nested data structure
        const stats = data.data?.stats || data.stats;
        setStats(stats);
      }
    } catch (error) {
      console.error('Error fetching transaction stats:', error);
    }
  };

  const fetchCommissionStats = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/payments/commission-stats');
      
      if (response.ok) {
        const data = await response.json();
        setCommissionStats(data.data?.stats);
      }
    } catch (error) {
      console.error('Error fetching commission stats:', error);
    }
  };

  const fetchPlatformAnalytics = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/analytics/platform');
      
      if (response.ok) {
        const data = await response.json();
        setPlatformAnalytics(data.data?.analytics);
      }
    } catch (error) {
      console.error('Error fetching platform analytics:', error);
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
      pending: 'bg-yellow-100 text-yellow-800',
      completed: 'bg-green-100 text-green-800',
      failed: 'bg-red-100 text-red-800',
      cancelled: 'bg-gray-100 text-gray-800'
    };
    
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${badgeClasses[status as keyof typeof badgeClasses]}`}>
        {status}
      </span>
    );
  };

  const getTypeIcon = (type: string) => {
    const iconClass = "w-4 h-4";
    switch (type) {
      case 'payment': 
        return (
          <svg className={`${iconClass} text-green-600`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
          </svg>
        );
      case 'refund':
        return (
          <svg className={`${iconClass} text-red-600`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 15v-1a4 4 0 00-4-4H8m0 0l3 3m-3-3l3-3" />
          </svg>
        );
      case 'commission':
        return (
          <svg className={`${iconClass} text-blue-600`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
          </svg>
        );
      case 'payout':
        return (
          <svg className={`${iconClass} text-purple-600`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
          </svg>
        );
      default:
        return (
          <svg className={`${iconClass} text-gray-600`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1" />
          </svg>
        );
    }
  };

  const formatCurrency = (amount: number, currency: string = 'CAD') => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: currency
    }).format(amount);
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-4"></div>
          <div className="grid grid-cols-4 gap-4 mb-6">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-20 bg-gray-200 rounded"></div>
            ))}
          </div>
          <div className="space-y-3">
            {[...Array(10)].map((_, i) => (
              <div key={i} className="h-16 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 bg-gray-100 min-h-screen">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Gestion des transactions</h2>
        
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-green-600">{formatCurrency(stats.total_revenue || 0)}</div>
              <div className="text-sm text-gray-600">Revenus totaux</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-blue-600">{formatCurrency(stats.total_commission || 0)}</div>
              <div className="text-sm text-gray-600">Commissions</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-yellow-600">{stats.pending_count || 0}</div>
              <div className="text-sm text-gray-600">En attente</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-red-600">{stats.failed_count || 0}</div>
              <div className="text-sm text-gray-600">Échouées</div>
            </div>
          </div>
        )}

        {/* Commission & Analytics Section */}
        {(commissionStats || platformAnalytics) && (
          <div className="mb-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-medium text-gray-900">Analytics de la plateforme</h3>
              <button
                onClick={() => setShowAnalytics(!showAnalytics)}
                className="text-blue-600 hover:text-blue-900 text-sm font-medium"
              >
                {showAnalytics ? 'Masquer' : 'Afficher'} les détails
              </button>
            </div>

            {/* Commission Stats */}
            {commissionStats && (
              <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
                <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                  <div className="text-2xl font-bold text-blue-600">
                    {formatCurrency(commissionStats.total_commission || 0)}
                  </div>
                  <div className="text-sm text-blue-700">Commission totale collectée</div>
                </div>
                <div className="bg-purple-50 p-4 rounded-lg border border-purple-200">
                  <div className="text-2xl font-bold text-purple-600">
                    {commissionStats.commission_rate || '0'}%
                  </div>
                  <div className="text-sm text-purple-700">Taux de commission moyen</div>
                </div>
                <div className="bg-indigo-50 p-4 rounded-lg border border-indigo-200">
                  <div className="text-2xl font-bold text-indigo-600">
                    {formatCurrency(commissionStats.monthly_commission || 0)}
                  </div>
                  <div className="text-sm text-indigo-700">Commission ce mois</div>
                </div>
                <div className="bg-teal-50 p-4 rounded-lg border border-teal-200">
                  <div className="text-2xl font-bold text-teal-600">
                    {commissionStats.commission_transactions || '0'}
                  </div>
                  <div className="text-sm text-teal-700">Transactions avec commission</div>
                </div>
              </div>
            )}

            {/* Expanded Analytics */}
            {showAnalytics && platformAnalytics && (
              <div className="bg-white p-6 rounded-lg border">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  {/* Volume Analytics */}
                  <div>
                    <h4 className="text-md font-medium text-gray-900 mb-3">Volume des transactions</h4>
                    <div className="space-y-3">
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Transactions aujourd'hui</span>
                        <span className="text-sm font-medium">{platformAnalytics.daily_transactions || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Transactions ce mois</span>
                        <span className="text-sm font-medium">{platformAnalytics.monthly_transactions || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Volume total traité</span>
                        <span className="text-sm font-medium">{formatCurrency(platformAnalytics.total_volume || 0)}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Valeur moyenne/transaction</span>
                        <span className="text-sm font-medium">{formatCurrency(platformAnalytics.avg_transaction_value || 0)}</span>
                      </div>
                    </div>
                  </div>

                  {/* User Analytics */}
                  <div>
                    <h4 className="text-md font-medium text-gray-900 mb-3">Utilisateurs actifs</h4>
                    <div className="space-y-3">
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Utilisateurs actifs</span>
                        <span className="text-sm font-medium">{platformAnalytics.active_users || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Nouveaux utilisateurs</span>
                        <span className="text-sm font-medium">{platformAnalytics.new_users || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Comptes connectés</span>
                        <span className="text-sm font-medium">{platformAnalytics.connected_accounts || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Taux de conversion</span>
                        <span className="text-sm font-medium">{platformAnalytics.conversion_rate?.toFixed(1) || '0.0'}%</span>
                      </div>
                    </div>
                  </div>

                  {/* Performance Analytics */}
                  <div>
                    <h4 className="text-md font-medium text-gray-900 mb-3">Performance</h4>
                    <div className="space-y-3">
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Taux de succès</span>
                        <span className="text-sm font-medium text-green-600">{platformAnalytics.success_rate?.toFixed(1) || '0.0'}%</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Taux d'échec</span>
                        <span className="text-sm font-medium text-red-600">{platformAnalytics.failure_rate?.toFixed(1) || '0.0'}%</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Remboursements</span>
                        <span className="text-sm font-medium">{platformAnalytics.refunds_count || 0}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-sm text-gray-600">Frais Stripe totaux</span>
                        <span className="text-sm font-medium">{formatCurrency(platformAnalytics.stripe_fees || 0)}</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Charts placeholder */}
                <div className="mt-6 pt-6 border-t">
                  <h4 className="text-md font-medium text-gray-900 mb-3">Tendances (7 derniers jours)</h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className="bg-gray-50 p-4 rounded-lg">
                      <div className="text-sm font-medium text-gray-700 mb-2">Volume quotidien</div>
                      <div className="text-2xl font-bold text-gray-900">
                        {formatCurrency(platformAnalytics.daily_trend?.volume || 0)}
                      </div>
                      <div className={`text-sm ${platformAnalytics.daily_trend?.volume_change >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                        {platformAnalytics.daily_trend?.volume_change >= 0 ? '+' : ''}
                        {platformAnalytics.daily_trend?.volume_change?.toFixed(1) || '0.0'}% par rapport à hier
                      </div>
                    </div>
                    <div className="bg-gray-50 p-4 rounded-lg">
                      <div className="text-sm font-medium text-gray-700 mb-2">Transactions quotidiennes</div>
                      <div className="text-2xl font-bold text-gray-900">
                        {platformAnalytics.daily_trend?.transactions || '0'}
                      </div>
                      <div className={`text-sm ${platformAnalytics.daily_trend?.transactions_change >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                        {platformAnalytics.daily_trend?.transactions_change >= 0 ? '+' : ''}
                        {platformAnalytics.daily_trend?.transactions_change?.toFixed(1) || '0.0'}% par rapport à hier
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}
        
        {/* Filters */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center space-x-4">
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value as any)}
              className="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 bg-white text-gray-900 selection:bg-blue-100 selection:text-blue-900"
            >
              <option value="all">Tous les statuts</option>
              <option value="pending">En attente</option>
              <option value="completed">Complétées</option>
              <option value="failed">Échouées</option>
            </select>
            
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value as any)}
              className="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 bg-white text-gray-900 selection:bg-blue-100 selection:text-blue-900"
            >
              <option value="all">Tous les types</option>
              <option value="payment">Paiements</option>
              <option value="refund">Remboursements</option>
              <option value="commission">Commissions</option>
              <option value="payout">Virements</option>
            </select>
          </div>
        </div>
      </div>

      {/* Transactions List */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Transaction
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Utilisateur
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Montant
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Statut
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {transactions.map((transaction) => (
                <tr key={transaction.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      {getTypeIcon(transaction.type)}
                      <div className="ml-3">
                        <div className="text-sm font-medium text-gray-900">
                          {transaction.stripe_transaction_id}
                        </div>
                        <div className="text-sm text-gray-500 capitalize">
                          {transaction.type}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">
                      {transaction.user?.first_name} {transaction.user?.last_name}
                    </div>
                    <div className="text-sm text-gray-600">
                      {transaction.user?.email}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">
                      {formatCurrency(transaction.amount, transaction.currency)}
                    </div>
                    <div className="text-sm text-gray-600">
                      Net: {formatCurrency(transaction.net_amount, transaction.currency)}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {getStatusBadge(transaction.status)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(transaction.created_at).toLocaleDateString('fr-FR')}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex items-center space-x-2">
                      <button
                        onClick={() => {
                          setSelectedTransaction(transaction);
                          setShowTransactionDetails(true);
                        }}
                        className="text-blue-600 hover:text-blue-900"
                      >
                        Détails
                      </button>
                      {transaction.type === 'payment' && transaction.status === 'completed' && (
                        <button
                          onClick={() => handleRefund(transaction.id)}
                          className="text-red-600 hover:text-red-900"
                        >
                          Rembourser
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

      {/* Transaction Details Modal */}
      {showTransactionDetails && selectedTransaction && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
              <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div className="sm:flex sm:items-start">
                  <div className="w-full">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg leading-6 font-medium text-gray-900">
                        Détails de la transaction
                      </h3>
                      <button
                        onClick={() => setShowTransactionDetails(false)}
                        className="text-gray-400 hover:text-gray-600"
                      >
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="text-sm font-medium text-gray-700">ID Transaction</label>
                        <p className="mt-1 text-sm text-gray-900 font-mono">{selectedTransaction.id}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Stripe ID</label>
                        <p className="mt-1 text-sm text-gray-900 font-mono">{selectedTransaction.stripe_transaction_id}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Type</label>
                        <div className="mt-1 flex items-center">
                          {getTypeIcon(selectedTransaction.type)}
                          <span className="ml-2 text-sm text-gray-900 capitalize">{selectedTransaction.type}</span>
                        </div>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Statut</label>
                        <div className="mt-1">{getStatusBadge(selectedTransaction.status)}</div>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Montant</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {formatCurrency(selectedTransaction.amount, selectedTransaction.currency)}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Montant net</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {formatCurrency(selectedTransaction.net_amount, selectedTransaction.currency)}
                        </p>
                      </div>
                      {selectedTransaction.stripe_fee && (
                        <div>
                          <label className="text-sm font-medium text-gray-700">Frais Stripe</label>
                          <p className="mt-1 text-sm text-gray-900">
                            {formatCurrency(selectedTransaction.stripe_fee || 0, selectedTransaction.currency)}
                          </p>
                        </div>
                      )}
                      {selectedTransaction.failure_reason && (
                        <div className="col-span-2">
                          <label className="text-sm font-medium text-gray-700">Raison de l'échec</label>
                          <p className="mt-1 text-sm text-red-600">{selectedTransaction.failure_reason}</p>
                        </div>
                      )}
                      <div>
                        <label className="text-sm font-medium text-gray-700">Date de création</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {new Date(selectedTransaction.created_at).toLocaleString('fr-FR')}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Dernière mise à jour</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {new Date(selectedTransaction.updated_at).toLocaleString('fr-FR')}
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <div className="flex space-x-3">
                  {selectedTransaction.type === 'payment' && selectedTransaction.status === 'completed' && (
                    <button
                      onClick={() => handleRefund(selectedTransaction.id)}
                      className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                    >
                      Rembourser
                    </button>
                  )}
                  <button
                    onClick={() => setShowTransactionDetails(false)}
                    className="bg-white hover:bg-gray-50 text-gray-900 px-4 py-2 rounded-md text-sm font-medium border border-gray-300"
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