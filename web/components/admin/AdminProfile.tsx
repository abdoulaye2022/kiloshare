'use client';

import { useState, useEffect } from 'react';
import { useAdminAuthStore } from '../../stores/adminAuthStore';
import adminAuth from '../../lib/admin-auth';

interface AdminUser {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
  role: string;
  created_at: string;
  last_login_at?: string;
}

export default function AdminProfile() {
  const { user, logout } = useAdminAuthStore();
  const [profile, setProfile] = useState<AdminUser | null>(null);
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    email: '',
    current_password: '',
    new_password: '',
    confirm_password: ''
  });

  useEffect(() => {
    fetchProfile();
  }, []);

  const fetchProfile = async () => {
    try {
      setLoading(true);
      const token = await adminAuth.getValidAccessToken();

      if (!token) {
        setError('Token d\'authentification manquant');
        return;
      }

      const response = await fetch('/api/admin/profile', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });

      if (response.ok) {
        const data = await response.json();
        const profileData = data.data?.profile || data.profile || data.data?.admin || user;
        setProfile(profileData);
        setFormData({
          first_name: profileData.first_name || '',
          last_name: profileData.last_name || '',
          email: profileData.email || '',
          current_password: '',
          new_password: '',
          confirm_password: ''
        });
      } else {
        setError('Impossible de charger le profil');
      }
    } catch (error) {
      console.error('Error fetching profile:', error);
      setError('Erreur de connexion');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    // Validation
    if (formData.new_password && formData.new_password !== formData.confirm_password) {
      setError('Les nouveaux mots de passe ne correspondent pas');
      return;
    }

    if (formData.new_password && formData.new_password.length < 6) {
      setError('Le nouveau mot de passe doit contenir au moins 6 caractères');
      return;
    }

    try {
      setLoading(true);
      const updateData: any = {
        first_name: formData.first_name,
        last_name: formData.last_name,
        email: formData.email
      };

      if (formData.new_password) {
        updateData.current_password = formData.current_password;
        updateData.new_password = formData.new_password;
      }

      const token = await adminAuth.getValidAccessToken();

      if (!token) {
        setError('Token d\'authentification manquant');
        return;
      }

      const response = await fetch('/api/admin/profile', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(updateData),
      });

      if (response.ok) {
        setSuccess('Profil mis à jour avec succès');
        setEditing(false);
        setFormData(prev => ({
          ...prev,
          current_password: '',
          new_password: '',
          confirm_password: ''
        }));
        await fetchProfile();
      } else {
        const errorData = await response.json();
        setError(errorData.message || 'Erreur lors de la mise à jour');
      }
    } catch (error) {
      console.error('Error updating profile:', error);
      setError('Erreur de connexion');
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  if (loading && !profile) {
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
          <div className="d-flex justify-content-between align-items-center">
            <div>
              <h2 className="h3 mb-0 fw-bold">Mon profil</h2>
              <p className="text-muted mb-0">Gérez vos informations personnelles et votre mot de passe</p>
            </div>
            {!editing && (
              <button
                onClick={() => setEditing(true)}
                className="btn btn-primary"
              >
                <i className="bi bi-pencil me-2"></i>
                Modifier
              </button>
            )}
          </div>
        </div>
      </div>

      {error && (
        <div className="alert alert-danger" role="alert">
          <i className="bi bi-exclamation-circle me-2"></i>
          {error}
        </div>
      )}

      {success && (
        <div className="alert alert-success" role="alert">
          <i className="bi bi-check-circle me-2"></i>
          {success}
        </div>
      )}

      <div className="row">
        <div className="col-lg-8">
          <div className="card">
            <div className="card-header">
              <h5 className="card-title mb-0">
                <i className="bi bi-person-fill me-2"></i>
                Informations personnelles
              </h5>
            </div>
            <div className="card-body">
              {!editing ? (
                // Mode lecture
                <div className="row g-3">
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Prénom</label>
                    <p className="mb-0">{profile?.first_name || 'Non renseigné'}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Nom</label>
                    <p className="mb-0">{profile?.last_name || 'Non renseigné'}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Email</label>
                    <p className="mb-0">{profile?.email}</p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Rôle</label>
                    <p className="mb-0">
                      <span className="badge bg-primary">
                        {profile?.role || 'Administrateur'}
                      </span>
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Membre depuis</label>
                    <p className="mb-0">
                      {profile?.created_at ? new Date(profile.created_at).toLocaleDateString('fr-FR') : 'Non disponible'}
                    </p>
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-medium">Dernière connexion</label>
                    <p className="mb-0">
                      {profile?.last_login_at ? new Date(profile.last_login_at).toLocaleString('fr-FR') : 'Non disponible'}
                    </p>
                  </div>
                </div>
              ) : (
                // Mode édition
                <form onSubmit={handleUpdateProfile}>
                  <div className="row g-3">
                    <div className="col-md-6">
                      <label className="form-label fw-medium">Prénom</label>
                      <input
                        type="text"
                        name="first_name"
                        value={formData.first_name}
                        onChange={handleInputChange}
                        className="form-control"
                        required
                      />
                    </div>
                    <div className="col-md-6">
                      <label className="form-label fw-medium">Nom</label>
                      <input
                        type="text"
                        name="last_name"
                        value={formData.last_name}
                        onChange={handleInputChange}
                        className="form-control"
                        required
                      />
                    </div>
                    <div className="col-md-6">
                      <label className="form-label fw-medium">Email</label>
                      <input
                        type="email"
                        name="email"
                        value={formData.email}
                        onChange={handleInputChange}
                        className="form-control"
                        required
                      />
                    </div>
                    <div className="col-12">
                      <hr />
                      <h6 className="fw-bold mb-3">Modification du mot de passe (optionnel)</h6>
                    </div>
                    <div className="col-md-4">
                      <label className="form-label fw-medium">Mot de passe actuel</label>
                      <input
                        type="password"
                        name="current_password"
                        value={formData.current_password}
                        onChange={handleInputChange}
                        className="form-control"
                        placeholder="Requis si nouveau mot de passe"
                      />
                    </div>
                    <div className="col-md-4">
                      <label className="form-label fw-medium">Nouveau mot de passe</label>
                      <input
                        type="password"
                        name="new_password"
                        value={formData.new_password}
                        onChange={handleInputChange}
                        className="form-control"
                        placeholder="Minimum 6 caractères"
                      />
                    </div>
                    <div className="col-md-4">
                      <label className="form-label fw-medium">Confirmer le nouveau mot de passe</label>
                      <input
                        type="password"
                        name="confirm_password"
                        value={formData.confirm_password}
                        onChange={handleInputChange}
                        className="form-control"
                        placeholder="Répétez le nouveau mot de passe"
                      />
                    </div>
                    <div className="col-12">
                      <div className="d-flex gap-2">
                        <button
                          type="submit"
                          className="btn btn-success"
                          disabled={loading}
                        >
                          {loading ? (
                            <>
                              <span className="spinner-border spinner-border-sm me-2" />
                              Mise à jour...
                            </>
                          ) : (
                            <>
                              <i className="bi bi-check me-2"></i>
                              Sauvegarder
                            </>
                          )}
                        </button>
                        <button
                          type="button"
                          onClick={() => {
                            setEditing(false);
                            setError('');
                            setSuccess('');
                            setFormData({
                              first_name: profile?.first_name || '',
                              last_name: profile?.last_name || '',
                              email: profile?.email || '',
                              current_password: '',
                              new_password: '',
                              confirm_password: ''
                            });
                          }}
                          className="btn btn-secondary"
                        >
                          <i className="bi bi-x me-2"></i>
                          Annuler
                        </button>
                      </div>
                    </div>
                  </div>
                </form>
              )}
            </div>
          </div>
        </div>

        <div className="col-lg-4">
          <div className="card">
            <div className="card-header">
              <h5 className="card-title mb-0">
                <i className="bi bi-shield-check me-2"></i>
                Sécurité
              </h5>
            </div>
            <div className="card-body">
              <div className="mb-3">
                <small className="text-muted">
                  <i className="bi bi-info-circle me-1"></i>
                  Conseils de sécurité :
                </small>
                <ul className="mt-2 small text-muted">
                  <li>Utilisez un mot de passe fort avec au moins 8 caractères</li>
                  <li>Incluez des majuscules, minuscules, chiffres et symboles</li>
                  <li>Ne partagez jamais vos identifiants</li>
                  <li>Déconnectez-vous après utilisation</li>
                </ul>
              </div>

              <div className="d-grid">
                <button
                  onClick={logout}
                  className="btn btn-outline-danger"
                >
                  <i className="bi bi-box-arrow-right me-2"></i>
                  Se déconnecter
                </button>
              </div>
            </div>
          </div>

          <div className="card mt-4">
            <div className="card-header">
              <h5 className="card-title mb-0">
                <i className="bi bi-activity me-2"></i>
                Activité récente
              </h5>
            </div>
            <div className="card-body">
              <div className="text-center text-muted">
                <i className="bi bi-clock mb-2" style={{fontSize: '2rem'}}></i>
                <p className="mb-0 small">Les logs d'activité seront bientôt disponibles</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}