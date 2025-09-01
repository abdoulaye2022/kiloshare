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

interface ConnectedAccountsManagementProps {
  adminInfo: any;
}

export default function ConnectedAccountsManagement({ adminInfo }: ConnectedAccountsManagementProps) {
  const [accounts, setAccounts] = useState<ConnectedAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'active' | 'pending' | 'restricted' | 'rejected'>('all');
  const [selectedAccount, setSelectedAccount] = useState<ConnectedAccount | null>(null);
  const [showAccountDetails, setShowAccountDetails] = useState(false);
  const [stats, setStats] = useState<any>(null);

  useEffect(() => {
    fetchAccounts();
    fetchStats();
  }, [filter]);

  const fetchAccounts = async () => {
    try {
      setLoading(true);
      const response = await adminAuth.apiRequest(
        `/api/v1/admin/stripe/connected-accounts?status=${filter}&limit=50`
      );
      
      if (response.ok) {
        const data = await response.json();
        setAccounts(data.accounts || []);
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
        setStats(data.stats);
      }
    } catch (error) {
      console.error('Error fetching connected accounts stats:', error);
    }
  };

  const handleAccountAction = async (accountId: string, action: 'enable' | 'disable' | 'review') => {
    try {
      const response = await adminAuth.apiRequest(`/api/v1/admin/stripe/connected-accounts/${accountId}/${action}`, {
        method: 'POST',
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
    <div className="p-6">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Comptes connectés Stripe</h2>
        
        {/* Stats */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-green-600">{stats.active_count || 0}</div>
              <div className="text-sm text-gray-500">Comptes actifs</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-yellow-600">{stats.pending_count || 0}</div>
              <div className="text-sm text-gray-500">En attente</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-orange-600">{stats.restricted_count || 0}</div>
              <div className="text-sm text-gray-500">Restreints</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-blue-600">{stats.total_balance?.toFixed(2) || '0.00'} €</div>
              <div className="text-sm text-gray-500">Solde total</div>
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
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Utilisateur
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Compte Stripe
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Statut
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Capacités
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Solde
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
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
                        <div className="text-sm text-gray-500">{account.user?.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900 font-mono">{account.stripe_account_id}</div>
                    <div className="text-sm text-gray-500">{account.country} • {account.default_currency}</div>
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
                        <div>Disponible: {account.balance.available.toFixed(2)} €</div>
                        <div className="text-xs text-gray-500">
                          En attente: {account.balance.pending.toFixed(2)} €
                        </div>
                      </div>
                    ) : (
                      <div className="text-sm text-gray-500">N/A</div>
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
                        <label className="text-sm font-medium text-gray-500">ID Compte Stripe</label>
                        <p className="mt-1 text-sm text-gray-900 font-mono">{selectedAccount.stripe_account_id}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Statut</label>
                        <div className="mt-1">{getStatusBadge(selectedAccount.account_status)}</div>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Pays</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedAccount.country}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Devise par défaut</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedAccount.default_currency}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Type d'entreprise</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedAccount.business_type || 'Non spécifié'}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Email</label>
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
                        <label className="text-sm font-medium text-gray-500">Date de création</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {new Date(selectedAccount.created_at).toLocaleDateString('fr-FR')}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-500">Dernière mise à jour</label>
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
    </div>
  );
}