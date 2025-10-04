'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface ConnectedAccount {
  id: string;
  user_id: number;
  stripe_account_id: string;
  account_status: 'pending' | 'restricted' | 'active' | 'rejected';
  onboarding_complete: boolean;
  capabilities?: {
    card_payments?: 'active' | 'inactive' | 'pending';
    transfers?: 'active' | 'inactive' | 'pending';
  };
  country: string;
  default_currency: string;
  email?: string;
  business_type?: string;
  created_at: string;
  updated_at: string;
  user?: {
    id: number;
    first_name: string;
    last_name: string;
    email: string;
  };
  balance?: {
    available: number;
    pending: number;
  };
  requirements?: {
    currently_due: string[];
    eventually_due: string[];
    past_due: string[];
    pending_verification: string[];
  };
}

export default function ConnectedAccountsManagement() {
  const [accounts, setAccounts] = useState<ConnectedAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'active' | 'pending' | 'restricted' | 'rejected'>('all');
  const [selectedAccount, setSelectedAccount] = useState<ConnectedAccount | null>(null);
  const [showAccountDetails, setShowAccountDetails] = useState(false);
  const [stats, setStats] = useState<any>(null);
  const [pendingTransfers, setPendingTransfers] = useState<any[]>([]);
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [selectedTransfer, setSelectedTransfer] = useState<any>(null);

  useEffect(() => {
    fetchAccounts();
    fetchStats();
    fetchPendingTransfers();
  }, [filter]);

  const fetchAccounts = async () => {
    try {
      setLoading(true);
      const response = await adminAuth.apiRequest(
        `/api/v1/admin/stripe/connected-accounts?status=${filter}&limit=50`
      );
      
      if (response.ok) {
        const data = await response.json();
        // Handle nested data structure: data.data.accounts
        const accounts = data.data?.data?.accounts || data.data?.accounts || [];
        setAccounts(accounts);
      } else {
        console.error('Failed to fetch connected accounts');
      }
    } catch (error) {
      console.error('Error fetching connected accounts:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/stripe/connected-accounts/stats');
      
      if (response.ok) {
        const data = await response.json();
        setStats(data.data?.stats);
      }
    } catch (error) {
      console.error('Error fetching connected accounts stats:', error);
    }
  };

  const fetchPendingTransfers = async () => {
    try {
      const response = await adminAuth.apiRequest('/api/v1/admin/payments/pending-transfers');
      
      if (response.ok) {
        const data = await response.json();
        setPendingTransfers(data.data?.transfers || data.transfers || []);
      }
    } catch (error) {
      console.error('Error fetching pending transfers:', error);
    }
  };

  const handleAccountAction = async (accountId: string, action: 'enable' | 'disable' | 'review') => {
    try {
      const response = await adminAuth.apiRequest(`/api/v1/admin/stripe/connected-accounts/${accountId}/action`, {
        method: 'POST',
        body: JSON.stringify({ action: action })
      });

      if (response.ok) {
        fetchAccounts();
        fetchStats();
        if (selectedAccount && selectedAccount.id === accountId) {
          setSelectedAccount(null);
          setShowAccountDetails(false);
        }
      }
    } catch (error) {
      console.error(`Error ${action}ing account:`, error);
    }
  };

  const handleTransferPayment = async (transferId: string, action: 'approve' | 'reject' | 'force') => {
    try {
      const response = await adminAuth.apiRequest(`/api/v1/admin/payments/transfers/${transferId}/${action}`, {
        method: 'POST',
        body: JSON.stringify({ 
          reason: action === 'approve' ? 'Admin approved transfer' : 
                 action === 'force' ? 'Admin forced transfer (24h passed)' : 'Admin rejected transfer'
        })
      });

      if (response.ok) {
        const result = await response.json();
        
        // Show success message
        if (action === 'approve') {
          alert(`Transfert approuvé avec succès ! Montant transféré: ${result.data?.amount_transferred?.toFixed(2)} CAD`);
        } else if (action === 'force') {
          alert(`Transfert forcé avec succès ! Montant transféré: ${result.data?.amount_transferred?.toFixed(2)} CAD`);
        } else {
          alert('Transfert rejeté avec succès');
        }
        
        fetchPendingTransfers();
        fetchStats();
        setShowTransferModal(false);
        setSelectedTransfer(null);
      } else {
        const errorData = await response.json();
        console.error('Transfer action failed:', errorData);
        alert(`Erreur lors du transfert: ${errorData.message || 'Une erreur inconnue s\'est produite'}`);
      }
    } catch (error) {
      console.error(`Error ${action}ing transfer:`, error);
    }
  };

  const formatCurrency = (amount: number, currency: string = 'CAD') => {
    return new Intl.NumberFormat('fr-CA', {
      style: 'currency',
      currency: currency
    }).format(amount);
  };

  const getStatusBadge = (status: string) => {
    const badgeClasses = {
      active: 'bg-green-100 text-green-800',
      pending: 'bg-yellow-100 text-yellow-800',
      restricted: 'bg-orange-100 text-orange-800',
      rejected: 'bg-red-100 text-red-800'
    };
    
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${badgeClasses[status as keyof typeof badgeClasses]}`}>
        {status === 'active' ? 'Actif' :
         status === 'pending' ? 'En attente' :
         status === 'restricted' ? 'Restreint' :
         status === 'rejected' ? 'Rejeté' : status}
      </span>
    );
  };

  const getCapabilityBadge = (capability: string) => {
    const badgeClasses = {
      active: 'bg-green-100 text-green-800',
      inactive: 'bg-red-100 text-red-800',
      pending: 'bg-yellow-100 text-yellow-800'
    };
    
    return (
      <span className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium ${badgeClasses[capability as keyof typeof badgeClasses]}`}>
        {capability === 'active' ? 'Actif' :
         capability === 'pending' ? 'En attente' :
         capability === 'inactive' ? 'Inactif' : capability}
      </span>
    );
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
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Comptes connectés Stripe</h2>
        
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-green-600">{stats.active_count || 0}</div>
              <div className="text-sm text-gray-600">Comptes actifs</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-yellow-600">{stats.pending_count || 0}</div>
              <div className="text-sm text-gray-600">En attente</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-orange-600">{stats.restricted_count || 0}</div>
              <div className="text-sm text-gray-600">Restreints</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-blue-600">{formatCurrency(stats.total_balance || 0)}</div>
              <div className="text-sm text-gray-600">Solde total</div>
            </div>
          </div>
        )}

        {/* Pending Transfers Alert */}
        {pendingTransfers.length > 0 && (
          <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 mb-6">
            <div className="flex items-center justify-between">
              <div className="flex">
                <div className="flex-shrink-0">
                  <svg className="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-yellow-800">
                    Transferts en attente
                  </h3>
                  <div className="mt-2 text-sm text-yellow-700">
                    <p>{pendingTransfers.length} transfert(s) en attente d'approbation ou prêt(s) à être effectué(s).</p>
                  </div>
                </div>
              </div>
              <button
                onClick={() => setShowTransferModal(true)}
                className="bg-yellow-100 hover:bg-yellow-200 text-yellow-800 px-3 py-1 rounded-md text-sm font-medium"
              >
                Gérer les transferts
              </button>
            </div>
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
              <option value="all">Tous les comptes</option>
              <option value="active">Actifs</option>
              <option value="pending">En attente</option>
              <option value="restricted">Restreints</option>
              <option value="rejected">Rejetés</option>
            </select>
          </div>
        </div>
      </div>

      {/* Accounts List */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Utilisateur
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Compte Stripe
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Statut
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Capacités
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Solde
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {accounts.map((account) => (
                <tr key={account.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 h-10 w-10">
                        <div className="h-10 w-10 rounded-full bg-blue-500 flex items-center justify-center">
                          <span className="text-white font-medium text-sm">
                            {account.user?.first_name?.[0]}{account.user?.last_name?.[0]}
                          </span>
                        </div>
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-gray-900">
                          {account.user?.first_name} {account.user?.last_name}
                        </div>
                        <div className="text-sm text-gray-600">{account.user?.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900 font-mono">{account.stripe_account_id}</div>
                    <div className="text-sm text-gray-600">{account.country} • {account.default_currency}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex flex-col space-y-1">
                      {getStatusBadge(account.account_status)}
                      {account.onboarding_complete ? (
                        <span className="text-xs text-green-600">✓ Onboarding terminé</span>
                      ) : (
                        <span className="text-xs text-orange-600">⚠ Onboarding en cours</span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex flex-col space-y-1">
                      {account.capabilities?.card_payments && (
                        <div className="flex items-center space-x-2">
                          <span className="text-xs text-gray-500">Paiements:</span>
                          {getCapabilityBadge(account.capabilities.card_payments)}
                        </div>
                      )}
                      {account.capabilities?.transfers && (
                        <div className="flex items-center space-x-2">
                          <span className="text-xs text-gray-500">Virements:</span>
                          {getCapabilityBadge(account.capabilities.transfers)}
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {account.balance ? (
                      <div className="text-sm text-gray-900">
                        <div>Disponible: {formatCurrency(account.balance.available)}</div>
                        <div className="text-xs text-gray-500">
                          En attente: {formatCurrency(account.balance.pending)}
                        </div>
                      </div>
                    ) : (
                      <div className="text-sm text-gray-600">N/A</div>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex items-center space-x-2">
                      <button
                        onClick={() => {
                          setSelectedAccount(account);
                          setShowAccountDetails(true);
                        }}
                        className="text-blue-600 hover:text-blue-900"
                      >
                        Détails
                      </button>
                      {account.account_status === 'active' && (
                        <button
                          onClick={() => handleAccountAction(account.id, 'disable')}
                          className="text-red-600 hover:text-red-900"
                        >
                          Désactiver
                        </button>
                      )}
                      {account.account_status === 'restricted' && (
                        <button
                          onClick={() => handleAccountAction(account.id, 'review')}
                          className="text-green-600 hover:text-green-900"
                        >
                          Réviser
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

      {/* Account Details Modal */}
      {showAccountDetails && selectedAccount && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
              <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div className="sm:flex sm:items-start">
                  <div className="w-full">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg leading-6 font-medium text-gray-900">
                        Détails du compte connecté
                      </h3>
                      <button
                        onClick={() => setShowAccountDetails(false)}
                        className="text-gray-400 hover:text-gray-600"
                      >
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>

                    <div className="grid grid-cols-2 gap-6 mb-6">
                      <div>
                        <label className="text-sm font-medium text-gray-700">ID Compte Stripe</label>
                        <p className="mt-1 text-sm text-gray-900 font-mono">{selectedAccount.stripe_account_id}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Statut</label>
                        <div className="mt-1">{getStatusBadge(selectedAccount.account_status)}</div>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Pays</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedAccount.country}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Devise par défaut</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedAccount.default_currency}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Type d'entreprise</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedAccount.business_type || 'Non spécifié'}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Email</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedAccount.email || 'Non spécifié'}</p>
                      </div>
                    </div>

                    {selectedAccount.requirements && (
                      <div className="mb-6">
                        <h4 className="text-md font-medium text-gray-900 mb-3">Exigences</h4>
                        <div className="grid grid-cols-2 gap-4">
                          <div>
                            <label className="text-sm font-medium text-red-500">Exigences actuelles</label>
                            <div className="mt-1">
                              {selectedAccount.requirements.currently_due && selectedAccount.requirements.currently_due.length > 0 ? (
                                <ul className="text-sm text-red-600 list-disc list-inside">
                                  {selectedAccount.requirements.currently_due.map((req, index) => (
                                    <li key={index}>{req}</li>
                                  ))}
                                </ul>
                              ) : (
                                <p className="text-sm text-green-600">Aucune</p>
                              )}
                            </div>
                          </div>
                          <div>
                            <label className="text-sm font-medium text-yellow-500">Exigences futures</label>
                            <div className="mt-1">
                              {selectedAccount.requirements.eventually_due.length > 0 ? (
                                <ul className="text-sm text-yellow-600 list-disc list-inside">
                                  {selectedAccount.requirements.eventually_due.map((req, index) => (
                                    <li key={index}>{req}</li>
                                  ))}
                                </ul>
                              ) : (
                                <p className="text-sm text-green-600">Aucune</p>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    )}

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="text-sm font-medium text-gray-700">Date de création</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {new Date(selectedAccount.created_at).toLocaleDateString('fr-FR')}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-700">Dernière mise à jour</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {new Date(selectedAccount.updated_at).toLocaleDateString('fr-FR')}
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <div className="flex space-x-3">
                  {selectedAccount.account_status === 'active' && (
                    <button
                      onClick={() => handleAccountAction(selectedAccount.id, 'disable')}
                      className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                    >
                      Désactiver le compte
                    </button>
                  )}
                  {selectedAccount.account_status === 'restricted' && (
                    <button
                      onClick={() => handleAccountAction(selectedAccount.id, 'review')}
                      className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                    >
                      Réviser le compte
                    </button>
                  )}
                  <button
                    onClick={() => setShowAccountDetails(false)}
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

      {/* Transfer Management Modal */}
      {showTransferModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-6xl sm:w-full">
              <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div className="sm:flex sm:items-start">
                  <div className="w-full">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg leading-6 font-medium text-gray-900">
                        Gestion des transferts de paiement
                      </h3>
                      <button
                        onClick={() => setShowTransferModal(false)}
                        className="text-gray-400 hover:text-gray-600"
                      >
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>

                    <div className="mb-4">
                      <p className="text-sm text-gray-600">
                        Voici les transferts en attente d'approbation vers les comptes connectés des transporteurs.
                        Les transferts peuvent être effectués automatiquement 24h après la livraison confirmée.
                      </p>
                    </div>

                    {/* Transfers Table */}
                    <div className="overflow-x-auto">
                      <table className="min-w-full divide-y divide-gray-200">
                        <thead className="bg-gray-50">
                          <tr>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                              Voyage
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                              Transporteur
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                              Montant
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                              Statut
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                              Délai
                            </th>
                            <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                              Actions
                            </th>
                          </tr>
                        </thead>
                        <tbody className="bg-white divide-y divide-gray-200">
                          {pendingTransfers.map((transfer) => {
                            const canForceTransfer = transfer.hours_since_delivery >= 24;
                            const hoursLeft = Math.max(0, 24 - transfer.hours_since_delivery);
                            
                            return (
                              <tr key={transfer.id} className="hover:bg-gray-50">
                                <td className="px-6 py-4 whitespace-nowrap">
                                  <div className="text-sm font-medium text-gray-900">
                                    {transfer.trip?.departure_city} → {transfer.trip?.arrival_city}
                                  </div>
                                  <div className="text-sm text-gray-600">
                                    #{transfer.trip?.id}
                                  </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                  <div className="text-sm text-gray-900">
                                    {transfer.transporter?.first_name} {transfer.transporter?.last_name}
                                  </div>
                                  <div className="text-sm text-gray-600">
                                    {transfer.transporter?.email}
                                  </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                  <div className="text-sm font-medium text-gray-900">
                                    {formatCurrency(transfer.amount, transfer.currency)}
                                  </div>
                                  <div className="text-sm text-gray-600">
                                    Commission: {formatCurrency(transfer.commission, transfer.currency)}
                                  </div>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                  <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                                    transfer.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                                    transfer.status === 'ready' ? 'bg-green-100 text-green-800' :
                                    'bg-gray-100 text-gray-800'
                                  }`}>
                                    {transfer.status === 'pending' ? 'En attente' :
                                     transfer.status === 'ready' ? 'Prêt' : transfer.status}
                                  </span>
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap">
                                  {canForceTransfer ? (
                                    <span className="text-green-600 font-medium">Peut transférer</span>
                                  ) : (
                                    <span className="text-yellow-600">
                                      {hoursLeft}h restantes
                                    </span>
                                  )}
                                </td>
                                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                                  <div className="flex items-center space-x-2">
                                    <button
                                      onClick={() => handleTransferPayment(transfer.id, 'approve')}
                                      className="text-green-600 hover:text-green-900"
                                    >
                                      Approuver
                                    </button>
                                    {canForceTransfer && (
                                      <button
                                        onClick={() => handleTransferPayment(transfer.id, 'force')}
                                        className="text-blue-600 hover:text-blue-900 font-medium"
                                      >
                                        Transférer (24h)
                                      </button>
                                    )}
                                    <button
                                      onClick={() => handleTransferPayment(transfer.id, 'reject')}
                                      className="text-red-600 hover:text-red-900"
                                    >
                                      Rejeter
                                    </button>
                                  </div>
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>

                    {pendingTransfers.length === 0 && (
                      <div className="text-center py-8">
                        <div className="text-gray-500">Aucun transfert en attente</div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
              <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button
                  onClick={() => setShowTransferModal(false)}
                  className="bg-white hover:bg-gray-50 text-gray-900 px-4 py-2 rounded-md text-sm font-medium border border-gray-300"
                >
                  Fermer
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}