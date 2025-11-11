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
  stripe_account_id?: string | null;
  stripe_onboarding_complete?: boolean;
  stripe_account_status?: string | null;
  stripe_charges_enabled?: boolean;
  stripe_payouts_enabled?: boolean;
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

  // États pour les modales
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [showAlertModal, setShowAlertModal] = useState(false);
  const [modalContent, setModalContent] = useState({ title: '', message: '', type: 'info' as 'info' | 'success' | 'error' });
  const [confirmMessage, setConfirmMessage] = useState('');
  const [alertMessage, setAlertMessage] = useState('');
  const [pendingAction, setPendingAction] = useState<{ userId: number; action: 'block' | 'unblock' | 'verify' } | null>(null);

  useEffect(() => {
    fetchUsers();
  }, [filter]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const token = await adminAuth.getValidAccessToken();

      if (!token) {
        console.error('No valid token for fetching users');
        return;
      }

      const response = await fetch(`/api/v1/admin/users?status=${filter}&limit=50`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      if (response.ok) {
        const data = await response.json();
        const users = data.data?.users || [];
        setUsers(users);
      } else {
        console.error('Failed to fetch users', response.status);
      }
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  // Fonctions pour les modales
  const showAlert = (title: string, message: string, type: 'info' | 'success' | 'error' = 'info') => {
    setModalContent({ title, message, type });
    setAlertMessage(message);
    setShowAlertModal(true);
  };

  const confirmAction = (userId: number, action: 'block' | 'unblock' | 'verify') => {
    const user = users.find(u => u.id === userId);
    const userName = user ? `${user.first_name} ${user.last_name}` : 'cet utilisateur';

    let title = '';
    let message = '';

    switch (action) {
      case 'block':
        title = 'Bloquer l\'utilisateur';
        message = `Êtes-vous sûr de vouloir bloquer ${userName} ? Cette action empêchera l'utilisateur d'accéder à la plateforme.`;
        break;
      case 'unblock':
        title = 'Débloquer l\'utilisateur';
        message = `Êtes-vous sûr de vouloir débloquer ${userName} ? L'utilisateur pourra à nouveau accéder à la plateforme.`;
        break;
      case 'verify':
        title = 'Vérifier l\'utilisateur';
        message = `Êtes-vous sûr de vouloir vérifier ${userName} ? Cette action marquera le compte comme vérifié.`;
        break;
    }

    setModalContent({ title, message, type: 'info' });
    setConfirmMessage(message);
    setPendingAction({ userId, action });
    setShowConfirmModal(true);
  };

  const handleConfirmedAction = async () => {
    if (!pendingAction) return;

    setShowConfirmModal(false);
    await executeUserAction(pendingAction.userId, pendingAction.action);
    setPendingAction(null);
  };

  const executeUserAction = async (userId: number, action: 'block' | 'unblock' | 'verify') => {
    try {
      let endpoint = '';
      let method = 'POST';
      let body: any = {};

      switch (action) {
        case 'block':
          endpoint = `/api/v1/admin/users/${userId}/block`;
          body = { reason: 'Bloqué par l\'administrateur' };
          break;
        case 'unblock':
          endpoint = `/api/v1/admin/users/${userId}/unblock`;
          break;
        case 'verify':
          endpoint = `/api/v1/admin/users/${userId}/verify`;
          break;
        default:
          console.error('Action not supported:', action);
          return;
      }

      const response = await adminAuth.apiRequest(endpoint, {
        method,
        body: Object.keys(body).length > 0 ? JSON.stringify(body) : undefined,
      });

      if (response.ok) {
        const result = await response.json();

        // Show success message
        const successMessage = `Utilisateur ${action === 'block' ? 'bloqué' : action === 'unblock' ? 'débloqué' : 'vérifié'} avec succès`;
        showAlert('Succès', successMessage, 'success');

        fetchUsers(); // Refresh the list
        if (selectedUser && selectedUser.id === userId) {
          // Update selected user data
          const updatedUser = { ...selectedUser, status: action === 'block' ? 'blocked' : action === 'unblock' ? 'active' : selectedUser.status };
          setSelectedUser(updatedUser);
        }
      } else {
        const errorData = await response.json();
        console.error(`${action} action failed:`, errorData);
        showAlert('Erreur', `Erreur lors de l'action: ${errorData.message || 'Une erreur inconnue s\'est produite'}`, 'error');
      }
    } catch (error) {
      console.error(`Error ${action}ing user:`, error);
      showAlert('Erreur de connexion', 'Erreur de connexion lors de l\'action sur l\'utilisateur', 'error');
    }
  };

  const getUserStatusBadge = (status: string) => {
    const badgeClasses = {
      active: 'badge bg-success',
      blocked: 'badge bg-danger',
      pending: 'badge bg-warning text-dark'
    };

    return (
      <span className={badgeClasses[status as keyof typeof badgeClasses] || 'badge bg-secondary'}>
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
      <div className="row mb-4">
        <div className="col-12">
          <div className="d-flex justify-content-between align-items-center mb-4">
            <div>
              <h2 className="h3 mb-0 fw-bold">Gestion des utilisateurs</h2>
              <p className="text-muted mb-0">Gérez tous les utilisateurs de la plateforme</p>
            </div>
          </div>

          {/* Filters and Search */}
          <div className="card mb-4">
            <div className="card-body">
              <div className="row g-3 align-items-center">
                <div className="col-md-3">
                  <select
                    value={filter}
                    onChange={(e) => setFilter(e.target.value as any)}
                    className="form-select"
                  >
                    <option value="all">Tous les utilisateurs</option>
                    <option value="active">Actifs</option>
                    <option value="blocked">Bloqués</option>
                    <option value="pending">En attente</option>
                  </select>
                </div>

                <div className="col-md-6">
                  <div className="input-group">
                    <span className="input-group-text">
                      <i className="bi bi-search"></i>
                    </span>
                    <input
                      type="text"
                      className="form-control"
                      placeholder="Rechercher un utilisateur..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                    />
                  </div>
                </div>

                <div className="col-md-3">
                  <div className="text-muted small">
                    <strong>{filteredUsers.length}</strong> utilisateur{filteredUsers.length !== 1 ? 's' : ''}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Stats */}
          <div className="row g-3 mb-4">
            <div className="col-md-3">
              <div className="card bg-primary text-white h-100">
                <div className="card-body">
                  <div className="d-flex justify-content-between align-items-center">
                    <div>
                      <h6 className="card-subtitle mb-2 text-white-50">Total utilisateurs</h6>
                      <h3 className="card-title mb-0">{users.length}</h3>
                    </div>
                    <i className="bi bi-people fs-1 opacity-50"></i>
                  </div>
                </div>
              </div>
            </div>
            <div className="col-md-3">
              <div className="card bg-success text-white h-100">
                <div className="card-body">
                  <div className="d-flex justify-content-between align-items-center">
                    <div>
                      <h6 className="card-subtitle mb-2 text-white-50">Actifs</h6>
                      <h3 className="card-title mb-0">{users.filter(u => u.status === 'active').length}</h3>
                    </div>
                    <i className="bi bi-check-circle fs-1 opacity-50"></i>
                  </div>
                </div>
              </div>
            </div>
            <div className="col-md-3">
              <div className="card bg-danger text-white h-100">
                <div className="card-body">
                  <div className="d-flex justify-content-between align-items-center">
                    <div>
                      <h6 className="card-subtitle mb-2 text-white-50">Bloqués</h6>
                      <h3 className="card-title mb-0">{users.filter(u => u.status === 'blocked').length}</h3>
                    </div>
                    <i className="bi bi-x-circle fs-1 opacity-50"></i>
                  </div>
                </div>
              </div>
            </div>
            <div className="col-md-3">
              <div className="card bg-info text-white h-100">
                <div className="card-body">
                  <div className="d-flex justify-content-between align-items-center">
                    <div>
                      <h6 className="card-subtitle mb-2 text-white-50">Comptes Stripe</h6>
                      <h3 className="card-title mb-0">{users.filter(u => u.stripe_account_id).length}</h3>
                    </div>
                    <i className="bi bi-credit-card fs-1 opacity-50"></i>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Users List */}
      <div className="row">
        <div className="col-12">
          <div className="card">
            <div className="card-header">
              <h5 className="card-title mb-0">
                <i className="bi bi-people me-2"></i>
                Liste des utilisateurs
              </h5>
            </div>
            <div className="card-body p-0">
              <div className="table-responsive">
                <table className="table table-hover mb-0">
                  <thead className="table-light">
                    <tr>
                      <th>Utilisateur</th>
                      <th>Statut</th>
                      <th>Vérifications</th>
                      <th>Activité</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredUsers.map((user) => (
                      <tr key={user.id}>
                        <td>
                          <div className="d-flex align-items-center">
                            <div className="avatar bg-primary text-white rounded-circle d-flex align-items-center justify-content-center me-3"
                                 style={{ width: '40px', height: '40px', fontSize: '14px' }}>
                              {user.first_name?.[0]}{user.last_name?.[0]}
                            </div>
                            <div>
                              <div className="fw-medium">{user.first_name} {user.last_name}</div>
                              <div className="text-muted small">{user.email}</div>
                            </div>
                          </div>
                        </td>
                        <td>
                          {getUserStatusBadge(user.status)}
                        </td>
                        <td>
                          <div className="d-flex gap-2">
                            {user.email_verified_at ? (
                              <span className="text-success small">
                                <i className="bi bi-check-circle-fill me-1"></i>
                                Email
                              </span>
                            ) : (
                              <span className="text-muted small">Email</span>
                            )}
                            {user.phone_verified_at ? (
                              <span className="text-success small">
                                <i className="bi bi-check-circle-fill me-1"></i>
                                Téléphone
                              </span>
                            ) : (
                              <span className="text-muted small">Téléphone</span>
                            )}
                          </div>
                        </td>
                        <td>
                          <div>
                            <span className="fw-medium">{user.total_trips || 0}</span> voyage{(user.total_trips || 0) !== 1 ? 's' : ''}
                          </div>
                          <div className="text-muted small">
                            Dernière connexion: {user.last_login_at ? new Date(user.last_login_at).toLocaleDateString('fr-FR') : 'Jamais'}
                          </div>
                        </td>
                        <td>
                          <div className="btn-group btn-group-sm">
                            <button
                              onClick={() => {
                                setSelectedUser(user);
                                setShowUserDetails(true);
                              }}
                              className="btn btn-outline-primary"
                              title="Voir les détails"
                            >
                              <i className="bi bi-eye"></i>
                            </button>
                            {!user.email_verified_at && (
                              <button
                                onClick={() => confirmAction(user.id, 'verify')}
                                className="btn btn-outline-warning"
                                title="Vérifier l'utilisateur"
                              >
                                <i className="bi bi-patch-check"></i>
                              </button>
                            )}
                            {user.status === 'active' ? (
                              <button
                                onClick={() => confirmAction(user.id, 'block')}
                                className="btn btn-outline-danger"
                                title="Bloquer l'utilisateur"
                              >
                                <i className="bi bi-x-circle"></i>
                              </button>
                            ) : user.status === 'blocked' ? (
                              <button
                                onClick={() => confirmAction(user.id, 'unblock')}
                                className="btn btn-outline-success"
                                title="Débloquer l'utilisateur"
                              >
                                <i className="bi bi-check-circle"></i>
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
          </div>
        </div>
      </div>

      {/* User Details Modal */}
      {showUserDetails && selectedUser && (
        <div className="modal show d-block" style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog modal-lg modal-dialog-centered">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">
                  <i className="bi bi-person-fill me-2"></i>
                  Détails utilisateur
                </h5>
                <button
                  type="button"
                  className="btn-close"
                  onClick={() => setShowUserDetails(false)}
                ></button>
              </div>
              <div className="modal-body">
                <div className="row g-3">
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Nom complet</label>
                    <p className="mb-0">{selectedUser.first_name} {selectedUser.last_name}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Email</label>
                    <p className="mb-0">{selectedUser.email}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Téléphone</label>
                    <p className="mb-0">{selectedUser.phone || 'Non renseigné'}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Statut</label>
                    <div>{getUserStatusBadge(selectedUser.status)}</div>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Compte Stripe</label>
                    <p className="mb-0">
                      {selectedUser.stripe_account_id ? (
                        <div>
                          <div className="mb-1">
                            {selectedUser.stripe_account_status === 'active' && (
                              <span className="badge bg-success">
                                <i className="bi bi-check-circle-fill me-1"></i>
                                Actif
                              </span>
                            )}
                            {selectedUser.stripe_account_status === 'pending' && (
                              <span className="badge bg-warning">
                                <i className="bi bi-clock-fill me-1"></i>
                                En attente
                              </span>
                            )}
                            {selectedUser.stripe_account_status === 'restricted' && (
                              <span className="badge bg-danger">
                                <i className="bi bi-exclamation-triangle-fill me-1"></i>
                                Restreint
                              </span>
                            )}
                          </div>
                          <small className="text-muted d-block">
                            ID: {selectedUser.stripe_account_id}
                          </small>
                          <small className="text-muted d-block">
                            Paiements: {selectedUser.stripe_charges_enabled ? 'Activés' : 'Désactivés'} |
                            Virements: {selectedUser.stripe_payouts_enabled ? 'Activés' : 'Désactivés'}
                          </small>
                        </div>
                      ) : (
                        <span className="text-muted">
                          <i className="bi bi-x-circle me-1"></i>
                          Non configuré
                        </span>
                      )}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Score de confiance</label>
                    <div className="progress" style={{height: '20px'}}>
                      <div
                        className="progress-bar bg-primary"
                        style={{width: `${selectedUser.trust_score || 0}%`}}
                      >
                        {selectedUser.trust_score || 0}/100
                      </div>
                    </div>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Date d'inscription</label>
                    <p className="mb-0">
                      {new Date(selectedUser.created_at).toLocaleDateString('fr-FR')}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Dernière connexion</label>
                    <p className="mb-0">
                      {selectedUser.last_login_at ? new Date(selectedUser.last_login_at).toLocaleDateString('fr-FR') : 'Jamais'}
                    </p>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <div className="d-flex gap-2">
                  {!selectedUser.email_verified_at && (
                    <button
                      onClick={() => confirmAction(selectedUser.id, 'verify')}
                      className="btn btn-warning"
                    >
                      <i className="bi bi-patch-check me-1"></i>
                      Vérifier l'utilisateur
                    </button>
                  )}
                  {selectedUser.status === 'active' ? (
                    <button
                      onClick={() => confirmAction(selectedUser.id, 'block')}
                      className="btn btn-danger"
                    >
                      <i className="bi bi-x-circle me-1"></i>
                      Bloquer l'utilisateur
                    </button>
                  ) : selectedUser.status === 'blocked' ? (
                    <button
                      onClick={() => confirmAction(selectedUser.id, 'unblock')}
                      className="btn btn-success"
                    >
                      <i className="bi bi-check-circle me-1"></i>
                      Débloquer l'utilisateur
                    </button>
                  ) : null}
                  <button
                    onClick={() => setShowUserDetails(false)}
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

      {/* Modal de confirmation */}
      {showConfirmModal && (
        <div className="modal show d-block" tabIndex={-1} style={{backgroundColor: 'rgba(0,0,0,0.5)'}}>
          <div className="modal-dialog">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">Confirmation</h5>
                <button
                  type="button"
                  className="btn-close"
                  onClick={() => setShowConfirmModal(false)}
                ></button>
              </div>
              <div className="modal-body">
                <p>{confirmMessage}</p>
              </div>
              <div className="modal-footer">
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setShowConfirmModal(false)}
                >
                  Annuler
                </button>
                <button
                  type="button"
                  className="btn btn-danger"
                  onClick={handleConfirmedAction}
                >
                  Confirmer
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Modal d'alerte */}
      {showAlertModal && (
        <div className="modal show d-block" tabIndex={-1} style={{backgroundColor: 'rgba(0,0,0,0.5)'}}>
          <div className="modal-dialog">
            <div className="modal-content">
              <div className="modal-header">
                <h5 className="modal-title">Information</h5>
                <button
                  type="button"
                  className="btn-close"
                  onClick={() => setShowAlertModal(false)}
                ></button>
              </div>
              <div className="modal-body">
                <p>{alertMessage}</p>
              </div>
              <div className="modal-footer">
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={() => setShowAlertModal(false)}
                >
                  OK
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}