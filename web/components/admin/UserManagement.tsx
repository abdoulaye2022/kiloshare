'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface User {
  id: number;
  uuid: string;
  email: string;
  first_name: string;
  last_name: string;
  phone?: string;
  is_verified: boolean;
  email_verified_at?: string;
  phone_verified_at?: string;
  status: 'active' | 'blocked' | 'pending';
  role: string;
  last_login_at?: string;
  created_at: string;
  stripe_account_id?: string;
  stripe_onboarding_complete?: boolean;
  total_trips?: number;
  total_bookings?: number;
  trust_score?: number;
}

export default function UserManagement() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'active' | 'blocked' | 'pending'>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [showUserDetails, setShowUserDetails] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, [filter]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const response = await adminAuth.apiRequest(`/api/v1/admin/users?status=${filter}&limit=50`);
      
      if (response.ok) {
        const data = await response.json();
        console.log('Users API response:', data);
        setUsers(data.data?.users || []);
      } else {
        console.error('Failed to fetch users');
      }
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleUserAction = async (userId: number, action: 'block' | 'unblock' | 'verify') => {
    try {
      const response = await adminAuth.apiRequest(`/api/v1/admin/users/${userId}/${action}`, {
        method: 'POST',
      });

      if (response.ok) {
        fetchUsers(); // Refresh the list
        if (selectedUser && selectedUser.id === userId) {
          setSelectedUser(null);
          setShowUserDetails(false);
        }
      }
    } catch (error) {
      console.error(`Error ${action}ing user:`, error);
    }
  };

  const getUserStatusBadge = (status: string) => {
    const badgeClasses = {
      active: 'bg-green-100 text-green-800',
      blocked: 'bg-red-100 text-red-800', 
      pending: 'bg-yellow-100 text-yellow-800'
    };
    
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${badgeClasses[status as keyof typeof badgeClasses]}`}>
        {status}
      </span>
    );
  };

  const filteredUsers = users.filter(user => {
    const matchesSearch = searchTerm === '' || 
      user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      `${user.first_name} ${user.last_name}`.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesSearch;
  });

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-4"></div>
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
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Gestion des utilisateurs</h2>
        
        {/* Filters and Search */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
          <div className="flex items-center space-x-4">
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value as any)}
              className="rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 bg-white text-gray-900 selection:bg-blue-100 selection:text-blue-900"
            >
              <option value="all">Tous les utilisateurs</option>
              <option value="active">Actifs</option>
              <option value="blocked">Bloqués</option>
              <option value="pending">En attente</option>
            </select>
          </div>
          
          <div className="flex-1 max-w-md">
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg className="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
              <input
                type="text"
                placeholder="Rechercher un utilisateur..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10 w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-2xl font-bold text-gray-900">{users.length}</div>
            <div className="text-sm text-gray-600">Total utilisateurs</div>
          </div>
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-2xl font-bold text-green-600">{users.filter(u => u.status === 'active').length}</div>
            <div className="text-sm text-gray-600">Actifs</div>
          </div>
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-2xl font-bold text-red-600">{users.filter(u => u.status === 'blocked').length}</div>
            <div className="text-sm text-gray-600">Bloqués</div>
          </div>
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-2xl font-bold text-blue-600">{users.filter(u => u.stripe_account_id).length}</div>
            <div className="text-sm text-gray-600">Comptes Stripe</div>
          </div>
        </div>
      </div>

      {/* Users List */}
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Utilisateur
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Statut
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Vérifications
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Activité
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-700 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 h-10 w-10">
                        <div className="h-10 w-10 rounded-full bg-blue-500 flex items-center justify-center">
                          <span className="text-white font-medium text-sm">
                            {user.first_name?.[0]}{user.last_name?.[0]}
                          </span>
                        </div>
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-gray-900">
                          {user.first_name} {user.last_name}
                        </div>
                        <div className="text-sm text-gray-600">{user.email}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    {getUserStatusBadge(user.status)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center space-x-2">
                      {user.email_verified_at ? (
                        <span className="inline-flex items-center text-green-600">
                          <svg className="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                          </svg>
                          Email
                        </span>
                      ) : (
                        <span className="text-gray-400">Email</span>
                      )}
                      {user.phone_verified_at ? (
                        <span className="inline-flex items-center text-green-600">
                          <svg className="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                          </svg>
                          Téléphone
                        </span>
                      ) : (
                        <span className="text-gray-400">Téléphone</span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <div>
                      {user.total_trips || 0} voyages
                    </div>
                    <div className="text-xs">
                      Dernière connexion: {user.last_login_at ? new Date(user.last_login_at).toLocaleDateString('fr-FR') : 'Jamais'}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <div className="flex items-center space-x-2">
                      <button
                        onClick={() => {
                          setSelectedUser(user);
                          setShowUserDetails(true);
                        }}
                        className="text-blue-600 hover:text-blue-900"
                      >
                        Voir
                      </button>
                      {user.status === 'active' ? (
                        <button
                          onClick={() => handleUserAction(user.id, 'block')}
                          className="text-red-600 hover:text-red-900"
                        >
                          Bloquer
                        </button>
                      ) : user.status === 'blocked' ? (
                        <button
                          onClick={() => handleUserAction(user.id, 'unblock')}
                          className="text-green-600 hover:text-green-900"
                        >
                          Débloquer
                        </button>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* User Details Modal */}
      {showUserDetails && selectedUser && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
              <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div className="sm:flex sm:items-start">
                  <div className="w-full">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg leading-6 font-medium text-gray-900">
                        Détails utilisateur
                      </h3>
                      <button
                        onClick={() => setShowUserDetails(false)}
                        className="text-gray-400 hover:text-gray-600"
                      >
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="text-sm font-medium text-gray-600">Nom complet</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedUser.first_name} {selectedUser.last_name}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-600">Email</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedUser.email}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-600">Téléphone</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedUser.phone || 'Non renseigné'}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-600">Statut</label>
                        <div className="mt-1">{getUserStatusBadge(selectedUser.status)}</div>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-600">Compte Stripe</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {selectedUser.stripe_account_id ? (
                            <span className="text-green-600">Configuré</span>
                          ) : (
                            <span className="text-gray-500">Non configuré</span>
                          )}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-600">Score de confiance</label>
                        <p className="mt-1 text-sm text-gray-900">{selectedUser.trust_score || 0}/100</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-600">Date d'inscription</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {new Date(selectedUser.created_at).toLocaleDateString('fr-FR')}
                        </p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-gray-600">Dernière connexion</label>
                        <p className="mt-1 text-sm text-gray-900">
                          {selectedUser.last_login_at ? new Date(selectedUser.last_login_at).toLocaleDateString('fr-FR') : 'Jamais'}
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <div className="flex space-x-3">
                  {selectedUser.status === 'active' ? (
                    <button
                      onClick={() => handleUserAction(selectedUser.id, 'block')}
                      className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                    >
                      Bloquer l'utilisateur
                    </button>
                  ) : selectedUser.status === 'blocked' ? (
                    <button
                      onClick={() => handleUserAction(selectedUser.id, 'unblock')}
                      className="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                    >
                      Débloquer l'utilisateur
                    </button>
                  ) : null}
                  <button
                    onClick={() => setShowUserDetails(false)}
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