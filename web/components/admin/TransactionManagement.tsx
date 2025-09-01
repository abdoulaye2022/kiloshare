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
        setTransactions(data.transactions || []);
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
        setStats(data.stats);
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
    <div className="p-6">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Gestion des transactions</h2>
        
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-green-600">{stats.total_revenue?.toFixed(2) || '0.00'} €</div>
              <div className="text-sm text-gray-500">Revenus totaux</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-blue-600">{stats.total_commission?.toFixed(2) || '0.00'} €</div>
              <div className="text-sm text-gray-500">Commissions</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-yellow-600">{stats.pending_count || 0}</div>
              <div className="text-sm text-gray-500">En attente</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-red-600">{stats.failed_count || 0}</div>
              <div className="text-sm text-gray-500">Échouées</div>
            </div>
          </div>
        )}
        
        {/* Filters */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center space-x-4">
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value as any)}
              className="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="all">Tous les statuts</option>
              <option value="pending">En attente</option>
              <option value="completed">Complétées</option>
              <option value="failed">Échouées</option>
            </select>
            
            <select
              value={typeFilter}
              onChange={(e) => setTypeFilter(e.target.value as any)}
              className="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
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
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Transaction
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Utilisateur
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Montant
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Statut
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
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
                    <div className="text-sm text-gray-500">
                      {transaction.user?.email}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">
                      {transaction.amount.toFixed(2)} {transaction.currency}
                    </div>
                    <div className="text-sm text-gray-500">
                      Net: {transaction.net_amount.toFixed(2)} {transaction.currency}
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
                        <label className="text-sm font-medium text-gray-500">ID Transaction</label>
                        <p className="mt-1 text-sm text-gray-900 font-mono">{selectedTransaction.id}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Stripe ID</label>
                        <p className="mt-1 text-sm text-gray-900 font-mono">{selectedTransaction.stripe_transaction_id}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Type</label>
                        <div className="mt-1 flex items-center">
                          {getTypeIcon(selectedTransaction.type)}
                          <span className="ml-2 text-sm text-gray-900 capitalize">{selectedTransaction.type}</span>
                        </div>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Statut</label>
                        <div className="mt-1">{getStatusBadge(selectedTransaction.status)}</div>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Montant</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {selectedTransaction.amount.toFixed(2)} {selectedTransaction.currency}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Montant net</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {selectedTransaction.net_amount.toFixed(2)} {selectedTransaction.currency}
                        </p>
                      </div>
                      {selectedTransaction.stripe_fee && (
                        <div>
                          <label className="text-sm font-medium text-gray-500">Frais Stripe</label>
                          <p className="mt-1 text-sm text-gray-900">
                            {selectedTransaction.stripe_fee.toFixed(2)} {selectedTransaction.currency}
                          </p>
                        </div>
                      )}
                      {selectedTransaction.failure_reason && (
                        <div className="col-span-2">
                          <label className="text-sm font-medium text-gray-500">Raison de l'échec</label>
                          <p className="mt-1 text-sm text-red-600">{selectedTransaction.failure_reason}</p>
                        </div>
                      )}
                      <div>
                        <label className="text-sm font-medium text-gray-500">Date de création</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {new Date(selectedTransaction.created_at).toLocaleString('fr-FR')}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Dernière mise à jour</label>
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