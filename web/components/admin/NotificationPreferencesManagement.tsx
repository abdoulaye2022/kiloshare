'use client';

import { useState, useEffect } from 'react';
import adminAuth from '../../lib/admin-auth';

interface NotificationPreferences {
  id: number;
  user_id: number;
  general: {
    push_enabled: boolean;
    email_enabled: boolean;
    sms_enabled: boolean;
    in_app_enabled: boolean;
    marketing_enabled: boolean;
    language: string;
    timezone: string;
  };
  quiet_hours: {
    enabled: boolean;
    start: string;
    end: string;
  };
  categories: {
    trip_updates: { push: boolean; email: boolean };
    booking_updates: { push: boolean; email: boolean };
    payment_updates: { push: boolean; email: boolean };
    security_alerts: { push: boolean; email: boolean };
  };
  created_at: string;
  updated_at: string;
}

interface User {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
}

interface UserWithPreferences {
  user: User;
  preferences: NotificationPreferences;
}

interface PreferencesStats {
  total_users: number;
  users_with_preferences: number;
  users_without_preferences: number;
  notification_channels: {
    push_enabled: number;
    email_enabled: number;
    sms_enabled: number;
    in_app_enabled: number;
    marketing_enabled: number;
  };
  notification_types: {
    trip_updates_push: number;
    booking_updates_push: number;
    payment_updates_push: number;
    security_alerts_push: number;
  };
  quiet_hours: {
    enabled: number;
    disabled: number;
  };
  languages: { [key: string]: number };
  timezones: { [key: string]: number };
}

export default function NotificationPreferencesManagement() {
  const [stats, setStats] = useState<PreferencesStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedUserId, setSelectedUserId] = useState<string>('');
  const [selectedUserPrefs, setSelectedUserPrefs] = useState<UserWithPreferences | null>(null);
  const [showUserModal, setShowUserModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    try {
      setLoading(true);
      const response = await adminAuth.apiRequest('/api/v1/admin/notification-preferences/stats');
      
      if (response.ok) {
        const data = await response.json();
        setStats(data.data?.stats);
      } else {
        console.error('Failed to fetch notification preferences stats');
      }
    } catch (error) {
      console.error('Error fetching notification preferences stats:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchUserPreferences = async (userId: string) => {
    try {
      const response = await adminAuth.apiRequest(`/api/v1/admin/notification-preferences/${userId}`);
      
      if (response.ok) {
        const data = await response.json();
        setSelectedUserPrefs(data.data);
        setShowUserModal(true);
      } else {
        const errorData = await response.json();
        alert(`Erreur: ${errorData.message || 'Utilisateur non trouvé'}`);
      }
    } catch (error) {
      console.error('Error fetching user preferences:', error);
      alert('Erreur lors de la récupération des préférences');
    }
  };

  const handleSearchUser = (e: React.FormEvent) => {
    e.preventDefault();
    if (selectedUserId.trim()) {
      fetchUserPreferences(selectedUserId.trim());
    }
  };

  const updateUserPreferences = async (userId: number, updates: Partial<any>) => {
    try {
      const response = await adminAuth.apiRequest(`/api/v1/admin/notification-preferences/${userId}`, {
        method: 'PUT',
        body: JSON.stringify(updates)
      });

      if (response.ok) {
        const data = await response.json();
        setSelectedUserPrefs(data.data);
        alert('Préférences mises à jour avec succès');
        fetchStats(); // Refresh stats
      } else {
        const errorData = await response.json();
        alert(`Erreur: ${errorData.message || 'Impossible de mettre à jour'}`);
      }
    } catch (error) {
      console.error('Error updating user preferences:', error);
      alert('Erreur lors de la mise à jour');
    }
  };

  const formatPercentage = (value: number, total: number) => {
    if (total === 0) return '0%';
    return `${Math.round((value / total) * 100)}%`;
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/3 mb-6"></div>
          <div className="grid grid-cols-4 gap-4 mb-6">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-24 bg-gray-200 rounded"></div>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-6">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="h-48 bg-gray-200 rounded"></div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 bg-gray-100 min-h-screen">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-4">Gestion des Préférences de Notifications</h2>
        
        {/* User Search */}
        <div className="bg-white p-4 rounded-lg shadow mb-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Rechercher les préférences d'un utilisateur</h3>
          <form onSubmit={handleSearchUser} className="flex gap-4">
            <input
              type="text"
              value={selectedUserId}
              onChange={(e) => setSelectedUserId(e.target.value)}
              placeholder="ID de l'utilisateur"
              className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
            <button
              type="submit"
              className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-md font-medium"
            >
              Rechercher
            </button>
          </form>
        </div>

        {/* Stats Overview */}
        {stats && (
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-blue-600">{stats.total_users}</div>
              <div className="text-sm text-gray-600">Total utilisateurs</div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-green-600">{stats.users_with_preferences}</div>
              <div className="text-sm text-gray-600">
                Avec préférences ({formatPercentage(stats.users_with_preferences, stats.total_users)})
              </div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-orange-600">{stats.users_without_preferences}</div>
              <div className="text-sm text-gray-600">
                Sans préférences ({formatPercentage(stats.users_without_preferences, stats.total_users)})
              </div>
            </div>
            <div className="bg-white p-4 rounded-lg border">
              <div className="text-2xl font-bold text-purple-600">{stats.notification_channels.marketing_enabled}</div>
              <div className="text-sm text-gray-600">Marketing activé</div>
            </div>
          </div>
        )}

        {/* Detailed Stats */}
        {stats && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Notification Channels */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Canaux de Notification</h3>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Notifications Push</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_channels.push_enabled}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_channels.push_enabled, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Email</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_channels.email_enabled}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_channels.email_enabled, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">SMS</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_channels.sms_enabled}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_channels.sms_enabled, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">In-App</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_channels.in_app_enabled}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_channels.in_app_enabled, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Notification Types */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Types de Notifications (Push)</h3>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Mises à jour trajets</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_types.trip_updates_push}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_types.trip_updates_push, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Réservations</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_types.booking_updates_push}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_types.booking_updates_push, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Paiements</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_types.payment_updates_push}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_types.payment_updates_push, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Sécurité</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium">{stats.notification_types.security_alerts_push}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.notification_types.security_alerts_push, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Quiet Hours */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Heures Calmes</h3>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Activées</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium text-green-600">{stats.quiet_hours.enabled}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.quiet_hours.enabled, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Désactivées</span>
                  <div className="flex items-center space-x-2">
                    <span className="font-medium text-red-600">{stats.quiet_hours.disabled}</span>
                    <span className="text-xs text-gray-500">
                      ({formatPercentage(stats.quiet_hours.disabled, stats.users_with_preferences)})
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Languages */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Langues</h3>
              <div className="space-y-3">
                {Object.entries(stats.languages).map(([language, count]) => (
                  <div key={language} className="flex justify-between items-center">
                    <span className="text-sm text-gray-600">
                      {language === 'fr' ? 'Français' : 
                       language === 'en' ? 'Anglais' : 
                       language === 'es' ? 'Espagnol' : language.toUpperCase()}
                    </span>
                    <div className="flex items-center space-x-2">
                      <span className="font-medium">{count}</span>
                      <span className="text-xs text-gray-500">
                        ({formatPercentage(count, stats.users_with_preferences)})
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* User Preferences Modal */}
      {showUserModal && selectedUserPrefs && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
              <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div className="sm:flex sm:items-start">
                  <div className="w-full">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg leading-6 font-medium text-gray-900">
                        Préférences de Notifications - {selectedUserPrefs.user.first_name} {selectedUserPrefs.user.last_name}
                      </h3>
                      <button
                        onClick={() => setShowUserModal(false)}
                        className="text-gray-400 hover:text-gray-600"
                      >
                        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>

                    <div className="mb-4 p-4 bg-gray-50 rounded-lg">
                      <div className="grid grid-cols-2 gap-4 text-sm">
                        <div>
                          <span className="font-medium">Email:</span> {selectedUserPrefs.user.email}
                        </div>
                        <div>
                          <span className="font-medium">ID:</span> {selectedUserPrefs.user.id}
                        </div>
                        <div>
                          <span className="font-medium">Langue:</span> {selectedUserPrefs.preferences.general.language}
                        </div>
                        <div>
                          <span className="font-medium">Timezone:</span> {selectedUserPrefs.preferences.general.timezone}
                        </div>
                      </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      {/* General Settings */}
                      <div>
                        <h4 className="text-md font-medium text-gray-900 mb-3">Paramètres Généraux</h4>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span>Push:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.general.push_enabled ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.general.push_enabled ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>Email:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.general.email_enabled ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.general.email_enabled ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>SMS:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.general.sms_enabled ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.general.sms_enabled ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>Marketing:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.general.marketing_enabled ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.general.marketing_enabled ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Quiet Hours */}
                      <div>
                        <h4 className="text-md font-medium text-gray-900 mb-3">Heures Calmes</h4>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span>Statut:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.quiet_hours.enabled ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.quiet_hours.enabled ? 'Activées' : 'Désactivées'}
                            </span>
                          </div>
                          {selectedUserPrefs.preferences.quiet_hours.enabled && (
                            <>
                              <div className="flex justify-between">
                                <span>Début:</span>
                                <span className="font-medium">{selectedUserPrefs.preferences.quiet_hours.start}</span>
                              </div>
                              <div className="flex justify-between">
                                <span>Fin:</span>
                                <span className="font-medium">{selectedUserPrefs.preferences.quiet_hours.end}</span>
                              </div>
                            </>
                          )}
                        </div>
                      </div>

                      {/* Trip Updates */}
                      <div>
                        <h4 className="text-md font-medium text-gray-900 mb-3">Mises à jour Trajets</h4>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span>Push:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.categories.trip_updates.push ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.categories.trip_updates.push ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>Email:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.categories.trip_updates.email ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.categories.trip_updates.email ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Security Alerts */}
                      <div>
                        <h4 className="text-md font-medium text-gray-900 mb-3">Alertes Sécurité</h4>
                        <div className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <span>Push:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.categories.security_alerts.push ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.categories.security_alerts.push ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>Email:</span>
                            <span className={`font-medium ${selectedUserPrefs.preferences.categories.security_alerts.email ? 'text-green-600' : 'text-red-600'}`}>
                              {selectedUserPrefs.preferences.categories.security_alerts.email ? 'Activé' : 'Désactivé'}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="mt-6 text-xs text-gray-500">
                      <div>Créé le: {new Date(selectedUserPrefs.preferences.created_at).toLocaleString('fr-FR')}</div>
                      <div>Modifié le: {new Date(selectedUserPrefs.preferences.updated_at).toLocaleString('fr-FR')}</div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <div className="flex space-x-3">
                  <button
                    onClick={() => {
                      if (confirm('Voulez-vous désactiver les notifications marketing pour cet utilisateur ?')) {
                        updateUserPreferences(selectedUserPrefs.user.id, { marketing_enabled: false });
                      }
                    }}
                    className="bg-orange-600 hover:bg-orange-700 text-white px-4 py-2 rounded-md text-sm font-medium"
                  >
                    Désactiver Marketing
                  </button>
                  <button
                    onClick={() => setShowUserModal(false)}
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